open Lwt.Infix
module Logger = Logger.Logger

module IrminLogBlock = Ezirmin.FS_log(Tc.String)
module IrminLogMem = Ezirmin.FS_log(Tc.String)
module IrminLogLeadMem = Ezirmin.FS_log(Tc.String)
module Coder = LogStringCoder.TestLogStringCoder
let remotes = ref []
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

let find_matching item list = 
  if item = "Genesis Commit" then None else
  let item_decoded = Coder.decode_log_item item in 
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
  | (x::xs) when x = "Genesis Commit" -> log_all_matching xs blockchain_list
  | (x::xs) -> let opt = find_matching x blockchain_list in (
    match opt with 
      | Some((mempool_item,blockchain_item), new_blockchain) ->
        Logger.log (Printf.sprintf "%f %f %f %s" (Coder.get_time mempool_item) (Coder.get_time blockchain_item) (Coder.get_rate mempool_item) (Coder.get_machine mempool_item));
        log_all_matching xs new_blockchain
      | _ ->  Logger.log (Printf.sprintf "%f" (Coder.get_time (Coder.decode_log_item x)));
        log_all_matching xs blockchain_list )
  | [] -> ()

let rec get_branches branches = 
  let get_branch branch = run @@ IrminLogLeadMem.get_branch mempool_repo branch in 
  List.fold_left (fun acc branch -> (get_branch branch)::acc) [] branches

let compare str1 str2 = 
  if str1 == "Genesis Commit" then 
    1
  else if str2 == "Genesis Commit" then
    -1
  else 
  let item1 = Coder.decode_log_item str1 in 
  let item2 = Coder.decode_log_item str2 in
  int_of_float ((Coder.get_time item1) -. (Coder.get_time item2))

let log_list_remotes () =
  let branches = get_branches !remotes in
  IrminLogBlock.read_all blockchain_master_branch [] >>= fun blockchain_list ->
  let items = List.fold_left (fun acc bra -> let items = run @@ IrminLogLeadMem.read_all bra [] in items @ acc) [] branches in
  let sorted_items = List.sort compare items in
  Lwt.return @@ log_all_matching sorted_items blockchain_list;;

let log_list_local () =
  IrminLogBlock.read_all blockchain_master_branch [] >>= fun blockchain_list ->
  Printf.printf "Blockchain size: %i\n" (List.length blockchain_list);
  IrminLogMem.read_all mempool_master_branch [] >>= fun mempool_list ->
  Printf.printf "Mempool size: %i\n" (List.length mempool_list);
  Lwt.return @@ log_all_matching mempool_list blockchain_list;;

let arg_local = ("-l", Arg.Unit (fun () -> run @@ log_list_local()), "Gather results from a local Participant")
let arg_remote = ("-r", Arg.Rest (fun str -> remotes := str::!remotes), "Gather results from remote Participants")
let _ = Arg.parse [arg_local;arg_remote] (fun _ -> ()) ""

let _ = if (!remotes != []) then
  run @@ log_list_remotes()