(*TODO: why are we adding a value every second...?*)
open Lwt.Infix
module IrminLogBlock = Ezirmin.Memory_log(Tc.String)
module IrminLogMem = Ezirmin.Memory_log(Tc.String)

let blockchainMasterBranch = Lwt_main.run (IrminLogBlock.init ~root: "/tmp/ezirminl/blockchain" ~bare:true () >>= IrminLogBlock.master)
let memPoolMasterBranch = Lwt_main.run (IrminLogMem.init ~root: "/tmp/ezirminl/mempool" ~bare: true () >>= IrminLogMem.master)

let run = Lwt_main.run
let path = []

(*TODO: remove wip branch after merge*)
(*string -> unit Lwt.t*)
let addValueToBlockchain value = IrminLogBlock.clone_force blockchainMasterBranch "wip" >>= fun wipBranch ->
  IrminLogBlock.append ~message:"Entry added to the blockchain" wipBranch ~path:path value >>= fun _ -> 
  IrminLogBlock.merge wipBranch ~into:blockchainMasterBranch

(*TODO: remove wip branch after merge*)
(*string -> unit Lwt.t*)
let addValueToMemPool value = IrminLogMem.clone_force memPoolMasterBranch "wip" >>= fun wipBranch ->
  IrminLogMem.append ~message:"Entry added to the blockchain" wipBranch ~path:path value >>= fun _ -> 
  IrminLogMem.merge wipBranch ~into:memPoolMasterBranch

(*string list -> unit Lwt.t*)
let addListToBlockchain list = Lwt_list.iter_s addValueToBlockchain list

(*unit -> string option Lwt.t*)
let getLatestBlockchainMessage () = IrminLogBlock.get_cursor blockchainMasterBranch ~path:path >>= function
    | Some(cursor) -> IrminLogBlock.read cursor ~num_items:1 >>= (function
      | (x::_, _) -> Lwt.return @@ Some(x)
      | _ -> Lwt.return None)
    | None -> Lwt.return None

(*?n:int -> string -> cursor -> int option Lwt.t*)
let rec countWithCursor ?(n=0) (comparisonMessage:string) cursor = 
  (*read one more item and check if it's same as comparisonMessage*)
  (*string list * cursor option*)
  IrminLogMem.read cursor ~num_items:1 >>= function
      | (memPoolMessage::_, _) when memPoolMessage = comparisonMessage -> Lwt.return (Some(n))
      | (_, None) -> Lwt.return (Some(n))
      | (_, Some(curs)) -> countWithCursor ~n:(n+1) comparisonMessage curs (*try the next one*)

(*TODO: s there a way to use >>= (or similar) below, rather than let statements?*)
(*Count how many new items there are in the memPool*)
(*unit -> int option Lwt.t*)
let countNewUpdates () = 
  getLatestBlockchainMessage() >>= fun latestMessage ->
  IrminLogMem.get_cursor memPoolMasterBranch ~path:path >>= fun cursor ->
  match (latestMessage, cursor) with 
    |(Some(committedMessage), Some(initCursor)) -> countWithCursor committedMessage initCursor
    |(None, Some(initCursor)) -> countWithCursor "NOT A MESSAGE" initCursor
    | _ -> Lwt.return None


(*unit -> string list option*)
let getNewUpdates () = 
  IrminLogMem.get_cursor memPoolMasterBranch ~path:path >>= fun cursor ->
  countNewUpdates () >>= fun numberOfUpdates ->
  match (cursor,numberOfUpdates) with
    | (Some(curs), Some(updates)) -> (IrminLogMem.read curs ~num_items:updates >>= function
      | (list, _) -> Lwt.return @@ Some(list))
    | _ -> Lwt.return None

let rec printList list = match list with 
  | (x::[]) -> Lwt.return @@ Printf.printf "| %s%!" x
  | (x::xs) -> Lwt.return @@ Printf.printf "| %s\n%!" x >>= fun _ -> printList xs
  | [] -> Lwt.return @@ Printf.printf "|"

let printList () = Lwt.return @@ Printf.printf "\n-----Start Block-----\n" >>= fun _ ->
  IrminLogBlock.read_all blockchainMasterBranch [] >>= fun list ->
  printList list >>= fun _ ->
  Lwt.return @@ Printf.printf "\n-----Start MemPo-----\n" >>= fun _ ->
  IrminLogMem.read_all memPoolMasterBranch [] >>= fun list ->
  printList list >>= fun _ ->
  Lwt.return @@ Printf.printf "\n------End MemPo------\n\n%!"

(*unit -> 'a Lwt.t*)
let rec runLeader () = getNewUpdates() >>= function 
  | None -> Lwt_unix.sleep 1.0 >>= fun _ ->
      runLeader ()
  | Some([]) -> Lwt_unix.sleep 1.0 >>= fun _ ->
      runLeader ()
  | Some(updates) -> addListToBlockchain updates >>= fun _ ->
      Lwt.return @@ Printf.printf "Found New Updates:\n%! " >>= fun _ ->
      printList() >>= fun _ ->
      Lwt_unix.sleep 1.0 >>= fun _ ->
      runLeader ()

(* unit -> 'a Lwt.t*)
let startLeader () = addValueToMemPool "New Leader" >>= fun _ ->
  runLeader();;     

Lwt_main.run @@ startLeader () ;;
  
(*
The following code demonstrates how to start a leader, and on another thread, wait a few seconds and then add something to the mempool.
let waitAndAdd () = Lwt_unix.sleep 3.0 >>= fun _ ->
  addValueToMemPool "New Value!"

let apply f = f()

let tasks = [startLeader;waitAndAdd];;

Lwt_main.run @@ Lwt_list.iter_p apply tasks;; 
*)
(*
#use "Documents/CompSci/PartIIProject/src/Leader/LogCreator.ml";;

Setup - get the ip of the leader and then ask for user to enter transactions
Transactions can also be registering of items (maybe from a set registration id)

Then need some mechanism for changing leader... is this possible without http requests?
*)