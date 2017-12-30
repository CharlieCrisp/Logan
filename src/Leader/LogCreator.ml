open Lwt.Infix
module M = Ezirmin.FS_log(Tc.String)
open M

let blockchainMasterBranch = Lwt_main.run (init ~root: "/tmp/ezirminl/blockchain" ~bare:true () >>= master)
let memPoolMasterBranch = Lwt_main.run (init ~root: "/tmp/ezirminl/mempool" ~bare: true () >>= master)

let run = Lwt_main.run
let path = []
let callback = MemPoolReactor.callback;;
install_listener ();;
watch memPoolMasterBranch path callback;; (*TODO figure out how to get this working*)
Lwt_io.write Lwt_io.stdout "Thing\n";;
append ~message:"commiting from file" memPoolMasterBranch ~path:path "message";;