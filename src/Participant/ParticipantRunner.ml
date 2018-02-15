open Lwt.Infix
module IrminLogMem = Ezirmin.FS_log(Tc.String)

let run = Lwt_main.run;;
let write value = Lwt_io.write Lwt_io.stdout value;;
let read () = Lwt_io.read_line Lwt_io.stdin ;;
let push = IrminLogMem.Sync.push;;
let pull = IrminLogMem.Sync.pull;;

let root = "/tmp/ezirminl/mempool"
let mempool_master_branch = Lwt_main.run (IrminLogMem.init ~root:root ~bare:true () >>= IrminLogMem.master)
let path = []

let get_id () = write "\n\027[93mWhat is your current ID: \027[39m" >>= fun _ ->
  read()

let get_is_remote () = write "\027[93mIs your destination log local or remote (l/r): \027[39m" >>= fun _ ->
  read () >>= function
    | "r" -> Lwt.return true
    | _ -> Lwt.return false

let try_get_remote_repo is_remote = match is_remote with
    | true -> write "Destination Username: " >>= fun _ ->
      read() >>= fun user ->
      write "Destination Hostname: " >>= fun _ ->
      read() >>= fun host ->
      Lwt.return @@ IrminLogMem.Sync.remote_uri ("git+ssh://"^user^"@"^host^"/tmp/ezirmin/mempool") >>= fun remote ->
      Lwt.return @@ Some(remote)
    | _ -> Lwt.return None


let current_id = run @@ get_id()
let is_remote = run @@ get_is_remote()
let opt_remote = run @@ try_get_remote_repo is_remote
exception Remote_Not_Found
exception Could_Not_Pull_From_Remote
exception Could_Not_Push_To_Remote

let add_local_message_to_mempool message =
  IrminLogMem.clone_force mempool_master_branch "wip" >>= fun wip_branch ->
  IrminLogMem.append ~message:"Entry added to the blockchain" wip_branch ~path:path message >>= fun _ -> 
  IrminLogMem.merge wip_branch ~into:mempool_master_branch ;;

let add_transaction_to_mempool sender_id receiver_id book_id =
  let message = LogStringCoder.encode_string sender_id receiver_id book_id in 
  match is_remote with
    | false -> add_local_message_to_mempool message
    | true -> (match opt_remote with 
      | Some(remote) -> pull remote mempool_master_branch `Merge >>= (function
        | `Ok -> add_local_message_to_mempool message >>= fun _ ->
          push remote mempool_master_branch >>= (function
            | `Ok -> Lwt.return ()
            | _ -> raise Could_Not_Push_To_Remote)
        | _ -> raise Could_Not_Pull_From_Remote)
      | None -> raise Remote_Not_Found)

let get_log_entry_tuple () = 
  write "\n\027[39mTheir ID (receiver): \027[39m" >>= fun _ ->
  read() >>= fun receiver_id ->
  write "\027[39mItem ID (book): \027[39m" >>= fun _ ->
  read() >>= fun book_id ->
  Lwt.return (current_id, receiver_id, book_id)

let rec start_participant () = 
  write "\027[35m-----------------------------------\n-----Enter Transaction Details-----\027[39m" >>= fun _ ->
  get_log_entry_tuple() >>= fun (sender, receiver, book) ->
  add_transaction_to_mempool sender receiver book >>= fun _ ->
  write "\n\027[32mITEM ADDED SUCCESSFULLY\n" >>= 
  start_participant;;

run @@ start_participant();;