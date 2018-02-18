open Lwt.Infix

module type I_ParticipantConfig = sig
  val is_local: bool
  val leader_uri: string
end

module type I_Participant = sig 
  type t
  val add_transaction_to_mempool: t -> [> `Could_Not_Pull_From_Remote | `Ok] Lwt.t
end

module type I_LogStringCoder = sig
  type t
  val encode_string: t -> string
end

module Make(Config: I_ParticipantConfig)(LogCoder: I_LogStringCoder): I_Participant with type t = LogCoder.t = struct 
  type t = LogCoder.t
  module IrminLog = Ezirmin.FS_log(Tc.String)
  let mempool_master_branch = Lwt_main.run (IrminLog.init ~root:"/tmp/ezirminl/part/mempool" ~bare:true () >>= IrminLog.master)
  let remote = IrminLog.Sync.remote_uri Config.leader_uri

  let add_transaction_to_mempool value =
    let add_local_message_to_mempool message =
      IrminLog.append ~message:"Entry added to the blockchain" mempool_master_branch ~path:[] message in
    let message = LogCoder.encode_string value in 
    match Config.is_local with
      | true -> add_local_message_to_mempool message >>= fun _ -> Lwt.return `Ok
      | false -> Lwt.catch 
        (fun _ -> IrminLog.Sync.pull remote mempool_master_branch `Merge) 
        (fun _ -> Lwt.return `Error) >>= (function
          | `Ok -> add_local_message_to_mempool message >>= fun _ -> Lwt.return `Ok
          | _ -> Lwt.return `Could_Not_Pull_From_Remote)
end
