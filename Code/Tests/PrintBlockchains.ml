(*Get the size of the blockchain or of given mempools*)
open Lwt.Infix
module IrminLogBlock = Ezirmin.FS_log(Tc.String)
module IrminLogMem = Ezirmin.FS_log(Tc.String)
module IrminLogLeadMem = Ezirmin.FS_log(Tc.String)
module Coder = LogStringCoder.TestLogStringCoder

let blockchain = ref false
let leader_participant = ref false
let mempools = ref []
let f = ref None
let l = ref None
let user = ref None

let print_blockchain = ("-b", Arg.Unit (fun () -> blockchain := true), "Print the blockchain")
let print_participant = ("-p", Arg.Unit (fun () -> leader_participant := true), "Print the Participant mempool on Leader machine")
let is_leader_tup = ("-u", Arg.String (fun u -> user := Some(Str.global_replace (Str.regexp "@") "" u)), "Print the Participant mempool (not Leader machine)")
let print_first = ("-h", Arg.Int (fun num -> f := Some(num)), "Print only first n txns")
let print_last = ("-t", Arg.Int (fun num -> l := Some(num)), "Print only last n txns")
let print_mempools = ("-m", Arg.Rest (fun mempool -> mempools := ((Str.global_replace (Str.regexp "@") "" mempool)::(!mempools))), 
  "Print all Participant mempools from Leader machine. Specify Participants in the format user@host")
let _ = Arg.parse [print_blockchain;print_participant;print_first;print_last;print_mempools;is_leader_tup] (fun _ -> ()) ""

let run = Lwt_main.run
let path = []

let print_txn str = 
  if str = "Genesis Commit" then 
    Printf.printf "Genesis Commit\n%!" 
  else
  let txn = Coder.decode_string str in 
  let log_item = Coder.decode_log_item str in
  let time_orig = Coder.get_time log_item in
  let time_int = (int_of_float time_orig) mod 100000 in
  let time = (float_of_int time_int) +. time_orig -. (float_of_int (int_of_float time_orig)) in 
  match txn with 
    | Some((machine, txn, rate)) -> Printf.printf "Time: \027[95m%.3f\027[39m; Machine id: %s; Txn id: %s; Rate: %f\n%!" time machine txn rate
    | None -> Printf.printf "Could Not Decode!\n%!"

let rec print_list lst = match lst with 
  | (x::[]) -> print_txn x
  | (x::xs) -> print_txn x; print_list xs
  | [] -> ()

let rec get_first num lst = match num, lst with 
  | 0, _ -> []
  | _, x::xs -> x::(get_first (num-1) xs)
  | _, [] -> []

let rec print_lead_mempool_list repo = function 
  | [] -> ()
  | x::xs -> Printf.printf "------------ Printing /lead/mempool %s ------------\n%!" x;
    let branch = run @@ IrminLogLeadMem.get_branch repo x in
    let mempool_list = run @@ IrminLogLeadMem.read_all branch [] in
    if mempool_list == [] then begin
      Printf.printf "No items found\n%!";
      print_lead_mempool_list repo xs
    end
    else
      match !f, !l with 
        | None, None -> print_list mempool_list;
          Printf.printf "------------ Finished /lead/mempool %s ------------\n%!" x;
          print_lead_mempool_list repo xs
        | Some(first), _ -> print_list (get_first first mempool_list);
          Printf.printf "------------ Finished /lead/mempool %s ------------\n%!" x;
          print_lead_mempool_list repo xs
        | None, Some(last) -> print_list (get_first last (List.rev mempool_list));
          Printf.printf "------------ Finished /lead/mempool %s ------------\n%!" x;
          print_lead_mempool_list repo xs

let rec print_local_mempool () = 
  let repo = run @@ IrminLogMem.init ~root: "/tmp/ezirminl/part/mempool" ~bare:true () in 
  let master_branch = run @@ IrminLogMem.master repo in
  let mempool_list = run @@ IrminLogMem.read_all master_branch [] in
  if mempool_list == [] then 
      Printf.printf "No items found\n%!"
  else
  match !f, !l with 
    | None, None -> print_list mempool_list
    | Some(first), _ -> print_list (get_first first mempool_list)
    | None, Some(last) -> print_list (get_first last (List.rev mempool_list))

let rec print_local_blockchain () = 
  let repo = run @@ IrminLogBlock.init ~root:"/tmp/ezirminl/lead/blockchain" ~bare:true () in
  let master_branch = run @@ IrminLogBlock.master repo in
  let blockchain_list = run @@ IrminLogBlock.read_all master_branch [] in
  if blockchain_list == [] then 
      Printf.printf "No items found\n%!"
  else
  match !f, !l with 
    | None, None -> print_list blockchain_list
    | Some(first), _ -> print_list (get_first first blockchain_list)
    | None, Some(last) -> print_list (get_first last (List.rev blockchain_list))

let rec print_non_leader_mempool user = 
  let repo = run @@ IrminLogMem.init ~root:"/tmp/ezirminl/part/mempool" ~bare:true () in
  let user_branch = run @@ IrminLogMem.get_branch repo user in
  let mempool_list = run @@ IrminLogMem.read_all user_branch [] in
  if mempool_list == [] then 
      Printf.printf "No items found\n%!"
  else
  match !f, !l with 
    | None, None -> print_list mempool_list
    | Some(first), _ -> print_list (get_first first mempool_list)
    | None, Some(last) -> print_list (get_first last (List.rev mempool_list))

let print () = 
  if !blockchain then begin
    Printf.printf "------------ Printing Blockchain ------------\n%!";
    print_local_blockchain ();
    Printf.printf "------------ Finished Blockchain ------------\n%!"
  end;
  if !leader_participant then begin
    Printf.printf "------------ Printing /part/mempool master ------------\n%!";
    print_local_mempool ();
    Printf.printf "------------ Finished /part/mempool master ------------\n%!"
  end;
  (match !user with 
    | Some(u) -> Printf.printf "------------ Printing /part/mempool %s ------------\n%!" u;
      print_non_leader_mempool u;
      Printf.printf "------------ Finished /part/mempool %s ------------\n%!" u;
    | None -> ());
  if !mempools != [] then begin
    let mempool_repo = run @@ IrminLogLeadMem.init ~root:"/tmp/ezirminl/lead/mempool" ~bare:true () in
    print_lead_mempool_list mempool_repo !mempools
  end;;

print();;
