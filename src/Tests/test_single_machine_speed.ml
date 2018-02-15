open Lwt.Infix
module IrminLogMem = Ezirmin.FS_log(Tc.String)

let run = Lwt_main.run;;
let root = "/tmp/ezirminl/mempool"
let mempool_master_branch = Lwt_main.run (IrminLogMem.init ~root:root ~bare:true () >>= IrminLogMem.master)
let path = []

let add_local_message_to_mempool message =
  IrminLogMem.clone_force mempool_master_branch "wip" >>= fun wip_branch ->
  IrminLogMem.append ~message:"Entry added to the blockchain" wip_branch ~path:path message >>= fun _ -> 
  IrminLogMem.merge wip_branch ~into:mempool_master_branch ;;
let add_transaction_to_mempool sender_id receiver_id book_id =
  let message = LogStringCoder.encode_string sender_id receiver_id book_id in 
    add_local_message_to_mempool message;;

let rec test_blockchain n = 
  let nstr = string_of_int n in
  let sender = "sender: "^nstr in 
  let receiver = "receiver: "^nstr in
  let book = "book: "^nstr in
  match n with
  | 0 -> Lwt.return @@ add_transaction_to_mempool sender receiver book
  | _ -> add_transaction_to_mempool sender receiver book >>= fun _ ->
    test_blockchain (n-1);;

run @@ test_blockchain 10;;