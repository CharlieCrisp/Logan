open Lwt.Infix
module IrminLog = Ezirmin.FS_log(Tc.String)

let blockchainMasterBranch = Lwt_main.run (IrminLog.init ~root: "/tmp/ezirminl/blockchain" ~bare:true () >>= IrminLog.master)
let memPoolMasterBranch = Lwt_main.run (IrminLog.init ~root: "/tmp/ezirminl/mempool" ~bare: true () >>= IrminLog.master)

let run = Lwt_main.run
let path = []

(*string -> unit*)
let addValueToBlockchain value = run @@ IrminLog.append ~message:"Entry added to blockchain" blockchainMasterBranch ~path:path value
let rec addListToBlockchain list = match list with
  | (x::xs) -> let _ = addValueToBlockchain x in addListToBlockchain(xs)
  | [] -> ()
(*unit -> string option*)
let getLatestBlockchainMessage () = let optCursor = run @@ IrminLog.get_cursor blockchainMasterBranch ~path:path
  in 
    match optCursor with
    | Some(cursor) -> let string = match run @@ IrminLog.read cursor ~num_items:1 with
                        | (x::_, _) -> Some(x)
                        | _ -> None
                    in
                      string
    | None -> None

(*Auxiliary function to above*)
(*?n:int -> string -> cursor -> int option*)
let rec countWithCursor ?(n=1) (comparisonMessage:string) cursor = 
  (*read one more item and check if it's same as comparisonMessage*)
  (*string list * cursor option*)
  let readResult = run @@ IrminLog.read cursor ~num_items:1
  in 
    match readResult with
      | (comparisonMessage::_, _) -> Some(n)
      | (_, None) -> None
      | (_, Some(curs)) -> countWithCursor ~n:(n+1) comparisonMessage curs (*try the next one*)

(*Count how many new items there are in the memPool*)
(*unit -> int option*)
let countNewUpdates () = 
  let 
    latestCommittedMessage = getLatestBlockchainMessage() and (*string option*)
    initialCursor = run @@ IrminLog.get_cursor memPoolMasterBranch ~path:path (*cursor option*)
  in
    match (latestCommittedMessage, initialCursor) with
      |(Some(committedMessage), Some(initCursor)) -> countWithCursor committedMessage initCursor
      | _ -> None

(*unit -> string list option*)
let getNewUpdates () = let cursor = run (IrminLog.get_cursor memPoolMasterBranch ~path:path) (*cursor option*)
   and numberOfUpdates = countNewUpdates() (*int option*)
  in (*cursor -> int -> string list*)
    let readList curs updates= match run (IrminLog.read curs ~num_items:updates) with
      (*string list * cursor option*)
      | (list, _) -> Some(list)
    in (*cursor option * int option*)
      match (cursor, numberOfUpdates)  with 
        | (Some(curs), Some(updates)) -> readList curs updates
        | _ -> None

(*unit -> 'a*)
let rec runLeader () = 
  let 
    optUpdates = getNewUpdates()
  in let _ = match optUpdates with 
      |None -> ()
      |Some(updates) ->addListToBlockchain updates
  in let
    _ = run @@ Lwt_unix.sleep 1.0
  in
    runLeader ()

(* unit -> 'a*)
let rec startLeader () = let _ = addValueToBlockchain "New Leader" in runLeader()  ;;     

startLeader ();;

(*
Setup - get the ip of the leader and then ask for user to enter transactions
Transactions can also be registering of items (maybe from a set registration id)


transactions are stored as strings
Transaction has an id of sender and receiver as well as an item
let getTransFromString
let getStringFromTrans

let getUpdates -> list of Transactions that aren't in the blockchain
validate transactions and commit to the blockchain

Then need some mechanism for changing leader... is this possible without http requests?
*)