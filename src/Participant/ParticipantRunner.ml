open Lwt.Infix
module IrminLogMem = Ezirmin.FS_log(Tc.String)

let run = Lwt_main.run;;
let write value = Lwt_io.write Lwt_io.stdout value;;
let read () = Lwt_io.read_line Lwt_io.stdin ;;

let getRepoString () = write "\n\027[93mIs your destination log local or remote (l/r): \027[39m" >>= fun _ ->
  read () >>= function 
    | "r" -> write "Destination Username: " >>= fun _ ->
      read() >>= fun user ->
      write "Destination Hostname: " >>= fun _ ->
      read() >>= fun host ->
      Lwt.return @@ Printf.sprintf "git+ssh://%s@%s/tmp/ezirmin/mempool" user host
    | _ -> Lwt.return "/tmp/ezirminl/mempool"

(*For remote repos...*)
let root = run @@ getRepoString()
let memPoolMasterBranch = Lwt_main.run (IrminLogMem.init ~root:root ~bare: true () >>= IrminLogMem.master)
let path = []

let addTransactionToMemPool senderID receiverID bookID =
  let message = LogStringCoder.encodeString senderID receiverID bookID in 
  IrminLogMem.clone_force memPoolMasterBranch "wip" >>= fun wipBranch ->
  IrminLogMem.append ~message:"Entry added to the blockchain" wipBranch ~path:path message >>= fun _ -> 
  IrminLogMem.merge wipBranch ~into:memPoolMasterBranch;;

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