open Lwt.Infix

let remote_uri = ref None
let n = ref 10
let parse_is_local str = 
  remote_uri := Some(str);
  Printf.printf "\n\027[93mUsing leader address:\027[39m %s\n%!" str
let parse_iterations itr = 
  n := itr

let remote_tuple = ("-r", Arg.String parse_is_local, "Specify the remote repository in the form user@host");;
let iterations_tuple = ("-n", Arg.Int parse_iterations, "Specify the number of iterations")
let _ = Arg.parse [remote_tuple] (fun _ -> ()) ""

type transaction = string * string * string
module Config : Blockchain.I_ParticipantConfig with type t = transaction = struct 
  type t = transaction
  module LogCoder = LogStringCoder.BookLogStringCoder
  let leader_uri = !remote_uri
  let validator = None
end

module Participant = Blockchain.MakeParticipant(Config)

let rec test_blockchain itr = 
  let nstr = string_of_int itr in
  let sender = "sender: "^nstr in 
  let receiver = "receiver: "^nstr in
  let book = "book: "^nstr in
  match itr with
  | 0 -> Lwt.return @@ Participant.add_transaction_to_mempool (sender, receiver, book)
  | _ -> Participant.add_transaction_to_mempool (sender, receiver, book) >>= fun _ ->
    test_blockchain (itr-1);;

Lwt_main.run @@ test_blockchain !n;;