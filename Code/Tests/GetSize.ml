(*Get the size of the blockchain or of given mempools*)
open Lwt.Infix
module IrminLogBlock = Ezirmin.FS_log(Tc.String)
module IrminLogMem = Ezirmin.FS_log(Tc.String)
module IrminLogLeadMem = Ezirmin.FS_log(Tc.String)
module Coder = LogStringCoder.TestLogStringCoder

let blockchain = ref false
let participant = ref false
let mempools = ref []
let help = ref false

let print_blockchain = ("-b", Arg.Unit (fun () -> blockchain := true), "Print the blockchain size")
let print_participant = ("-p", Arg.Unit (fun () -> participant := true), "Print the participant mempool size")
let print_help = ("-h", Arg.Unit (fun () -> help := true), "Print all available options")
let print_mempools = ("-m", Arg.Rest (fun mempool -> mempools := (mempool::(!mempools))), "Specify the mempools to print")
let _ = Arg.parse [print_blockchain;print_participant;print_help;print_mempools] (fun _ -> ()) ""

let run = Lwt_main.run
let path = []

let rec print_mempool_list repo = function 
  | [] -> ()
  | x::xs -> let branch = Lwt_main.run @@ IrminLogLeadMem.get_branch repo x in
    let mempool_list = run @@ IrminLogLeadMem.read_all branch [] in
    Printf.printf "Blockchain size: %i\n" (List.length mempool_list);
    print_mempool_list repo xs

let print () = 
  if !blockchain then begin
    let blockchain_repo = run @@ IrminLogBlock.init ~root: "/tmp/ezirminl/lead/blockchain" ~bare:true () in 
    let blockchain_master_branch = Lwt_main.run @@ IrminLogBlock.master blockchain_repo in
    let blockchain_list = run @@ IrminLogBlock.read_all blockchain_master_branch [] in
    Printf.printf "Blockchain size: %i\n" (List.length blockchain_list)
  end;
  if !participant then begin
    let mempool_repo = run @@ IrminLogBlock.init ~root: "/tmp/ezirminl/part/mempool" ~bare:true () in 
    let mempool_master_branch = Lwt_main.run @@ IrminLogBlock.master mempool_repo in
    let mempool_list = run @@ IrminLogBlock.read_all mempool_master_branch [] in
    Printf.printf "Blockchain size: %i\n" (List.length mempool_list)
  end;
  if !mempools != [] then begin
    let mempool_repo = run @@ IrminLogLeadMem.init ~root:"/tmp/ezirminl/lead/mempool" ~bare:true () in
    print_mempool_list mempool_repo !mempools
  end;;

if !help then begin
  Printf.printf "\nGETSIZE - A helper function to print the sizes of Logan's blockchains and mempools.
                \n-b                 Print the blockchain size
                \n-p                 Print the size of a local participant
                \n-m arg1 arg2 ...   Print the size of mempools with ids/branch names ar1, arg2,...
                \n"
end;;
print();;
