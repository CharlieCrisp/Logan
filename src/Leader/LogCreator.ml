open Lwt.Infix
module IrminLogBlock = Ezirmin.FS_log(Tc.String)
module IrminLogMem = Ezirmin.FS_log(Tc.String)

let blockchain_master_branch = Lwt_main.run (IrminLogBlock.init ~root: "/tmp/ezirminl/blockchain" ~bare:true () >>= IrminLogBlock.master)
let mempool_master_branch = Lwt_main.run (IrminLogMem.init ~root: "/tmp/ezirminl/mempool" ~bare:true () >>= IrminLogMem.master)

let run = Lwt_main.run
let path = []

(*TODO: remove wip branch after merge*)
let add_value_to_blockchain value = IrminLogBlock.clone_force blockchain_master_branch "wip" >>= fun wip_branch ->
  IrminLogBlock.append ~message:"Entry added to the blockchain" wip_branch ~path:path value >>= fun _ -> 
  IrminLogBlock.merge wip_branch ~into:blockchain_master_branch

(*TODO: remove wip branch after merge*)
let add_transaction_to_mempool value =
  let message = LogStringCoder.encode_string "some id" "another id" value in 
  IrminLogMem.clone_force mempool_master_branch "wip" >>= fun wip_branch ->
  IrminLogMem.append ~message:"Entry added to the blockchain" wip_branch ~path:path message >>= fun _ -> 
  IrminLogMem.merge wip_branch ~into:mempool_master_branch

let add_list_to_blockchain list = Lwt_list.iter_s add_value_to_blockchain list

let get_latest_blockchain_message () = IrminLogBlock.get_cursor blockchain_master_branch ~path:path >>= function
    | Some(cursor) -> IrminLogBlock.read cursor ~num_items:1 >>= (function
      | (x::_, _) -> Lwt.return @@ Some(x)
      | _ -> Lwt.return None)
    | None -> Lwt.return None

let rec count_with_cursor ?(n=0) (comparison_message:string) cursor = 
  (*read one more item and check if it's same as comparison_message*)
  IrminLogMem.read cursor ~num_items:1 >>= function
      | (mempool_message::_, _) when mempool_message = comparison_message -> Lwt.return (Some(n))
      | (_, None) -> Lwt.return (Some(n))
      | (_, Some(curs)) -> count_with_cursor ~n:(n+1) comparison_message curs (*try the next one*)

(*TODO: s there a way to use >>= (or similar) below, rather than let statements?*)
(*Count how many new items there are in the memPool*)
let count_new_updates () = 
  get_latest_blockchain_message() >>= fun latest_message ->
  IrminLogMem.get_cursor mempool_master_branch ~path:path >>= fun cursor ->
  match (latest_message, cursor) with 
    |(Some(committed_message), Some(initial_cursor)) -> count_with_cursor committed_message initial_cursor
    |(None, Some(initial_cursor)) -> count_with_cursor "NOT A MESSAGE" initial_cursor
    | _ -> Lwt.return None

let get_new_updates () = 
  IrminLogMem.get_cursor mempool_master_branch ~path:path >>= fun cursor ->
  count_new_updates () >>= fun number_of_updates ->
  match (cursor,number_of_updates) with
    | (Some(curs), Some(updates)) -> (IrminLogMem.read curs ~num_items:updates >>= function
      | (list, _) -> Lwt.return @@ Some(list))
    | _ -> Lwt.return None

let rec print_list list = match list with 
  | (x::[]) -> Lwt.return @@ Printf.printf "%s%!" x
  | (x::xs) -> Lwt.return @@ Printf.printf "%s\n%!" x >>= fun _ -> print_list xs
  | [] -> Lwt.return @@ ()

let print_list () = Lwt.return @@ Printf.printf "\n\027[92m-----Start Block-----\027[32m\n" >>= fun _ ->
  IrminLogBlock.read_all blockchain_master_branch [] >>= fun list ->
  print_list list >>= fun _ ->
  Lwt.return @@ Printf.printf "\n\027[93m-----Start MemPo-----\027[33m\n" >>= fun _ ->
  IrminLogMem.read_all mempool_master_branch [] >>= fun list ->
  print_list list >>= fun _ ->
  Lwt.return @@ Printf.printf "\n\027[91m------End MemPo------\027[39m\n\n%!"

let rec run_leader () = get_new_updates() >>= function 
  | None -> Lwt_unix.sleep 1.0 >>= fun _ ->
      run_leader ()
  | Some([]) -> Lwt_unix.sleep 1.0 >>= fun _ ->
      run_leader ()
  | Some(updates) -> add_list_to_blockchain updates >>= fun _ ->
      Lwt.return @@ Printf.printf "\027[95mFound New Updates:\027[39m\n%! " >>= fun _ ->
      print_list() >>= fun _ ->
      Lwt_unix.sleep 1.0 >>= fun _ ->
      run_leader ()

let start_leader () = add_transaction_to_mempool "New Leader" >>= fun _ ->
  run_leader();;     

Lwt_main.run @@ start_leader () ;;
  

(* The following code demonstrates how to start a leader, and on another thread, wait a few seconds and then add something to the mempool.
let waitAndAdd () = Lwt_unix.sleep 3.0 >>= fun _ ->
  add_transaction_to_mempool "New Value!"

let apply f = f()

let tasks = [start_leader;waitAndAdd];;

Lwt_main.run @@ Lwt_list.iter_p apply tasks;;  *)

(*
#use "Documents/CompSci/PartIIProject/src/Leader/LogCreator.ml";;

Setup - get the ip of the leader and then ask for user to enter transactions
Transactions can also be registering of items (maybe from a set registration id)

Then need some mechanism for changing leader... is this possible without http requests?
*)