open Lwt.Infix
module Logger = Logger.Logger

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

let rec log_list list = match list with 
    | (x::[]) -> Lwt.return @@ Logger.log x
    | (x::xs) -> Lwt.return @@ Logger.log x >>= fun _ -> log_list xs
    | [] -> Lwt.return @@ ()

let find_matching item list = let item_decoded = Coder.decode_log_item item in 
  if item = "Genesis Commit" then None else
  let rec loop = function 
    | (x::_) when x = "Genesis Commit" -> None
    | (x::xs) -> (let comparison_item = Coder.decode_log_item x in 
      if Coder.is_equal comparison_item item_decoded 
      then 
        Some((item_decoded, comparison_item), xs)
      else 
        loop xs )
    | [] -> None
    in loop list

(*Log pairs of values for matching txns: add time and commit time. I.e. when added to mempool vs blockchain*)
let rec log_all_matching mempool_list blockchain_list = match mempool_list with 
  | (x::xs) -> let opt = find_matching x blockchain_list in (
    match opt with 
      | Some((mempool_item,blockchain_item), new_blockchain) ->
        Logger.log (Printf.sprintf "%f %f %f" (Coder.get_time mempool_item) (Coder.get_time blockchain_item) (Coder.get_rate mempool_item));
        log_all_matching xs new_blockchain
      | _ ->  Logger.log (Printf.sprintf "%f" (Coder.get_time (Coder.decode_log_item x)));
        log_all_matching xs blockchain_list )
  | [] -> ()

let log_list () =
  IrminLogBlock.read_all blockchain_master_branch [] >>= fun blockchain_list ->
  Printf.printf "Blockchain size: %i\n" (List.length blockchain_list);
  IrminLogMem.read_all mempool_master_branch [] >>= fun mempool_list ->
  Printf.printf "Mempool size: %i\n" (List.length mempool_list);
  Lwt.return @@ log_all_matching mempool_list blockchain_list;;

Lwt_main.run @@ log_list();;

(* This is optional debug code to print out the contents of the blockchain/mempools after finishing data gathering *)

(* let rec print_list list = match list with 
  | (x::[]) -> Lwt.return @@ Printf.printf "%s%!" x
  | (x::xs) -> Lwt.return @@ Printf.printf "%s\n%!" x >>= fun _ -> print_list xs
  | [] -> Lwt.return @@ ()

let print_list () = Lwt.return @@ Printf.printf "\n\027[92m-----Start Block-----\027[32m\n" >>= fun _ ->
  IrminLogBlock.read_all blockchain_master_branch [] >>= fun list ->
  print_list list >>= fun _ ->
  Lwt.return @@ Printf.printf "\n\027[93m-----Start MemPo-----\027[33m\n" >>= fun _ ->
  IrminLogMem.read_all mempool_master_branch [] >>= fun list ->
  print_list list >>= fun _ ->
  Lwt.return @@ Printf.printf "\n\027[91m------End MemPo------\027[39m\n\n%!" >>= fun _ ->
  IrminLogLeadMem.read_all lead_mempool_master_branch [] >>= fun list ->
  print_list list >>= fun _ ->
  Lwt.return @@ Printf.printf "\n\027[91m------End MemPo------\027[39m\n\n%!";;

  Lwt_main.run @@ print_list();; *)