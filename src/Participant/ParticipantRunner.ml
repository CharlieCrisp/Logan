open Lwt.Infix
module IrminLogMem = Ezirmin.FS_log(Tc.String)

let memPoolMasterBranch = Lwt_main.run (IrminLogMem.init ~root: "/tmp/ezirminl/mempool" ~bare: true () >>= IrminLogMem.master)
let run = Lwt_main.run
let path = []

let addTransactionToMemPool value =
  let message = LogStringCoder.encodeString "some id" "another id" value in 
  IrminLogMem.clone_force memPoolMasterBranch "wip" >>= fun wipBranch ->
  IrminLogMem.append ~message:"Entry added to the blockchain" wipBranch ~path:path message >>= fun _ -> 
  IrminLogMem.merge wipBranch ~into:memPoolMasterBranch;;

run @@ Lwt_io.write_line Lwt_io.stdout "Hi There, input a value: ";;
let thing = run @@ Lwt_io.read_line Lwt_io.stdin;;
run @@ Lwt_io.write_line Lwt_io.stdout thing;;
