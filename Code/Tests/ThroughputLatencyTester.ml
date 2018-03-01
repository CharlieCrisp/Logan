(*bin/lead -r remoteuser@remotehost -i 10*)

open Lwt.Infix

let remote_uri = ref None
let n = ref 10
let machine_id = ref 0
let parse_is_local str = 
  remote_uri := Some(str);
  Printf.printf "\n\027[93mUsing leader address:\027[39m %s\n%!" str
let parse_iterations itr = 
  n := itr
let parse_id num = 
  machine_id := num

let iterations_tuple = ("-n", Arg.Int parse_iterations, "Specify the number of iterations")
let remote_tuple = ("-r", Arg.String parse_is_local, "Specify the remote repository in the form user@host")
let id_tuple = ("-i", Arg.Int parse_id, "Specify the machine id as a number")
let _ = Arg.parse [remote_tuple; iterations_tuple; id_tuple] (fun _ -> ()) ""

type transaction = string * string
module Config : Blockchain.I_ParticipantConfig with type t = transaction = struct 
  type t = transaction
  module LogCoder = LogStringCoder.TestLogStringCoder
  let leader_uri = !remote_uri
  let validator = None
end

module Participant = Blockchain.MakeParticipant(Config)

let rec test_blockchain itr = 
  let id = string_of_int !machine_id in
  let nstr = string_of_int itr in
  let machine_id = id in 
  let txn = nstr in
  match itr with
  | 0 -> Lwt.return @@ Participant.add_transaction_to_mempool (machine_id, txn)
  | _ -> Participant.add_transaction_to_mempool (machine_id, txn) >>= fun _ ->
    test_blockchain (itr-1);;

Lwt_main.run @@ test_blockchain !n;;