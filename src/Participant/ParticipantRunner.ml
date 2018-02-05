open Lwt.Infix
module IrminLogMem = Ezirmin.FS_log(Tc.String)

let run = Lwt_main.run;;
let write value = Lwt_io.write Lwt_io.stdout value;;
let read () = Lwt_io.read_line Lwt_io.stdin ;;
let push = IrminLogMem.Sync.push;;
let pull = IrminLogMem.Sync.pull;;

let root = "/tmp/ezirminl/mempool"
let memPoolMasterBranch = Lwt_main.run (IrminLogMem.init ~root:root ~bare: true () >>= IrminLogMem.master)
let path = []

let getIsRemote () = write "\n\027[93mIs your destination log local or remote (l/r): \027[39m" >>= fun _ ->
  read () >>= function
    | "r" -> Lwt.return true
    | _ -> Lwt.return false

let tryGetRemoteRepo isRemote = match isRemote with
    | true -> write "Destination Username: " >>= fun _ ->
      read() >>= fun user ->
      write "Destination Hostname: " >>= fun _ ->
      read() >>= fun host ->
      Lwt.return @@ IrminLogMem.Sync.remote_uri ("git+ssh://"^user^"@"^host^"/tmp/ezirmin/mempool") >>= fun remote ->
      Lwt.return @@ Some(remote)
    | _ -> Lwt.return None

(*For remote repos...*)
let isRemote = run @@ getIsRemote()
let optRemote = run @@ tryGetRemoteRepo isRemote
exception Remote_Not_Found
exception Could_Not_Pull_From_Remote
exception Could_Not_Push_To_Remote

let addLocalMessageToMemPool message =
  IrminLogMem.clone_force memPoolMasterBranch "wip" >>= fun wipBranch ->
  IrminLogMem.append ~message:"Entry added to the blockchain" wipBranch ~path:path message >>= fun _ -> 
  IrminLogMem.merge wipBranch ~into:memPoolMasterBranch ;;

let addTransactionToMemPool senderID receiverID bookID =
  let message = LogStringCoder.encodeString senderID receiverID bookID in 
  match isRemote with
    | false -> addLocalMessageToMemPool message
    | true -> (match optRemote with 
      | Some(remote) -> pull remote memPoolMasterBranch `Merge >>= (function
        | `Ok -> addLocalMessageToMemPool message >>= fun _ ->
          push remote memPoolMasterBranch >>= (function
            | `Ok -> Lwt.return ()
            | _ -> raise Could_Not_Push_To_Remote)
        | _ -> raise Could_Not_Pull_From_Remote)
      | None -> raise Remote_Not_Found)

let getLogEntryTuple () = 
  write "\n\027[39mYour ID (sender): \027[39m" >>= fun _ ->
  read() >>= fun senderID ->
  write "\027[39mTheir ID (receiver): \027[39m" >>= fun _ ->
  read() >>= fun receiverID ->
  write "\027[39mItem ID (book): \027[39m" >>= fun _ ->
  read() >>= fun bookID ->
  Lwt.return (senderID, receiverID, bookID)

let rec startParticipant () = 
  write "\027[35m-----------------------------------\n-----Enter Transaction Details-----\027[39m" >>= fun _ ->
  getLogEntryTuple() >>= fun (sender, receiver, book) ->
  addTransactionToMemPool sender receiver book >>= fun _ ->
  write "\n\027[32mITEM ADDED SUCCESSFULLY\n" >>= 
  startParticipant;;

run @@ startParticipant();;