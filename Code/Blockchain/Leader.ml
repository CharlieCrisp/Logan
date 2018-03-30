open Lwt.Infix

module Logger = Logger.Logger

module type I_Validator = sig 
  type t 
  val init: t list -> unit Lwt.t (*Accept any transactions already in the blockchain, initialise state then return when ready*)
  val filter: t list -> t list Lwt.t
end

module type I_Config = sig 
  type t 
  module LogCoder: Participant.I_LogStringCoder with type t = t
  module Validator: I_Validator with type t = t
  val remotes: string list
  val replicas: string list
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

  (*Do in setup*)
  let mem_branches = ref []

  (*tuples of *)
  let userathosts = Config.remotes
  let latest_cursors: IrminLogMem.cursor list ref = ref []
  let buffered_updates = ref []
  let updates_to_be_added = ref []
  let cache_branch = ref None

  exception Validator_Not_Supplied
  exception Could_Not_Initialise_Blockchain
  exception Option_Unwrapping

  let remove_at str = Str.global_replace (Str.regexp "@")"" str

  let add_all_remotes () = 
    let add_single_remote userathost = (
      let userhost = remove_at userathost in 
      let cd_directory = "cd /tmp/ezirminl/lead/mempool; " in
      let add_remote = Printf.sprintf "git remote add %s ssh://%s/tmp/ezirminl/part/mempool; " userhost userathost in 
      let fetch_remote = Printf.sprintf "git fetch %s; " userhost in 
      let checkout_master = "git checkout master; " in
      let checkout_new_master = Printf.sprintf "git checkout -b %s; " userhost in
      let set_master_upstream = Printf.sprintf "git branch -u %s/master; " userhost in 
      let checkout_internal = "git checkout internal; " in
      let checkout_new_internal = Printf.sprintf "git checkout -b %sinternal; " userhost in 
      let set_internal_upstream = Printf.sprintf "git branch -u %s/internal; " userhost in 
      let command = cd_directory ^ add_remote ^ fetch_remote ^ checkout_master ^ checkout_new_master ^ set_master_upstream ^ 
        checkout_internal ^ checkout_new_internal ^ set_internal_upstream ^ checkout_master in 
      Lwt.return @@ Sys.command command >>= fun _ ->
      Lwt.return () ) in 
    let add_remote_promise_list = List.map add_single_remote userathosts in
    Lwt.join add_remote_promise_list >>= fun _ ->
    Lwt.return ()

  let update_mempool () = 
    let pull_mempool userathost = (
      let userhost = remove_at userathost in 
      let cd_directory = "cd /tmp/ezirminl/lead/mempool; " in
      let checkout_master = Printf.sprintf "git checkout %s; " userhost in
      let pull_master = Printf.sprintf "git pull; " in 
      let checkout_internal = Printf.sprintf "git checkout %sinternal; " userhost in
      let pull_internal = Printf.sprintf "git pull; " in 
      let _ = Sys.command (cd_directory ^ checkout_master ^ pull_master ^ checkout_internal ^ pull_internal) in
      ()) in 
    let _ = List.iter pull_mempool userathosts in
    Lwt.return ()

  let get = function 
    | Some x -> x
    | None -> raise Option_Unwrapping

  let add_value_to_blockchain value = 
    IrminLogBlock.append ~message:"Entry added to the blockchain" blockchain_master_branch ~path:path value
  (*Decode and re-encode value so as to get new timestamp*)

  let add_txn_to_blockchain value = 
    let add_to_cache branch = (
    let txn_opt = Config.LogCoder.decode_string value in
    match txn_opt with 
      | Some(txn) -> let txn_string = Config.LogCoder.encode_string txn in
        IrminLogBlock.append ~message:"Entry added to the blockchain" branch ~path:path txn_string
      | _ -> Printf.printf "Couldn't reconstruct log item\n%!"; Lwt.return ()) in 
    match !cache_branch with 
      | Some(branch) -> add_to_cache branch
      | None -> IrminLogBlock.clone_force blockchain_master_branch "cache" >>= fun branch ->
        cache_branch :=  Some(branch);
        add_to_cache branch

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
      | (branch::bs), (lkc::cursors) -> get_single_mempool_updates branch lkc >>= fun updates ->
        get_all_rem_updates (insert_list_into_list compare_tuples (updates, acc)) bs cursors
      | _ -> Lwt.return acc)
    in 
    let get_all_updates () = (
      get_all_rem_updates [] !mem_branches !latest_cursors >>= fun rem_updates ->  
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
   
  let interrupted_bool = ref false
  let interrupted_mvar = Lwt_mvar.create_empty()

  let update_cursors latest_known_part_cursor = 
    part_mempool_cursor := latest_known_part_cursor;
    IrminLogPartMem.read (get(!part_mempool_cursor)) ~num_items:1  >>= (function 
    | ([],_) -> Lwt.return ()
    | thing -> Lwt.return ()) >>= fun _ ->
    let rec get_updated_cursors acc = function 
      | [] -> Lwt.return acc
      | branch::xs -> get_updated_cursors (get(run @@ IrminLogMem.get_cursor branch ~path:path)::acc) xs
    in 
      get_updated_cursors [] !mem_branches >>= fun updated_cursors ->
      latest_cursors := List.rev updated_cursors;
      Lwt.return ()

  let get_all_transactions_from_blockchain () = 
    IrminLogBlock.get_cursor blockchain_master_branch [] >>= function 
      | Some(cursor) -> IrminLogBlock.read_all blockchain_master_branch [] >>= (function encoded_list ->
        let list = (List.map (Config.LogCoder.decode_string) encoded_list) in 
        Lwt.return (flat_map list))
      | _ -> Lwt.return []

  let push_replicas () = 
    let get_replica_command str = Sys.command (Printf.sprintf "cd /tmp/ezirminl/lead/blockchain; git push ssh://%s/tmp/ezirminl/replica/blockchain cache:cache; cd -" str) in 
    let commands = List.map get_replica_command Config.replicas in
    let threads = List.map (fun com -> Lwt.return com >>= fun _ -> Lwt.return ()) commands in
    Lwt.join threads

  let merge_blockchain () = 
    match !cache_branch with 
      | Some(branch) -> IrminLogBlock.merge branch ~into: blockchain_master_branch
      | None -> Lwt.return ()

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
      add_list_to_blockchain updates >>= 
      push_replicas >>=
      merge_blockchain >>= fun _ ->
      Lwt.return @@ Logger.info (Printf.sprintf "\027[95mAdded %i New Updates\027[39m\n%!" (List.length updates))>>= fun _ ->
      run_leader ()
      ) in
    let decoded_updates = flat_map (List.map Config.LogCoder.decode_string all_updates) in
    Config.Validator.filter decoded_updates >>= fun new_updates ->
    let new_string_updates = List.map (Config.LogCoder.encode_string) new_updates in 
    perform_update new_string_updates

  let fail_nicely str = interrupted_bool := true;
    run (Lwt_mvar.take interrupted_mvar >>= fun _ -> 
      IrminLogBlock.read_all blockchain_master_branch ~path:path >>= fun blockchain ->
      Lwt.return @@ Printf.printf "\nHalting execution due to: %s%!" str)
    
  let register_handlers () = 
    let _ = Lwt_unix.on_signal Sys.sigterm (fun _ -> fail_nicely "SIGTERM\n") in
    let _ = Lwt_unix.on_signal Sys.sigint (fun _ -> fail_nicely "SIGINT\n") in 
    ()

  let add_genesis () = IrminLogMem.get_cursor mempool_master_branch ~path:path >>= function
      | None -> IrminLogMem.append ~message:"Entry added to the blockchain" mempool_master_branch ~path:path "Genesis Commit" >>= fun _ ->
        IrminLogBlock.append ~message:"Entry added to the blockchain" blockchain_master_branch ~path:path "Genesis Commit" >>= fun _ ->
        Lwt.return ()
      | curs -> Lwt.return ()
  
  let init_branches_and_cursors () = 
    let get_branch str = run (IrminLogMem.get_branch mempool_repo (remove_at str)) in
    mem_branches := List.map (fun str -> get_branch str) Config.remotes;
    latest_cursors := List.map (fun bra -> get (run @@ IrminLogMem.get_cursor bra ~path:path)) !mem_branches


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
    add_genesis() >>=
    add_part_genesis_and_cursor >>= fun _ ->
    get_all_transactions_from_blockchain () >>= fun txns ->
    Config.Validator.init txns >>= fun _ ->
    Lwt.return (fun () -> 
      add_all_remotes () >>= fun () -> 
      init_branches_and_cursors();
      Printf.printf "Ready\n%!";
      run_leader())
end;;
