(*Get the size of the blockchain or of given mempools*)
open Lwt.Infix
module IrminLogBlock = Ezirmin.FS_log(Tc.String)
module IrminLogMem = Ezirmin.FS_log(Tc.String)
module IrminLogLeadMem = Ezirmin.FS_log(Tc.String)
module Coder = LogStringCoder.TestLogStringCoder

let blockchain = ref false
let participant = ref false
let mempools = ref []
let f = ref None
let l = ref None
let is_leader = ref false

let print_blockchain = ("-b", Arg.Unit (fun () -> blockchain := true), "Print the blockchain")
let print_participant = ("-p", Arg.Unit (fun () -> participant := true), "Print the local participant mempool")
let is_leader_tup = ("-r", Arg.Unit (fun b -> is_leader := true), "Specify that you are on the leader machine")
let print_first = ("-f", Arg.Int (fun num -> f := Some(num)), "Print only first n txns")
let print_last = ("-l", Arg.Int (fun num -> l := Some(num)), "Print only last n txns")
let print_mempools = ("-m", Arg.Rest (fun mempool -> mempools := ((Str.global_replace (Str.regexp "@") "" mempool)::(!mempools))), 
  "Specify the remote mempools to print - in the format user@host")
let _ = Arg.parse [print_blockchain;print_participant;print_first;print_last;print_mempools;is_leader_tup] (fun _ -> ()) ""

let run = Lwt_main.run
let path = []

let print_txn str = let txn = Coder.decode_string str in 
  match txn with 
    | Some((machine, txn, rate)) -> Printf.printf "Machine id: %s; Txn id: %s; Rate: %f\n%!" machine txn rate
    | None -> Printf.printf "Could Not Decode!\n%!"

let rec print_list lst = match lst with 
  | (x::[]) -> print_txn x
  | (x::xs) -> print_txn x; print_list xs
  | [] -> ()

let rec get_first num lst = match num, lst with 
  | 0, _ -> []
  | _, x::xs -> x::(get_first (num-1) xs)
  | _, [] -> []

let rec print_mempool_list repo = function 
  | [] -> ()
  | x::xs -> let branch = Lwt_main.run @@ IrminLogLeadMem.get_branch repo x in
    let mempool_list = run @@ IrminLogLeadMem.read_all branch [] in
    if mempool_list == [] then begin
      Printf.printf "No items found\n%!";
      print_mempool_list repo xs
    end
    else
      match !f, !l with 
        | None, None -> print_list mempool_list;
          print_mempool_list repo xs
        | Some(first), _ -> print_list (get_first first mempool_list);
          print_mempool_list repo xs
        | None, Some(last) -> print_list (get_first last (List.rev mempool_list));
          print_mempool_list repo xs

let rec print_local_mempool () = 
  let repo = run @@ IrminLogMem.init ~root: "/tmp/ezirminl/part/mempool" ~bare:true () in 
  let master_branch = Lwt_main.run @@ IrminLogMem.master repo in
  let mempool_list = run @@ IrminLogLeadMem.read_all master_branch [] in
  if mempool_list == [] then 
      Printf.printf "No items found\n%!"
  else
  match !f, !l with 
    | None, None -> print_list mempool_list
    | Some(first), _ -> print_list (get_first first mempool_list)
    | None, Some(last) -> print_list (get_first last (List.rev mempool_list))

let rec print_local_blockchain () = 
  let repo = run @@ IrminLogBlock.init ~root:"/tmp/ezirminl/lead/blockchain" ~bare:true () in
  let master_branch = Lwt_main.run @@ IrminLogMem.master repo in
  let blockchain_list = run @@ IrminLogLeadMem.read_all master_branch [] in
  if blockchain_list == [] then 
      Printf.printf "No items found\n%!"
  else
  match !f, !l with 
    | None, None -> print_list blockchain_list
    | Some(first), _ -> print_list (get_first first blockchain_list)
    | None, Some(last) -> print_list (get_first last (List.rev blockchain_list))

let print () = 
  if !blockchain then begin
    print_local_blockchain ()
  end;
  if !participant then begin
    print_local_mempool ()
  end;
  if !mempools != [] then begin
    if !is_leader then 
      let mempool_repo = run @@ IrminLogLeadMem.init ~root:"/tmp/ezirminl/lead/mempool" ~bare:true () in
      print_mempool_list mempool_repo !mempools
    else 
      let mempool_repo = run @@ IrminLogLeadMem.init ~root:"/tmp/ezirminl/part/mempool" ~bare:true () in
      print_mempool_list mempool_repo !mempools
  end;;

print();;
