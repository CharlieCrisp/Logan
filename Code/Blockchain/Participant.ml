open Lwt.Infix

module type I_LogStringCoder = sig
  type t
  val encode_string: t -> string
  val decode_string: string -> t option
end

module type I_ParticipantConfig = sig
  type t
  module LogCoder: I_LogStringCoder with type t = t

  val is_local: bool
  val leader_uri: string
  val is_validated: bool
  val try_validate: (t list -> t -> bool) option
end

module type I_Participant = sig 
  type t
  val add_transaction_to_mempool: t -> [> `Could_Not_Pull_From_Remote | `Validation_Failure | `Ok] Lwt.t
  val get_transactions_from_blockchain: int -> [> `Error | `Ok of t list] Lwt.t
  val get_all_transactions_from_blockchain: unit -> [> `Error | `Ok of t list] Lwt.t
end

module Make(Config: I_ParticipantConfig): I_Participant with type t = Config.t = struct 
  type t = Config.t 
  module IrminLog = Ezirmin.FS_log(Tc.String)
  let mempool_master_branch = Lwt_main.run (IrminLog.init ~root:"/tmp/ezirminl/part/mempool" ~bare:true () >>= IrminLog.master)
  let blockchain_master_branch = Lwt_main.run (IrminLog.init ~root:"/tmp/ezirminl/lead/blockchain" ~bare:true () >>= IrminLog.master)
  let remote_mem = IrminLog.Sync.remote_uri (Printf.sprintf "git+ssh://%s/tmp/ezirminl/lead/mempool" Config.leader_uri)
  let remote_block = IrminLog.Sync.remote_uri (Printf.sprintf "git+ssh://%s/tmp/ezirminl/lead/blockchain" Config.leader_uri)

  let rec flat_map = function 
    | [] -> []
    | (Some(x)::xs) -> (x::(flat_map xs))
    | (None::xs) -> flat_map xs

  let get_all_transactions_from_blockchain () = 
    IrminLog.Sync.pull remote_block blockchain_master_branch `Update >>= fun _ ->
    IrminLog.get_cursor blockchain_master_branch [] >>= function 
      | Some(cursor) -> IrminLog.read_all blockchain_master_branch [] >>= (function encoded_list ->
        let list = (List.map (Config.LogCoder.decode_string) encoded_list) in 
        Lwt.return @@ `Ok (flat_map list))
      | _ -> Lwt.return `Error

  let get_transactions_from_blockchain n = 
    IrminLog.Sync.pull remote_block blockchain_master_branch `Update >>= fun _ ->
    IrminLog.get_cursor blockchain_master_branch [] >>= function 
      | Some(cursor) -> IrminLog.read cursor n >>= (function
        | (encoded_list, _) -> let list = (List.map (Config.LogCoder.decode_string) encoded_list) in 
          Lwt.return @@ `Ok (flat_map list))
      | _ -> Lwt.return `Error
  
  (*This function will not attempt to validate any transaction*)
  let force_transaction_to_mempool value =
    let add_local_message_to_mempool message =
      IrminLog.append ~message:"Entry added to the blockchain" mempool_master_branch ~path:[] message in
    let message = Config.LogCoder.encode_string value in 
    match Config.is_local with
      | true -> add_local_message_to_mempool message >>= fun _ -> Lwt.return `Ok
      | false -> Lwt.catch 
        (fun _ -> IrminLog.Sync.pull remote_mem mempool_master_branch `Merge) 
        (fun _ -> Lwt.return `Error) >>= (function
          | `Ok -> add_local_message_to_mempool message >>= fun _ -> Lwt.return `Ok
          | _ -> Lwt.return `Could_Not_Pull_From_Remote)

  let add_transaction_to_mempool value =
    match Config.is_validated with 
      | true -> (get_all_transactions_from_blockchain() >>= function
        | `Ok blockchain -> (
          match Config.try_validate with
          | Some(f) -> (let should_commit = f blockchain value in
            match should_commit with 
            | true -> force_transaction_to_mempool value
            | false -> Lwt.return `Validation_Failure)
          | None -> Lwt.return `Validation_Failure)
        | _ -> Lwt.return `Validation_Failure)
      | false -> force_transaction_to_mempool value

end
