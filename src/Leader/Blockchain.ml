open Lwt.Infix

module type Remotes = sig 
  val remotes: string list
end

module type LeaderInterface = sig
  val start_leader: unit -> 'a Lwt.t
end

module Leader (Rem: Remotes) : LeaderInterface = struct
  module IrminLog = Ezirmin.FS_log(Tc.String)

  let blockchain_master_branch = Lwt_main.run (IrminLog.init ~root: "/tmp/ezirminl/blockchain" ~bare:true () >>= IrminLog.master)
  let mempool_master_branch = Lwt_main.run (IrminLog.init ~root: "/tmp/ezirminl/mempool" ~bare:true () >>= IrminLog.master)

  let run = Lwt_main.run
  let path = []

  let add_value_to_blockchain value = IrminLog.append ~message:"Entry added to the blockchain" blockchain_master_branch ~path:path value

  let add_genesis_to_mempool () = let message = "Genesis Commit" in 
    IrminLog.append ~message:"Entry added to the blockchain" mempool_master_branch ~path:path message

  let add_list_to_blockchain list = Lwt_list.iter_s add_value_to_blockchain list

  let rec get_with_cursor mem_cursor block_cursor item_acc= 
    Lwt.return @@ IrminLog.is_earlier block_cursor ~than:mem_cursor >>= function
      | Some(true) -> IrminLog.read ~num_items:1 mem_cursor >>= (function 
        | ([item], Some(new_cursor)) -> get_with_cursor new_cursor block_cursor (item::item_acc)
        | _ ->Lwt.return item_acc)
      | _ -> Lwt.return item_acc

  let get_new_updates () = 
    IrminLog.get_cursor blockchain_master_branch ~path:path >>= fun block_cursor ->
    IrminLog.get_cursor mempool_master_branch ~path:path >>= fun mem_cursor ->
    match (block_cursor, mem_cursor) with
      | (Some(bl_cursor), Some(m_cursor)) -> get_with_cursor m_cursor bl_cursor []
      | (None, Some(m_cursor)) -> IrminLog.read ~num_items: 1 m_cursor >>= (function 
        | (xs, _) ->Lwt.return xs)
      | _ -> Lwt.return []

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

  let rec run_leader () = get_new_updates() >>= function
    | [] -> Lwt_unix.sleep 1.0 >>= fun _ ->
        run_leader ()
    | updates -> add_list_to_blockchain updates >>= fun _ ->
        Lwt.return @@ Printf.printf "\027[95mFound New Updates:\027[39m\n%! " >>= fun _ ->
        print_list() >>= fun _ ->
        Lwt_unix.sleep 1.0 >>= fun _ ->
        run_leader ()

  let start_leader () = add_genesis_to_mempool() >>= fun _ ->
    run_leader()
end;;
  

(* The following code demonstrates how to start a leader, and on another thread, wait a few seconds and then add something to the mempool.
let waitAndAdd () = Lwt_unix.sleep 3.0 >>= fun _ ->
  add_transaction_to_mempool "New Value!"

let apply f = f()

let tasks = [start_leader;waitAndAdd];;

Lwt_main.run @@ Lwt_list.iter_p apply tasks;;  *)