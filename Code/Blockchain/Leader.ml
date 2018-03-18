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
  let remotes = List.map (fun str -> (IrminLogMem.Sync.remote_uri str, str)) Config.remotes
  let internal_branch = run @@ IrminLogMem.get_branch mempool_repo "internal"
  let mempool_cursor_earlier: IrminLogMem.cursor option ref = ref None
  let mempool_cursor_later: IrminLogMem.cursor option ref = ref None
  let part_mempool_cursor: IrminLogPartMem.cursor option ref = ref None
  exception Validator_Not_Supplied
  exception Could_Not_Initialise_Blockchain

  let ignore_lwt t = t >|= fun _ -> ()

  let pull_mem remote_mem = Lwt.join [ignore_lwt @@ IrminLogMem.Sync.pull remote_mem internal_branch `Merge;
    ignore_lwt @@ IrminLogMem.Sync.pull remote_mem mempool_master_branch `Merge]

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
  let get_new_updates () = 
    let earlier_or_equal cursor1 ~than:cursor2 = (
      match IrminLogMem.is_earlier cursor1 ~than:cursor2, IrminLogMem.is_earlier cursor2 ~than:cursor1 with
        | Some(true), _ -> Some(true)
        | Some(false), Some(false) -> Some(true)
        | _ -> Some(false)) in
    let rec get_with_cursor earlier_curs later_curs scanning_curs item_acc = ( 
      (*We add whatever our latest pointer is pointing to up until (but not including) what our earlier pointer points to*)
      (*In the case that we've already added our latest pointer item, 
        our earlier pointer will point to this item too, and this will mean it is not added because it is not late_enough *)
      let is_early_enough = earlier_or_equal scanning_curs ~than:later_curs in
      let is_late_enough = IrminLogMem.is_later scanning_curs ~than:earlier_curs in
      match is_early_enough, is_late_enough with
        | Some(false), Some(true) -> IrminLogMem.read ~num_items:1 scanning_curs >>= (function 
          | (_, Some(new_scanning_cursor)) -> get_with_cursor earlier_curs later_curs new_scanning_cursor item_acc
          | _ -> Lwt.return item_acc)
        | Some(true), Some(true) -> IrminLogMem.read ~num_items:1 scanning_curs >>= (function 
          | ([item], Some(new_scanning_cursor)) when item <> "Genesis Commit" -> get_with_cursor earlier_curs later_curs new_scanning_cursor (item::item_acc)
          | _ -> Lwt.return item_acc)
        | _ -> Lwt.return item_acc) in
      (*Logger.info (Printf.sprintf "Starting retrieval of new mempool updates at time %f" (Ptime.to_float_s (Ptime_clock.now())));*)
      IrminLogMem.get_cursor mempool_master_branch ~path:path >>= fun newest_cursor_opt ->
      match (!mempool_cursor_earlier, !mempool_cursor_later, newest_cursor_opt) with
        | (Some(earlier_curs), Some(later_curs), Some(newest_curs)) -> get_with_cursor earlier_curs later_curs newest_curs []
        | _ -> (*Logger.info (Printf.sprintf "Finishing retrieval of new mempool updates at time %f\n" (Ptime.to_float_s (Ptime_clock.now())));*) Lwt.return []

  let update_from_remote remote = 
    try 
      pull_mem remote >>= fun _ -> Lwt.return ()
    with 
     | _ -> Logger.info "Error while pulling from remote"; Lwt.return ()

  let update_mem_from_local_part () = 
    let rec get_with_cursor latest_known new_curs item_acc = ( 
      Lwt.return @@ IrminLogPartMem.is_earlier latest_known ~than:new_curs >>= function
        | Some(true) -> IrminLogPartMem.read ~num_items:1 new_curs >>= (function 
          | ([item], Some(new_cursor)) when item <> "Genesis Commit" -> get_with_cursor latest_known new_cursor (item::item_acc)
          | _ -> Lwt.return item_acc)
        | _ -> Lwt.return item_acc) in
    let add_value_to_mempool value = IrminLogMem.append ~message:"Entry added to the blockchain" mempool_master_branch ~path:path value in
    let add_list_to_mempool list = Lwt_list.iter_s add_value_to_mempool list in
    IrminLogPartMem.get_cursor part_mempool_master_branch ~path:path >>= fun new_part_cursor ->
    match (!part_mempool_cursor, new_part_cursor) with
      | (Some(l_cursor), Some(p_cursor)) -> get_with_cursor l_cursor p_cursor [] >>= fun updates ->
        add_list_to_mempool updates >>= fun _ ->
        Lwt.return @@ (part_mempool_cursor := new_part_cursor)
      | (None, Some(p_cursor)) ->
        Lwt.return @@ (part_mempool_cursor := new_part_cursor)
      | _ -> Lwt.return ()

  (*This will sequentially merge changes from all the mempools in the known remotes*)
  let update_mempool () = 
    let rec update_mempools num = function 
      | (x,str)::xs -> (*Logger.info (Printf.sprintf "Starting Pull from remote %i at time %f" num (Ptime.to_float_s (Ptime_clock.now())));*)
        update_from_remote x >>= fun _ ->
        (*Logger.info (Printf.sprintf "Finishing Pull from remote %i at time %f" num (Ptime.to_float_s (Ptime_clock.now()))); *)
        update_mempools (num+1) xs;
      | [] -> Lwt.return ()
    in update_mempools 0 remotes
   
  let interrupted_bool = ref false
  let interrupted_mvar = Lwt_mvar.create_empty()

  let get_all_transactions_from_blockchain () = 
    IrminLogBlock.get_cursor blockchain_master_branch [] >>= function 
      | Some(cursor) -> IrminLogBlock.read_all blockchain_master_branch [] >>= (function encoded_list ->
        let list = (List.map (Config.LogCoder.decode_string) encoded_list) in 
        Lwt.return (flat_map list))
      | _ -> Lwt.return []

  let rec run_leader () = 
    if !interrupted_bool then Lwt_mvar.put interrupted_mvar true >>= fun _ -> Lwt.return () else
    update_mem_from_local_part() >>= fun _ ->
    update_mempool() >>= fun _ ->
    get_new_updates() >>= fun all_updates -> 
    mempool_cursor_earlier := !mempool_cursor_later;
    mempool_cursor_later := (run @@ (IrminLogMem.get_cursor mempool_master_branch ~path:path));
    if all_updates = [] then Lwt_unix.sleep 1.0 >>= run_leader else
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

  let add_genesis_and_update_cursor () = IrminLogMem.get_cursor mempool_master_branch ~path:path >>= function
      | None -> IrminLogMem.append ~message:"Entry added to the blockchain" mempool_master_branch ~path:path "Genesis Commit" >>= fun _ ->
        IrminLogBlock.append ~message:"Entry added to the blockchain" blockchain_master_branch ~path:path "Genesis Commit" >>= fun _ ->
        IrminLogMem.get_cursor mempool_master_branch ~path:path >>= (function 
          | None -> raise Could_Not_Initialise_Blockchain
          | curs -> mempool_cursor_earlier := curs; mempool_cursor_later := curs;
            Lwt.return ())
      | curs -> mempool_cursor_earlier := curs; mempool_cursor_later := curs;
        Lwt.return ()

  let add_part_genesis_and_cursor () = IrminLogPartMem.get_cursor part_mempool_master_branch ~path:path >>= function
    | None -> IrminLogPartMem.append ~message:"Entry added to the blockchain" part_mempool_master_branch ~path:path "Genesis Commit" >>= fun _ ->
      IrminLogPartMem.get_cursor mempool_master_branch ~path:path >>= (function
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
    add_genesis_and_update_cursor() >>= 
    add_part_genesis_and_cursor >>=
    get_new_updates >>= fun updates ->
    add_list_to_blockchain updates >>= fun _ -> 
    Lwt.return (fun () -> run_leader())
end;;
  