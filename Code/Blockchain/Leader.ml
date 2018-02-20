open Lwt.Infix

let write value = Lwt_io.write Lwt_io.stdout value
let read () = Lwt_io.read_line Lwt_io.stdin 

module type I_Config = sig 
  type t 
  module LogCoder: Participant.I_LogStringCoder with type t = t
  val remotes: string list
  val validator: (t list -> t list -> t list) option
end

module type I_Leader = sig
  val start_leader: unit -> unit Lwt.t
end

module Logger = struct 
  
  let error str = 
    let log = open_out_gen [Open_append] 0o640 "leader.log" in
    Printf.fprintf log "[ERROR] %s\n" str;
    close_out log

  let debug str = 
    let log = open_out "leader.log" in
    let log = open_out_gen [Open_append] 0o640 "leader.log" in
    Printf.fprintf log "[DEBUG] %s\n" str;
    close_out log

  let info str = 
    let log = open_out "leader.log" in
    let log = open_out_gen [Open_append] 0o640 "leader.log" in
    Printf.fprintf log "[INFO] %s\n" str;
    close_out log
end

module Make (Config: I_Config) : I_Leader = struct
  module IrminLog = Ezirmin.FS_log(Tc.String)
  let run = Lwt_main.run
  let path = []
  let blockchain_master_branch = run (IrminLog.init ~root: "/tmp/ezirminl/lead/blockchain" ~bare:true () >>= IrminLog.master)
  let mempool_master_branch = run (IrminLog.init ~root: "/tmp/ezirminl/lead/mempool" ~bare:true () >>= IrminLog.master)
  let local_mempool_master_branch = run (IrminLog.init ~root: "/tmp/ezirminl/part/mempool" ~bare:true () >>= IrminLog.master)
  let remotes = List.map (fun str -> IrminLog.Sync.remote_uri str) Config.remotes
  exception Validator_Not_Supplied
  exception Could_Not_Initialise_Blockchain

  let add_value_to_blockchain value = IrminLog.append ~message:"Entry added to the blockchain" blockchain_master_branch ~path:path value
  let add_list_to_blockchain list = Lwt_list.iter_s add_value_to_blockchain list 
  let mempool_cursor: IrminLog.cursor option ref = ref None

  let rec flat_map = function 
  | [] -> []
  | (Some(x)::xs) -> (x::(flat_map xs))
  | (None::xs) -> flat_map xs

  let rec get_with_cursor latest_known new_curs item_acc= 
    Lwt.return @@ IrminLog.is_earlier latest_known ~than:new_curs >>= function
      | Some(true) -> IrminLog.read ~num_items:1 new_curs >>= (function 
        | ([item], Some(new_cursor)) -> get_with_cursor latest_known new_cursor (item::item_acc)
        | _ ->Lwt.return item_acc)
      | _ -> Lwt.return item_acc
  
  (*This function gets new updates from the local mempool so they can be added to the blockchain*)
  (*Earliest messages will appear first in resulting list*)
  let get_new_updates () = 
      IrminLog.get_cursor mempool_master_branch ~path:path >>= fun new_mem_cursor ->
      match (!mempool_cursor, new_mem_cursor) with
        | (Some(latest_known), Some(new_curs)) -> get_with_cursor latest_known new_curs []
        | (None, Some(new_curs)) -> IrminLog.read ~num_items: 1 new_curs >>= (function 
          | (xs, _) -> Lwt.return xs)
        | _ -> Lwt.return []

  let update_from_remote remote = 
    try 
      IrminLog.Sync.pull remote mempool_master_branch `Merge >>= function
      | `Ok -> Logger.info "Successfully pulled from remote"; Lwt.return ()
      | _ -> Logger.info "Error while pulling from remote"; Lwt.return ()
    with 
     | _ -> Lwt.return ()

  let update_from_local_mempool () = 
    let add_value_to_mempool value = IrminLog.append ~message:"Entry added to the blockchain" mempool_master_branch ~path:path value in
    let add_list_to_mempool list = Lwt_list.iter_s add_value_to_mempool list in
    IrminLog.get_cursor mempool_master_branch ~path:path >>= fun leader_mempool ->
    IrminLog.get_cursor local_mempool_master_branch ~path:path >>= fun part_mempool ->
    match (leader_mempool, part_mempool) with
      | (Some(l_cursor), Some(p_cursor)) -> get_with_cursor l_cursor p_cursor [] >>= fun updates ->
        add_list_to_mempool updates
      | (None, Some(p_cursor)) -> IrminLog.read ~num_items: 1 p_cursor >>= fun (updates, _) ->
        add_list_to_mempool updates
      | _ -> Lwt.return ()

  (*This will sequentially merge changes from all the mempools in the known remotes*)
  let update_mempool () = let rems = Lwt_stream.of_list remotes in 
    Lwt_stream.iter_s update_from_remote rems
    
  let rec print_list list = match list with 
    | (x::[]) -> Lwt.return @@ Printf.printf "%s%!" x
    | (x::xs) -> Lwt.return @@ Printf.printf "%s\n%!" x >>= fun _ -> print_list xs
    | [] -> Lwt.return @@ ()

  let print_list () = Lwt.return @@ Printf.printf "\n\027[92m-----Start Block-----\027[32m\n" >>= fun _ ->
    IrminLog.read_all blockchain_master_branch [] >>= fun list ->
    print_list list >>= fun _ ->
    Lwt.return @@ Printf.printf "\n\027[93m-----Start MemPo-----\027[33m\n" >>= fun _ ->
    IrminLog.read_all mempool_master_branch [] >>= fun list ->
    print_list list >>= fun _ ->
    Lwt.return @@ Printf.printf "\n\027[91m------End MemPo------\027[39m\n\n%!"
   
  let interrupted_bool = ref false
  let interrupted_mvar = Lwt_mvar.create_empty()

  let get_all_transactions_from_blockchain () = 
    IrminLog.get_cursor blockchain_master_branch [] >>= function 
      | Some(cursor) -> IrminLog.read_all blockchain_master_branch [] >>= (function encoded_list ->
        let list = (List.map (Config.LogCoder.decode_string) encoded_list) in 
        Lwt.return (flat_map list))
      | _ -> Lwt.return []

  let rec run_leader () = 
    match !interrupted_bool with
    | true -> Lwt_mvar.put interrupted_mvar true >>= fun _ -> Lwt.return ()
    | false -> (
      update_from_local_mempool() >>= fun _ ->
      update_mempool() >>= fun _ ->
      get_new_updates() >>= function
      | [] -> Lwt_unix.sleep 1.0 >>= fun _ ->
        run_leader ()
      | all_updates -> (let perform_update updates = (
          add_list_to_blockchain updates >>= fun _ ->
          Lwt.return @@ Printf.printf "\027[95mFound New Updates:\027[39m\n%! " >>= fun _ ->
          print_list() >>= fun _ ->
          IrminLog.get_cursor mempool_master_branch ~path:path >>= fun new_cursor ->
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
      Lwt.return @@ Printf.printf "\nHalting execution due to: %s%!" str)
    
  let register_handlers () = 
    let _ = Lwt_unix.on_signal Sys.sigterm (fun _ -> fail_nicely "SIGTERM") in
    let _ = Lwt_unix.on_signal Sys.sigint (fun _ -> fail_nicely "SIGINT") in 
    ()

  let add_genesis_and_update_cursor () = IrminLog.get_cursor mempool_master_branch ~path:path >>= function
      | None -> IrminLog.append ~message:"Entry added to the blockchain" mempool_master_branch ~path:path "Genesis Commit" >>= fun _ ->
        IrminLog.append ~message:"Entry added to the blockchain" blockchain_master_branch ~path:path "Genesis Commit" >>= fun _ ->
        IrminLog.get_cursor mempool_master_branch ~path:path >>= (function 
          | None -> raise Could_Not_Initialise_Blockchain
          | curs -> mempool_cursor := curs;
            Lwt.return ())
      | curs -> mempool_cursor := curs;
        Lwt.return ()

  let start_leader () = 
    register_handlers();  
    add_genesis_and_update_cursor() >>= fun _ ->
    get_new_updates() >>= (function 
      | [] -> Lwt.return ()
      | updates -> add_list_to_blockchain updates) >>= fun _ ->
    print_list() >>= fun _ ->
    write "\027[95m\nBlockchain initialised. Press any key to start the leader: \027[95m" >>= fun _ ->
    read() >>= fun _ ->
    run_leader()
end;;
  