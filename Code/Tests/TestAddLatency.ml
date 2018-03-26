(*
This generates an executable which will add a specified number of transactions to the blockchain (mempool) with no delay in between
bin/AddNumberToBlockchain -r remoteuser@remotehost -i 1 -s 2018031233300 -n 1000
*)

open Lwt.Infix
open Ptime

let run = Lwt_main.run
let recorded = ref 0
let running_total = ref 0.0

type transaction = string * string * float
module Config : Blockchain.I_ParticipantConfig with type t = transaction = struct 
  type t = transaction
  module LogCoder = LogStringCoder.TestLogStringCoder
  let leader_uri = None
  let self_uri = None
  let validator = None
end

module Participant = Blockchain.MakeParticipant(Config)
let log_file = open_out_gen [Open_creat; Open_text; Open_append] 0o640 "output.log"

let log f = Printf.fprintf log_file "%f\n%!" f

let record n = match !recorded with 
  | 20 -> log ((!running_total /. 20.0) *.1000.0); recorded := 0; running_total := n
  | _ -> recorded := !recorded + 1; running_total := !running_total +. n

let rec add_transactions = function
  | 0 -> Lwt.return ()
  | n -> let time1 = Ptime_clock.now() in 
    Participant.add_transaction_to_mempool ("0", "0", 1.0) >>= fun _ ->
    let time2 = Ptime_clock.now() in 
    record ((Ptime.to_float_s time2) -. (Ptime.to_float_s time1));
    add_transactions (n-1);;

Printf.printf "Printing average txn time in ms, averged over 20 txns:\n%!";;
run @@ add_transactions 15000;;
close_out log_file;;