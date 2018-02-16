open Lwt.Infix

let run = Lwt_main.run
let write value = Lwt_io.write Lwt_io.stdout value;;
let read () = Lwt_io.read_line Lwt_io.stdin ;;

let get_id () = write "\n\027[93mWhat is your current ID: \027[39m" >>= fun _ ->
  read()
let get_is_local () = write "\027[93mIs your destination log local or remote (l/r): \027[39m" >>= fun _ ->
  read () >>= function
    | "l" -> Lwt.return true
    | _ -> Lwt.return false
let try_get_remote_repo is_local = match is_local with
    | false -> write "Destination Username: " >>= fun _ ->
      read() >>= fun user ->
      write "Destination Hostname: " >>= fun _ ->
      read() >>= fun host ->
      Lwt.return @@ "git+ssh://"^user^"@"^host^"/tmp/ezirmin/lead/mempool" 
    | _ -> Lwt.return ""


let current_id = run @@ get_id()
let is_local = run @@ get_is_local()
let remote_uri = run @@ try_get_remote_repo is_local

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
  Part.add_transaction_to_mempool value >>= fun _ ->
  write "\n\027[32mITEM ADDED SUCCESSFULLY\n" >>= 
  start_participant;;

run @@ start_participant ();;