(*bin/lead -r remoteuser@remotehost -i 1 -s 2018031233300*)

open Lwt.Infix
open Ptime
let remote_uri = ref None
let n = ref 10
let machine_id = ref 0
let itr = ref 0
let start_time = ref (Ptime_clock.now())
let parse_is_local str = 
  remote_uri := Some(str);
  Printf.printf "\n\027[93mUsing leader address:\027[39m %s\n%!" str
let parse_iterations itr = 
  n := itr
let parse_id num = 
  machine_id := num
let parse_time input = 
  let year = int_of_string (String.sub input 0 4) in
  let month = int_of_string (String.sub input 4 2) in
  let day = int_of_string (String.sub input 6 2) in
  let hour = int_of_string (String.sub input 8 2) in
  let min = int_of_string (String.sub input 10 2) in 
  let sec = 0 in
  let time: Ptime.time = ((hour, min, sec),0) in 
  let date: Ptime.date = (year, month, day) in
  match Ptime.of_date_time (date, time) with
  | Some(new_date) -> start_time := new_date;
  | _ -> ()



let iterations_tuple = ("-n", Arg.Int parse_iterations, "Specify the number of iterations")
let remote_tuple = ("-r", Arg.String parse_is_local, "Specify the remote repository in the form user@host")
let id_tuple = ("-i", Arg.Int parse_id, "Specify the machine id as a number")
let start_tuple = ("-s", Arg.String parse_time, "Specify when this should begin")

let _ = Arg.parse [remote_tuple; iterations_tuple; id_tuple; start_tuple] (fun _ -> ()) ""

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
    test_blockchain (itr-1)

let rec test_blockchain_increasing inc_time sleep_time = 
  Lwt_main.run @@ Lwt_unix.sleep sleep_time; 
  let now = Ptime_clock.now() in 
  let id = string_of_int !machine_id in
  let nstr = string_of_int !itr in
  let machine_id = id in 
  let txn = nstr in
  if sleep_time < 0.01 then Lwt.return () else
  match now > inc_time with
  | true -> itr := !itr + 1;
    (match (of_float_s((to_float_s inc_time) +. 10.0)) with 
      | Some(new_inc_time) -> Printf.printf "Using rate, %f txn/s\n%!" (1.0 /. (sleep_time /. 2.0)); 
        test_blockchain_increasing new_inc_time (sleep_time /. 2.0)
      | _ -> test_blockchain_increasing inc_time (sleep_time /. 2.0))
  | false -> Participant.add_transaction_to_mempool (machine_id, txn) >>= fun _ ->
    itr := !itr + 1;
    test_blockchain_increasing inc_time sleep_time;;

let rec test_blockchain_start() = 
  let now = Ptime_clock.now() in 
  match now > !start_time with  
    | true -> Printf.printf "Starting Tests\n%!";
      Printf.printf "Using rate, 1 txn/s\n%!";
      test_blockchain_increasing !start_time 1.0
    | false -> Lwt_unix.sleep 0.1 >>= fun _ -> test_blockchain_start();;

Lwt_main.run @@ test_blockchain_start();;