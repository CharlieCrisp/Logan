open Lwt.Infix

let write value = Lwt_io.write Lwt_io.stdout value
let read () = Lwt_io.read_line Lwt_io.stdin 

module type I_Remotes = sig 
  val remotes: string list
end

module type I_Leader = sig
  val start_leader: unit -> unit Lwt.t
end

module Make (Rem: I_Remotes) : I_Leader = struct
  module IrminLog = Ezirmin.FS_log(Tc.String)
  let run = Lwt_main.run
  let path = []
  let blockchain_master_branch = run (IrminLog.init ~root: "/tmp/ezirminl/lead/blockchain" ~bare:true () >>= IrminLog.master)
  let mempool_master_branch = run (IrminLog.init ~root: "/tmp/ezirminl/lead/mempool" ~bare:true () >>= IrminLog.master)
  let local_mempool_master_branch = run (IrminLog.init ~root: "/tmp/ezirminl/part/mempool" ~bare:true () >>= IrminLog.master)
  let remotes = List.map (fun str -> IrminLog.Sync.remote_uri str) Rem.remotes

  let add_value_to_blockchain value = IrminLog.append ~message:"Entry added to the blockchain" blockchain_master_branch ~path:path value
  let add_list_to_blockchain list = Lwt_list.iter_s add_value_to_blockchain list 

  let rec get_with_cursor mem_cursor block_cursor item_acc= 
    Lwt.return @@ IrminLog.is_earlier block_cursor ~than:mem_cursor >>= function
      | Some(true) -> IrminLog.read ~num_items:1 mem_cursor >>= (function 
        | ([item], Some(new_cursor)) -> get_with_cursor new_cursor block_cursor (item::item_acc)
        | _ ->Lwt.return item_acc)
      | _ -> Lwt.return item_acc
  
  (*This function gets new updates from the local mempool so they can be added to the blockchain*)
  (*Earliest messages will appear first in resulting list*)
  let get_new_updates () = 
    IrminLog.get_cursor blockchain_master_branch ~path:path >>= fun block_cursor ->
    IrminLog.get_cursor mempool_master_branch ~path:path >>= fun mem_cursor ->
    match (block_cursor, mem_cursor) with
      | (Some(bl_cursor), Some(m_cursor)) -> get_with_cursor m_cursor bl_cursor []
      | (None, Some(m_cursor)) -> IrminLog.read ~num_items: 1 m_cursor >>= (function 
        | (xs, _) ->Lwt.return xs)
      | _ -> Lwt.return []

  let update_from_remote remote = 
    IrminLog.Sync.pull remote mempool_master_branch `Merge >>= function
    | `Ok -> Printf.printf "Successfully pulled from remote"; Lwt.return ()
    | _ -> Printf.printf "Error while pulling from remote"; Lwt.return ()

  let update_from_local_mempool () = 
    let add_value_to_mempool value = IrminLog.append ~message:"Entry added to the blockchain" mempool_master_branch ~path:path value in
    let add_list_to_mempool list = Lwt_list.iter_s add_value_to_mempool list in
    IrminLog.get_cursor mempool_master_branch ~path:path >>= fun leader_mempool ->
    IrminLog.get_cursor local_mempool_master_branch ~path:path >>= fun part_mempool ->
    match (leader_mempool, part_mempool) with
      | (Some(l_cursor), Some(p_cursor)) -> get_with_cursor p_cursor l_cursor [] >>= fun updates ->
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

  let rec run_leader () = 
    match !interrupted_bool with
    | true -> Lwt_mvar.put interrupted_mvar true >>= fun _ -> Lwt.return ()
    | false -> (
      update_from_local_mempool() >>= fun _ ->
      update_mempool() >>= fun _ ->
      get_new_updates() >>= function
      | [] -> Lwt_unix.sleep 1.0 >>= fun _ ->
          run_leader ()
      | updates -> add_list_to_blockchain updates >>= fun _ ->
          Lwt.return @@ Printf.printf "\027[95mFound New Updates:\027[39m\n%! " >>= fun _ ->
          print_list() >>= fun _ ->
          Lwt_unix.sleep 1.0 >>= fun _ ->
          run_leader ())
  
  let fail_nicely str = interrupted_bool := true;
    run (Lwt_mvar.take interrupted_mvar >>= fun _ -> 
      Lwt.return @@ Printf.printf "\nHalting execution due to: %s%!" str)
    
  let register_handlers () = 
    let _ = Lwt_unix.on_signal Sys.sigterm (fun _ -> fail_nicely "SIGTERM") in
    let _ = Lwt_unix.on_signal Sys.sigint (fun _ -> fail_nicely "SIGINT") in 
    ()

  let start_leader () = let add_genesis_to_mempool () = (let message = "Genesis Commit" in 
    IrminLog.append ~message:"Entry added to the blockchain" mempool_master_branch ~path:path message) in
    register_handlers();  
    add_genesis_to_mempool() >>= fun _ ->
    get_new_updates() >>= (function 
      | [] -> Lwt.return ()
      | updates -> add_list_to_blockchain updates) >>= fun _ ->
    print_list() >>= fun _ ->
    write "\027[95m\nBlockchain initialised. Press any key to start the leader: \027[95m" >>= fun _ ->
    read() >>= fun _ ->
    run_leader()
end;;
  