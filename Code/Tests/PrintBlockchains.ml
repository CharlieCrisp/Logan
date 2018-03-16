open Lwt.Infix

module IrminLogBlock = Ezirmin.FS_log(Tc.String)
module IrminLogMem = Ezirmin.FS_log(Tc.String)
module IrminLogLeadMem = Ezirmin.FS_log(Tc.String)
module Coder = LogStringCoder.TestLogStringCoder
let run = Lwt_main.run
let path = []
let blockchain_repo = run @@ IrminLogBlock.init ~root: "/tmp/ezirminl/lead/blockchain" ~bare:true ()
let blockchain_master_branch = Lwt_main.run @@ IrminLogBlock.master blockchain_repo
let mempool_repo = run @@ IrminLogMem.init ~root: "/tmp/ezirminl/part/mempool" ~bare:true ()
let mempool_master_branch = Lwt_main.run @@ IrminLogMem.master mempool_repo
let lead_mempool_repo = run @@ IrminLogLeadMem.init ~root: "/tmp/ezirminl/lead/mempool" ~bare:true ()
let lead_mempool_master_branch = Lwt_main.run @@ IrminLogLeadMem.master lead_mempool_repo

let rec print_list list = match list with 
  | (x::[]) -> Lwt.return @@ Printf.printf "%s%!" x
  | (x::xs) -> Lwt.return @@ Printf.printf "%s\n%!" x >>= fun _ -> print_list xs
  | [] -> Lwt.return @@ ()

let print_list () = Lwt.return @@ Printf.printf "\n\027[92m-----Start Block-----\027[32m\n" >>= fun _ ->
  IrminLogBlock.read_all blockchain_master_branch [] >>= fun list1 ->
  print_list list1 >>= fun _ ->
  Lwt.return @@ Printf.printf "\n\027[93m-----Start MemPo-----\027[33m\n" >>= fun _ ->
  IrminLogMem.read_all mempool_master_branch [] >>= fun list2 ->
  print_list list2 >>= fun _ ->
  Lwt.return @@ Printf.printf "\n\027[91m------End MemPo------\027[39m\n\n%!" >>= fun _ ->
  IrminLogLeadMem.read_all lead_mempool_master_branch [] >>= fun list3 ->
  print_list list3 >>= fun _ ->
  Printf.printf "\n\027[91m------End MemPo------\027[39m\n\n%!";
  Lwt.return @@Printf.printf "Blockchain: %i, Part Mempool: %i, Lead Mempool: %i\n%!" (List.length list1) (List.length list2) (List.length list3);;

  Lwt_main.run @@ print_list();;