open Lwt.Infix
type transaction = string * string * string
module Config : Blockchain.I_ParticipantConfig with type t = transaction = struct 
  type t = transaction
  module LogCoder = LogStringCoder.BookLogStringCoder
  let is_local = false
  let leader_uri = ""
  let validator = None
end

module Participant = Blockchain.MakeParticipant(Config)

let rec test_blockchain n = 
  let nstr = string_of_int n in
  let sender = "sender: "^nstr in 
  let receiver = "receiver: "^nstr in
  let book = "book: "^nstr in
  match n with
  | 0 -> Lwt.return @@ Participant.add_transaction_to_mempool (sender, receiver, book)
  | _ -> Participant.add_transaction_to_mempool (sender, receiver, book) >>= fun _ ->
    test_blockchain (n-1);;

Lwt_main.run @@ test_blockchain 10;;