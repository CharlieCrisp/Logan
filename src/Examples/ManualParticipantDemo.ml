open Lwt.Infix

let run = Lwt_main.run
let write value = Lwt_io.write Lwt_io.stdout value;;
let read () = Lwt_io.read_line Lwt_io.stdin ;;

let current_id = "charlie"
let is_local = false
let remote_uri = "git+ssh://charlie@13.90.155.211/tmp/ezirminl/part/mempool"

module Config: Participant.I_ParticipantConfig = struct
  let is_local = is_local
  let leader_uri = remote_uri
end

module Part = Participant.Make(Config)(LogStringCoder.BookLogStringCoder)

let get_log_entry_tuple () = 
  write "\n\027[39mTheir ID (receiver): \027[39m" >>= fun _ ->
  read() >>= fun receiver_id ->
  write "\027[39mItem ID (book): \027[39m" >>= fun _ ->
  read() >>= fun book_id ->
  Lwt.return (current_id, receiver_id, book_id)

let rec start_participant () = 
  write "\027[35m-----------------------------------\n-----Enter Transaction Details-----\027[39m" >>= fun _ ->
  get_log_entry_tuple() >>= fun value ->
  Part.add_transaction_to_mempool value >>= function
    | `Ok -> write "\n\027[32mITEM ADDED SUCCESSFULLY\n" >>= 
      start_participant
    | _ -> write "\n\027[31mFAILED TO ADD ITEM\n" >>= 
      start_participant;;

run @@ start_participant ();;