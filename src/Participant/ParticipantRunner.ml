open Lwt.Infix
module IrminLogMem = Ezirmin.FS_log(Tc.String)

let run = Lwt_main.run

(*For remote repos...*)
let root = run (Lwt_io.write Lwt_io.stdout "\n\027[93mPlease input the destination repo string: \027[39m" >>= fun _ ->
  Lwt_io.read_line Lwt_io.stdin)
let memPoolMasterBranch = Lwt_main.run (IrminLogMem.init ~root:root ~bare: true () >>= IrminLogMem.master)
let path = []

let addTransactionToMemPool senderID receiverID bookID =
  let message = LogStringCoder.encodeString senderID receiverID bookID in 
  IrminLogMem.clone_force memPoolMasterBranch "wip" >>= fun wipBranch ->
  IrminLogMem.append ~message:"Entry added to the blockchain" wipBranch ~path:path message >>= fun _ -> 
  IrminLogMem.merge wipBranch ~into:memPoolMasterBranch;;

let getLogEntryTuple () = 
  Lwt_io.write Lwt_io.stdout "\n\027[39mYour ID (sender): \027[39m" >>= fun _ ->
  Lwt_io.read_line Lwt_io.stdin >>= fun senderID ->
  Lwt_io.write Lwt_io.stdout "\027[39mTheir ID (receiver): \027[39m" >>= fun _ ->
  Lwt_io.read_line Lwt_io.stdin >>= fun receiverID ->
  Lwt_io.write Lwt_io.stdout "\027[39mItem ID (book): \027[39m" >>= fun _ ->
  Lwt_io.read_line Lwt_io.stdin >>= fun bookID ->
  Lwt.return (senderID, receiverID, bookID)

let rec startParticipant () = 
  Lwt_io.write_line Lwt_io.stdout "\027[35m-----------------------------------\n-----Enter Transaction Details-----\027[39m" >>= fun _ ->
  getLogEntryTuple() >>= fun (sender, receiver, book) ->
  addTransactionToMemPool sender receiver book >>= fun _ ->
  Lwt_io.write_line Lwt_io.stdout "\n\027[32mITEM ADDED SUCCESSFULLY\n" >>= 
  startParticipant;;

run @@ startParticipant();;