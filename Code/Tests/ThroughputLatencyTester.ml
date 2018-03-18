(*
Add transactions to the blockchain at an increasing rate
bin/lead -r remoteuser@remotehost -i 1 -s 2018031233300
*)

open Lwt.Infix
open Ptime
let remote_uri = ref None
let machine_id = ref 0
let itr = ref 0
let start_time = ref (Ptime_clock.now())
let parse_is_local str = 
  remote_uri := Some(str);
  Printf.printf "\n\027[93mUsing leader address:\027[39m %s\n%!" str
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



let remote_tuple = ("-r", Arg.String parse_is_local, "Specify the remote repository in the form user@host")
let id_tuple = ("-i", Arg.Int parse_id, "Specify the machine id as a number")
let start_tuple = ("-s", Arg.String parse_time, "Specify when this should begin")

let _ = Arg.parse [remote_tuple; id_tuple; start_tuple] (fun _ -> ()) ""

type transaction = string * string * float
module Config : Blockchain.I_ParticipantConfig with type t = transaction = struct 
  type t = transaction
  module LogCoder = LogStringCoder.TestLogStringCoder
  let leader_uri = !remote_uri
  let validator = None
end

module Participant = Blockchain.MakeParticipant(Config)


let rec test_blockchain_increasing inc_time rates = 
  match rates with 
   | [] -> Lwt.return ()
   | ((rate, duration)::new_rates) ->(
      Lwt_main.run @@ Lwt_unix.sleep rate; 
      let now = Ptime_clock.now() in 
      let id = string_of_int !machine_id in
      let machine_id = id in 
      let txn =  Printf.sprintf "machine: %s; txn: %s;" machine_id (string_of_int !itr) in
      match now > inc_time with
      | true -> itr := !itr + 1;
        (match (of_float_s((to_float_s inc_time) +. duration)) with 
          | Some(new_inc_time) ->( match new_rates with 
            | [] -> Lwt.return ()
            | ((new_rate, new_duration)::_) -> Printf.printf "Using txn interval: %f\n%!" new_rate ; 
              test_blockchain_increasing new_inc_time new_rates)
          | _ -> test_blockchain_increasing inc_time new_rates)
      | false -> Participant.add_transaction_to_mempool (machine_id, txn, rate) >>= fun _ ->
        itr := !itr + 1;
        test_blockchain_increasing inc_time rates)

let rates = List.map (fun x -> 1.0 /. x) [1.0;3.0;5.0;7.0;9.0;11.0;13.0;15.0;17.0;19.0;21.0;23.0;25.0;27.0;29.0;31.0]
(*first arg is the rate, second is the test duration*)
let rates = List.map (fun x -> (x, 15.0 *. x)) rates


let rec test_blockchain_start() = 
  let now = Ptime_clock.now() in 
  match now > !start_time with  
    | true -> Printf.printf "Starting Tests\n%!";
      Printf.printf "Using rate, 1 txn/s\n%!";
      (match (of_float_s(to_float_s(!start_time) +. (snd(List.hd rates)))) with 
       | Some(inc_time) -> test_blockchain_increasing inc_time rates
       | _ -> test_blockchain_increasing !start_time rates)
    | false -> Lwt_unix.sleep 0.1 >>= fun _ -> test_blockchain_start();;

Lwt_main.run @@ test_blockchain_start();;
(* Lwt_main.run @@ Lwt_unix.sleep 5.0;;
Lwt_main.run @@ Participant.get_all_transactions_from_blockchain();; *)