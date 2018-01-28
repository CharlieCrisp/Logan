open Lwt.Infix
module IrminLogBlock = Ezirmin.FS_log(Tc.String)
module IrminLogMem = Ezirmin.FS_log(Tc.String)

let blockchainMasterBranch = Lwt_main.run (IrminLogBlock.init ~root: "/tmp/ezirminl/blockchain" ~bare:true () >>= IrminLogBlock.master)
let memPoolMasterBranch = Lwt_main.run (IrminLogMem.init ~root: "/tmp/ezirminl/mempool" ~bare: true () >>= IrminLogMem.master)

let run = Lwt_main.run
let path = []

(*TODO: remove wip branch after merge*)
(*string -> unit Lwt.t*)
let addValueToBlockchain value = let wipBranch = run @@ IrminLogBlock.clone_force blockchainMasterBranch "wip" in
  IrminLogBlock.append ~message:"Entry added to the blockchain" wipBranch ~path:path value >>= function _ -> 
  IrminLogBlock.merge wipBranch ~into:blockchainMasterBranch

(*TODO: remove wip branch after merge*)
(*string -> unit Lwt.t*)
let addValueToMemPool value = let wipBranch = run @@ IrminLogMem.clone_force memPoolMasterBranch "wip" in
  IrminLogMem.append ~message:"Entry added to the blockchain" wipBranch ~path:path value >>= function _ -> 
  IrminLogMem.merge wipBranch ~into:memPoolMasterBranch

(*string list -> unit Lwt.t*)
let addListToBlockchain list = Lwt.return @@ Lwt_list.iter_s addValueToBlockchain list

(*unit -> string option Lwt.t*)
let getLatestBlockchainMessage () = IrminLogBlock.get_cursor blockchainMasterBranch ~path:path >>= function
    | Some(cursor) -> IrminLogBlock.read cursor ~num_items:1 >>= (function
      | (x::_, _) -> Lwt.return @@ Some(x)
      | _ -> Lwt.return None)
    | None -> Lwt.return None

(*?n:int -> string -> cursor -> int option Lwt.t*)
let rec countWithCursor ?(n=1) (comparisonMessage:string) cursor = 
  (*read one more item and check if it's same as comparisonMessage*)
  (*string list * cursor option*)
  IrminLogMem.read cursor ~num_items:1 >>= function
      | (comparisonMessage::_, _) -> Lwt.return (Some(n))
      | (_, None) -> Lwt.return None
      | (_, Some(curs)) -> countWithCursor ~n:(n+1) comparisonMessage curs (*try the next one*)

(*TODO: s there a way to use >>= (or similar) below, rather than let statements?*)
(*Count how many new items there are in the memPool*)
(*unit -> int option Lwt.t*)
let countNewUpdates () = 
  let latestMessage = run @@ getLatestBlockchainMessage() in
  let cursor = run @@ IrminLogMem.get_cursor memPoolMasterBranch ~path:path in 
  match (latestMessage, cursor) with 
    |(Some(committedMessage), Some(initCursor)) -> countWithCursor committedMessage initCursor
    | _ -> Lwt.return None


(*unit -> string list option*)
let getNewUpdates () = 
  let cursor = run @@ IrminLogMem.get_cursor memPoolMasterBranch ~path:path in
  let numberOfUpdates = run @@ countNewUpdates () in
  match (cursor,numberOfUpdates) with
    | (Some(curs), Some(updates)) -> (IrminLogMem.read curs ~num_items:updates >>= function
      | (list, _) -> Lwt.return @@ Some(list))
    | _ -> Lwt.return None

(*unit -> 'a Lwt.t*)
let rec runLeader () = getNewUpdates() >>= function 
  | None -> 
    let _ = run @@ Lwt_unix.sleep 1.0
    in runLeader ()
  | Some(updates) -> let _ = run @@ addListToBlockchain updates
    in let _ = run @@ Lwt_unix.sleep 1.0
    in runLeader ()

(* unit -> 'a Lwt.t*)
let startLeader () = addValueToBlockchain "New Leader" >>= function _ ->
  addValueToMemPool "NewLeader" >>= function _ ->
  Lwt.return @@ runLeader();;     

Lwt_main.run @@ startLeader () ;;

(*
Setup - get the ip of the leader and then ask for user to enter transactions
Transactions can also be registering of items (maybe from a set registration id)

Then need some mechanism for changing leader... is this possible without http requests?
*)