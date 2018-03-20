open Lwt.Infix

module Logger = Logger.Logger

module type I_Config = sig 
  type t 
  module LogCoder: Participant.I_LogStringCoder with type t = t
  val remotes: string list
  val validator: (t list -> t list -> t list) option
end

module type I_Leader = sig
  (*This performs certain initialisations, then will return a function that actually runs the leader*)
  val init_leader: unit -> (unit -> unit Lwt.t) Lwt.t
end

module Make (Config: I_Config) : I_Leader = struct
  module IrminLogMem = Ezirmin.FS_log(Tc.String)
  module IrminLogBlock = Ezirmin.FS_log(Tc.String)
  module IrminLogPartMem = Ezirmin.FS_log(Tc.String)
  let run = Lwt_main.run
  let path = []
  let blockchain_repo = run @@ IrminLogBlock.init ~root: "/tmp/ezirminl/lead/blockchain" ~bare:true ()
  let mempool_repo = run @@ IrminLogMem.init ~root:"/tmp/ezirminl/lead/mempool" ~bare:true ()
  let mempool_local_repo = run @@ IrminLogPartMem.init ~root: "/tmp/ezirminl/part/mempool" ~bare:true ()
  let blockchain_master_branch = run @@ IrminLogBlock.master blockchain_repo
  let mempool_master_branch = run @@ IrminLogMem.master mempool_repo
  let part_mempool_master_branch = run @@ IrminLogPartMem.master mempool_local_repo
  let internal_branch = run @@ IrminLogMem.get_branch mempool_repo "internal"
  let part_mempool_cursor: IrminLogPartMem.cursor option ref = ref None
  let remotes_branches_names = let full_uris = List.map (fun str -> (Printf.sprintf "git+ssh://%s/tmp/ezirminl/part/mempool" str, str)) Config.remotes in
   List.map (fun (str1,str2) -> (IrminLogMem.Sync.remote_uri str1, run (IrminLogMem.get_branch mempool_repo (Str.global_replace (Str.regexp "@")"" str2)), str2)) full_uris
  let latest_cursors: IrminLogMem.cursor list ref = ref []
  let buffered_updates = ref []
  let updates_to_be_added = ref []

  exception Validator_Not_Supplied
  exception Could_Not_Initialise_Blockchain
  exception Option_Unwrapping

  let ignore_lwt t = t >|= fun _ -> ()
  let get = function 
    | Some x -> x
    | None -> raise Option_Unwrapping

  let pull_mem remote_mem branch = Lwt.join [ignore_lwt @@ IrminLogMem.Sync.pull remote_mem internal_branch `Merge;
    ignore_lwt @@ IrminLogMem.Sync.pull remote_mem branch `Merge]

  let add_value_to_blockchain value = 
    IrminLogBlock.append ~message:"Entry added to the blockchain" blockchain_master_branch ~path:path value
  (*Decode and re-encode value so as to get new timestamp*)
  let add_txn_to_blockchain value = 
    let txn_opt = Config.LogCoder.decode_string value in
    match txn_opt with 
      | Some(txn) -> let txn_string = Config.LogCoder.encode_string txn in
        IrminLogBlock.append ~message:"Entry added to the blockchain" blockchain_master_branch ~path:path txn_string
      | _ -> Printf.printf "Couldn't reconstruct log item\n%!"; Lwt.return ()
  let add_list_to_blockchain list = 
    Logger.info (Printf.sprintf "Starting to add to blockchain at time %f" (Ptime.to_float_s (Ptime_clock.now()))); 
    Lwt_list.iter_s add_txn_to_blockchain list >>= fun _ ->
    Logger.info (Printf.sprintf "Finished adding to blockchain at time %f" (Ptime.to_float_s (Ptime_clock.now())));
    Lwt.return ()

  let rec flat_map = function 
    | [] -> []
    | (Some(x)::xs) -> (x::(flat_map xs))
    | (None::xs) -> flat_map xs
  
  (*This function gets new updates from the leaders mempool so they can be added to the blockchain*)
  (*Earliest messages will appear first in resulting list*)
  let get_single_mempool_updates branch latest_known_cursor = 
    let rec get_with_cursor acc = (function 
      | Some(cursor) -> 
        if get(IrminLogMem.is_later cursor ~than:latest_known_cursor) then
          IrminLogMem.read cursor ~num_items:1 >>= (function
            | ([x], Some(curs)) -> get_with_cursor ((x, get(IrminLogMem.at_time cursor))::acc) (Some(curs))
            | ([x], None) -> Lwt.return ((x, get(IrminLogMem.at_time cursor))::acc)
            | _ -> Lwt.return acc )
        else 
          (*We've gone too far back!*)
          Lwt.return acc
      | None -> Lwt.return acc)
    in 
      IrminLogMem.get_cursor branch ~path:path >>= get_with_cursor [] 

  let get_local_part_updates () = 
    let rec get_with_cursor new_curs item_acc = ( 
      Lwt.return @@ IrminLogPartMem.is_earlier (get !part_mempool_cursor) ~than:new_curs >>= function
        | Some(true) -> IrminLogPartMem.read ~num_items:1 new_curs >>= (function 
          | ([item], Some(new_cursor)) when item <> "Genesis Commit" -> get_with_cursor new_cursor ((item, get (IrminLogPartMem.at_time new_curs))::item_acc)
          | _ -> Lwt.return item_acc)
        | _ -> Lwt.return item_acc) 
    in
      IrminLogPartMem.get_cursor part_mempool_master_branch ~path:path >>= function 
        | None -> Lwt.return ([], None)
        | Some(cursor) -> get_with_cursor cursor [] >>= fun items -> Lwt.return (items, Some(cursor))

  let rec insert_list_into_list greater_than = function 
    | [], [] -> []
    | (x::xs), (y::ys) -> if greater_than x y then 
        y::(insert_list_into_list greater_than (x::xs, ys)) 
      else 
        x::(insert_list_into_list greater_than (xs, y::ys))
    | [], ys -> ys
    | xs, [] -> xs
  
  let compare_tuples (_,x) (_,y) = Ptime.is_later x y
  let rec split_list greater_than acc = function 
    | (x::xs) -> if greater_than x then 
        (List.rev acc, x::xs)
      else 
        split_list greater_than (x::acc) xs
    | [] -> (List.rev acc, []) 

  (*Returns the cursor to the latest item it scanned from the participant mempool*)
  let process_new_updates () = 
    let rec get_all_rem_updates acc branches latest_known_cursors = (match branches, latest_known_cursors with
      | ((_,branch,_)::bs), (lkc::cursors) -> get_single_mempool_updates branch lkc >>= fun updates ->
        get_all_rem_updates (insert_list_into_list compare_tuples (updates, acc)) bs cursors
      | _ -> Lwt.return acc)
    in 
    let get_all_updates () = (
      get_all_rem_updates [] remotes_branches_names !latest_cursors >>= fun rem_updates ->  
      get_local_part_updates() >>= fun (loc_updates, latest_known_part_mempool) ->
      Lwt.return @@ (insert_list_into_list compare_tuples (rem_updates, loc_updates), latest_known_part_mempool)) 
    in
      get_all_updates() >>= fun (newupdates, latest_known_part_mempool) ->
      let items = List.rev (!updates_to_be_added) in 
      match items with 
        | [] -> buffered_updates := newupdates; Lwt.return latest_known_part_mempool
        | x::_ -> (*x is the latest item in updates_to_be_added*)
          (*find all the missed transactions andmerge into updates_to_be_added. put rest in buffered updates *)
          let newuptoadd, newup = split_list (fun y -> not (compare_tuples x y)) [] newupdates in
          updates_to_be_added := insert_list_into_list compare_tuples (!updates_to_be_added,newuptoadd);
          buffered_updates := newup;
          Lwt.return latest_known_part_mempool

  let update_from_remote remote branch = 
    try 
      pull_mem remote branch >>= fun _ -> Lwt.return ()
    with 
     | _ -> Logger.info "Error while pulling from remote"; Lwt.return ()

  (*This will sequentially merge changes from all the mempools in the known remotes*)
  let update_mempool () = 
    let rec update_mempools num = function 
      | (remote, branch, name)::xs -> (*Logger.info (Printf.sprintf "Starting Pull from remote %i at time %f" num (Ptime.to_float_s (Ptime_clock.now())));*)
        update_from_remote remote branch >>= fun _ ->
        (*Logger.info (Printf.sprintf "Finishing Pull from remote %i at time %f" num (Ptime.to_float_s (Ptime_clock.now()))); *)
        update_mempools (num+1) xs;
      | [] -> Lwt.return ()
    in 
      let time1 = (Ptime.to_float_s(Ptime_clock.now())) in
      update_mempools 0 remotes_branches_names >>= fun _ ->
      Logger.logg time1 (Ptime.to_float_s (Ptime_clock.now()));
      Lwt.return ()

   
  let interrupted_bool = ref false
  let interrupted_mvar = Lwt_mvar.create_empty()

  let update_cursors latest_known_part_cursor = 
    part_mempool_cursor := latest_known_part_cursor;
    IrminLogPartMem.read (get(!part_mempool_cursor)) ~num_items:1  >>= (function 
    | ([],_) -> Lwt.return ()
    | thing -> Lwt.return ()) >>= fun _ ->
    let rec get_updated_cursors acc = function 
      | [] -> Lwt.return acc
      | (_,branch,_)::xs -> get_updated_cursors (get(run @@ IrminLogMem.get_cursor branch ~path:path)::acc) xs
    in 
      get_updated_cursors [] remotes_branches_names >>= fun updated_cursors ->
      latest_cursors := List.rev updated_cursors;
      Lwt.return ()

  let get_all_transactions_from_blockchain () = 
    IrminLogBlock.get_cursor blockchain_master_branch [] >>= function 
      | Some(cursor) -> IrminLogBlock.read_all blockchain_master_branch [] >>= (function encoded_list ->
        let list = (List.map (Config.LogCoder.decode_string) encoded_list) in 
        Lwt.return (flat_map list))
      | _ -> Lwt.return []

  let rec run_leader () = 
    if !interrupted_bool then Lwt_mvar.put interrupted_mvar true >>= fun _ -> Lwt.return () else
    update_mempool() >>= 
    process_new_updates >>= fun latest_known_part_cursor ->
    let all_updates = List.map (fun (x,_) -> x) !updates_to_be_added in 
    updates_to_be_added := !buffered_updates;
    buffered_updates := [];
    update_cursors latest_known_part_cursor >>= fun _ ->
    if all_updates = [] then run_leader() else
    let perform_update updates = (  
      add_list_to_blockchain updates >>= fun _ ->
      Lwt.return @@ Logger.info (Printf.sprintf "\027[95mFound %i New Updates\027[39m\n%!" (List.length updates))>>= fun _ ->
      run_leader ()
      ) in
    match Config.validator with 
      | Some(f) -> 
        let decoded_updates = flat_map (List.map Config.LogCoder.decode_string all_updates) in
        get_all_transactions_from_blockchain() >>= fun blockchain ->
        let new_updates = f blockchain decoded_updates in
        let new_string_updates = List.map (Config.LogCoder.encode_string) new_updates in 
        perform_update new_string_updates
      | None -> perform_update all_updates
  
  let fail_nicely str = interrupted_bool := true;
    run (Lwt_mvar.take interrupted_mvar >>= fun _ -> 
      IrminLogBlock.read_all blockchain_master_branch ~path:path >>= fun blockchain ->
      Lwt.return @@ Printf.printf "\nHalting execution due to: %s%!" str)
    
  let register_handlers () = 
    let _ = Lwt_unix.on_signal Sys.sigterm (fun _ -> fail_nicely "SIGTERM\n") in
    let _ = Lwt_unix.on_signal Sys.sigint (fun _ -> fail_nicely "SIGINT\n") in 
    ()

  let add_genesis_and_update_cursors () = IrminLogMem.get_cursor mempool_master_branch ~path:path >>= function
      | None -> IrminLogMem.append ~message:"Entry added to the blockchain" mempool_master_branch ~path:path "Genesis Commit" >>= fun _ ->
        IrminLogBlock.append ~message:"Entry added to the blockchain" blockchain_master_branch ~path:path "Genesis Commit" >>= fun _ ->
        (*Merge genesis block into each remote*)
        List.iter (fun (_,branch,_) -> run @@ IrminLogMem.merge mempool_master_branch ~into: branch) remotes_branches_names; 
        (*Get latest cursors for all mempools*)
        latest_cursors := List.map (fun (rem,bra,name) -> get (run @@ IrminLogMem.get_cursor bra ~path:path)) remotes_branches_names;
        Lwt.return ()
      | curs -> latest_cursors := List.map (fun (rem,bra,name) -> get (run @@ IrminLogMem.get_cursor bra ~path:path)) remotes_branches_names;
        Lwt.return ()

  let add_part_genesis_and_cursor () = IrminLogPartMem.get_cursor part_mempool_master_branch ~path:path >>= function
    | None -> IrminLogPartMem.append ~message:"Entry added to the blockchain" part_mempool_master_branch ~path:path "Genesis Commit" >>= fun _ ->
      IrminLogPartMem.get_cursor part_mempool_master_branch ~path:path >>= (function
        | None -> raise Could_Not_Initialise_Blockchain
        | curs -> part_mempool_cursor := curs;
          Lwt.return ())
    | Some(curs) -> part_mempool_cursor := Some(curs);
      IrminLogPartMem.read curs ~num_items:1 >>= (function
        | x::_, _ when x = "Genesis Commit" -> Lwt.return ()
        | _ -> IrminLogPartMem.append ~message:"Entry added to the blockchain" part_mempool_master_branch ~path:path "Genesis Commit" >>= fun _ ->
          Lwt.return ()
      ) >>= 
      Lwt.return

  let init_leader () = 
    Logger.info "Starting Leader";
    register_handlers();  
    add_genesis_and_update_cursors() >>=
    add_part_genesis_and_cursor >>= fun _ ->
    Lwt.return run_leader
end;;
  