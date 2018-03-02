open Lwt.Infix
module Logger = Logger.Logger

module IrminLogBlock = Ezirmin.FS_log(Tc.String)
module IrminLogMem = Ezirmin.FS_log(Tc.String)
let run = Lwt_main.run
let path = []
let blockchain_repo = run @@ IrminLogBlock.init ~root: "/tmp/ezirminl/lead/blockchain" ~bare:true ()
let blockchain_master_branch = Lwt_main.run @@ IrminLogBlock.master blockchain_repo
let mempool_repo = run @@ IrminLogMem.init ~root: "/tmp/ezirminl/part/mempool" ~bare:true ()
let mempool_master_branch = Lwt_main.run @@ IrminLogMem.master mempool_repo

let rec log_list list = match list with 
    | (x::[]) -> Lwt.return @@ Logger.log x
    | (x::xs) -> Lwt.return @@ Logger.log x >>= fun _ -> log_list xs
    | [] -> Lwt.return @@ ()

let log_list () = Lwt.return @@ Logger.info "\n-----Start Block-----\n" >>= fun _ ->
  IrminLogBlock.read_all blockchain_master_branch [] >>= fun list ->
  log_list list >>= fun _ ->
  Lwt.return @@ Logger.log "\n-----Start MemPo-----\n" >>= fun _ ->
  IrminLogMem.read_all mempool_master_branch [] >>= fun list ->
  log_list list >>= fun _ ->
  Lwt.return @@ Logger.log "\n------End MemPo------\n\n";;

Lwt_main.run @@ log_list();;