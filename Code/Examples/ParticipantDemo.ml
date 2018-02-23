(*
This program demonstrates the capabilities of the Participant Module.
Run the executable with `-r remote` to connect to a remote leader
E.g. PartcipantDemo.exe -r leader@0.0.0.0 
*)

open Lwt.Infix

let run = Lwt_main.run
let is_local = ref true
let remote_uri = ref ""

let write value = Lwt_io.write Lwt_io.stdout value;;
let read () = Lwt_io.read_line Lwt_io.stdin ;;

let get_id () = write "\n\027[93mWhat is your current ID: \027[39m" >>= fun _ ->
  read()

let parse_is_local str = 
  is_local := false;
  remote_uri := str;
  Printf.printf "\n\027[93mUsing leader address:\027[39m %s\n%!" str

let remote_tuple = ("-r", Arg.String parse_is_local, "Specify the remote repository in the form user@host");;
let _ = Arg.parse [remote_tuple] (fun _ -> ()) ""

let current_id = run @@ get_id()

module Config: Blockchain.I_ParticipantConfig with type t = string * string * string = struct
  type t = string * string * string
  module LogCoder = LogStringCoder.BookLogStringCoder
  let is_local = !is_local
  let leader_uri = !remote_uri
  let validator = None
end

module Part = Blockchain.MakeParticipant(Config)

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