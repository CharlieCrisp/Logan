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
  let mempool_cursor: IrminLogMem.cursor option ref = ref None
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
      | _ -> Lwt.return ()
  let add_list_to_blockchain list = Lwt_list.iter_s add_txn_to_blockchain list 

  let rec flat_map = function 
    | [] -> []
    | (Some(x)::xs) -> (x::(flat_map xs))
    | (None::xs) -> flat_map xs
  
  (*This function gets new updates from the leaders mempool so they can be added to the blockchain*)
  (*Earliest messages will appear first in resulting list*)
  let get_new_mempool_updates () = 
    let rec get_with_cursor latest_known new_curs item_acc = ( 
      Lwt.return @@ IrminLogMem.is_earlier latest_known ~than:new_curs >>= function
        | Some(true) -> IrminLogMem.read ~num_items:1 new_curs >>= (function 
          | ([item], Some(new_cursor)) -> get_with_cursor latest_known new_cursor (item::item_acc)
          | _ -> Lwt.return item_acc)
        | _ -> Lwt.return item_acc) in
      IrminLogMem.get_cursor mempool_master_branch ~path:path >>= fun new_mem_cursor ->
      match (!mempool_cursor, new_mem_cursor) with
        | (Some(latest_known), Some(new_curs)) -> get_with_cursor latest_known new_curs []
        | (None, Some(new_curs)) -> IrminLogPartMem.read ~num_items: 1 new_curs >>= (function 
          | (xs, _) -> Lwt.return xs)
        | _ -> Lwt.return []

  let update_from_remote remote = 
    try 
      pull_mem remote >>= fun _ -> Lwt.return ()
    with 
     | _ -> Logger.info "Error while pulling from remote"; Lwt.return ()

  let update_from_part_mempool () = 
    let rec get_with_cursor latest_known new_curs item_acc = ( 
      Lwt.return @@ IrminLogPartMem.is_earlier latest_known ~than:new_curs >>= function
        | Some(true) -> IrminLogPartMem.read ~num_items:1 new_curs >>= (function 
          | ([item], Some(new_cursor)) -> get_with_cursor latest_known new_cursor (item::item_acc)
          | _ -> Lwt.return item_acc)
        | _ -> Lwt.return item_acc) in
    let add_value_to_mempool value = IrminLogMem.append ~message:"Entry added to the blockchain" mempool_master_branch ~path:path value in
    let add_list_to_mempool list = Lwt_list.iter_s add_value_to_mempool list in
    IrminLogPartMem.get_cursor part_mempool_master_branch ~path:path >>= fun new_part_cursor ->
    match (!part_mempool_cursor, new_part_cursor) with
      | (Some(l_cursor), Some(p_cursor)) -> get_with_cursor l_cursor p_cursor [] >>= fun updates ->
        add_list_to_mempool updates >>= fun _ ->
        Lwt.return @@ (part_mempool_cursor := new_part_cursor)
      | (None, Some(p_cursor)) -> IrminLogMem.read ~num_items: 1 p_cursor >>= fun (updates, _) ->
        add_list_to_mempool updates >>= fun _ ->
        Lwt.return @@ (part_mempool_cursor := new_part_cursor)
      | _ -> Lwt.return ()

  (*This will sequentially merge changes from all the mempools in the known remotes*)
  let update_mempool () = 
    let rec update_mempools = function 
      | (x,str)::xs -> update_from_remote x >>= fun _ ->
        update_mempools xs;
      | [] -> Lwt.return ()
    in update_mempools remotes
   
  let interrupted_bool = ref false
  let interrupted_mvar = Lwt_mvar.create_empty()

  let get_all_transactions_from_blockchain () = 
    IrminLogBlock.get_cursor blockchain_master_branch [] >>= function 
      | Some(cursor) -> IrminLogBlock.read_all blockchain_master_branch [] >>= (function encoded_list ->
        let list = (List.map (Config.LogCoder.decode_string) encoded_list) in 
        Lwt.return (flat_map list))
      | _ -> Lwt.return []

  let rec run_leader () = 
    match !interrupted_bool with
    | true -> Lwt_mvar.put interrupted_mvar true >>= fun _ -> Lwt.return ()
    | false -> (
      update_from_part_mempool() >>= fun _ ->
      update_mempool() >>= fun _ ->
      get_new_mempool_updates() >>= function
      | [] -> Lwt_unix.sleep 1.0 >>= fun _ ->
        run_leader ()
      | all_updates -> (let perform_update updates = (  
        add_list_to_blockchain updates >>= fun _ ->
        Lwt.return @@ Logger.info (Printf.sprintf "\027[95mFound %i New Updates\027[39m\n%!" (List.length updates))>>= fun _ ->
        (* print_list() >>= fun _ -> *)
        IrminLogMem.get_cursor mempool_master_branch ~path:path >>= fun new_cursor ->
        mempool_cursor:= new_cursor;
        Lwt_unix.sleep 1.0 >>= fun _ -> 
        run_leader ()
        ) in
        match Config.validator with 
          | Some(f) -> 
            let decoded_updates = flat_map (List.map Config.LogCoder.decode_string all_updates) in
            get_all_transactions_from_blockchain() >>= fun blockchain ->
            let new_updates = f blockchain decoded_updates in
            let new_string_updates = List.map (Config.LogCoder.encode_string) new_updates in 
            perform_update new_string_updates
          | None -> perform_update all_updates))
  
  let fail_nicely str = interrupted_bool := true;
    run (Lwt_mvar.take interrupted_mvar >>= fun _ -> 
      IrminLogBlock.read_all blockchain_master_branch ~path:path >>= fun blockchain ->
      Lwt.return @@ Printf.printf "\nHalting execution due to: %s%!" str)
    
  let register_handlers () = 
    let _ = Lwt_unix.on_signal Sys.sigterm (fun _ -> fail_nicely "SIGTERM") in
    let _ = Lwt_unix.on_signal Sys.sigint (fun _ -> fail_nicely "SIGINT") in 
    ()

  let add_genesis_and_update_cursor () = IrminLogMem.get_cursor mempool_master_branch ~path:path >>= function
      | None -> IrminLogMem.append ~message:"Entry added to the blockchain" mempool_master_branch ~path:path "Genesis Commit" >>= fun _ ->
        IrminLogBlock.append ~message:"Entry added to the blockchain" blockchain_master_branch ~path:path "Genesis Commit" >>= fun _ ->
        IrminLogMem.get_cursor mempool_master_branch ~path:path >>= (function 
          | None -> raise Could_Not_Initialise_Blockchain
          | curs -> mempool_cursor := curs;
            Lwt.return ())
      | curs -> mempool_cursor := curs;
        Lwt.return ()

  let add_part_genesis_and_cursor () = IrminLogPartMem.get_cursor mempool_master_branch ~path:path >>= function
  | None -> IrminLogPartMem.append ~message:"Entry added to the blockchain" part_mempool_master_branch ~path:path "Genesis Commit" >>= fun _ ->
    IrminLogMem.get_cursor mempool_master_branch ~path:path >>= (function 
      | None -> raise Could_Not_Initialise_Blockchain
      | curs -> part_mempool_cursor := curs;
        Lwt.return ())
  | curs -> part_mempool_cursor := curs;
    Lwt.return ()

  let init_leader () = 
    Logger.info "Starting Leader";
    register_handlers();  
    add_genesis_and_update_cursor() >>= 
    add_part_genesis_and_cursor >>=
    get_new_mempool_updates >>= (function 
      | [] -> Lwt.return ()
      | updates -> add_list_to_blockchain updates) >>= fun _ -> 
        Lwt.return (fun () -> run_leader())
end;;
  