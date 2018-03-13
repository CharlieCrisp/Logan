open Lwt.Infix

module type I_LogStringCoder = sig
  type t
  type log_item
  val encode_string: t -> string
  val decode_string: string -> t option
  val decode_log_item: string -> log_item
  val is_equal: log_item -> log_item -> bool
  val get_time_diff: log_item -> log_item -> float
  val get_time: log_item -> float
  val get_rate: log_item -> float
  val get_machine: log_item -> string
end

module type I_ParticipantConfig = sig
  type t
  module LogCoder: I_LogStringCoder with type t = t
  val leader_uri: string option
  val validator: (t list -> t -> bool) option
end

module type I_Participant = sig 
  type t
  val add_transaction_to_mempool: t -> [> `Could_Not_Pull_From_Remote | `Validation_Failure | `Ok] Lwt.t
  val get_transactions_from_blockchain: int -> [> `Error | `Ok of t list] Lwt.t
  val get_all_transactions_from_blockchain: unit -> [> `Error | `Ok of t list] Lwt.t
end

module Make(Config: I_ParticipantConfig): I_Participant with type t = Config.t = struct 
  type t = Config.t 
  module IrminLogMem = Ezirmin.FS_log(Tc.String)
  module IrminLogBlock = Ezirmin.FS_log(Tc.String)
  let mempool_repo = Lwt_main.run @@ IrminLogMem.init ~root:"/tmp/ezirminl/part/mempool" ~bare:true ()
  let blockchain_repo = Lwt_main.run @@ IrminLogBlock.init ~root:"/tmp/ezirminl/lead/blockchain" ~bare:true ()
  let mempool_master_branch = Lwt_main.run @@ IrminLogMem.master mempool_repo
  let blockchain_master_branch = Lwt_main.run @@ IrminLogBlock.master blockchain_repo
  let remote_mem_opt = match Config.leader_uri with 
    | Some(uri) -> Some(IrminLogMem.Sync.remote_uri (Printf.sprintf "git+ssh://%s/tmp/ezirminl/lead/mempool" uri))
    | None -> None
  let remote_block_opt = match Config.leader_uri with 
    | Some(uri) -> Some(IrminLogBlock.Sync.remote_uri (Printf.sprintf "git+ssh://%s/tmp/ezirminl/lead/blockchain" uri))
    | None -> None

  let pull_block = match remote_block_opt with 
    | Some(remote_block) ->
      IrminLogBlock.get_branch blockchain_repo "internal" >>= fun ib ->
      IrminLogBlock.Sync.pull remote_block blockchain_master_branch `Merge >>= fun _ ->
      IrminLogBlock.Sync.pull remote_block ib `Merge
    | _ -> Lwt.return `Error

  let pull_mem = match remote_mem_opt with
    | Some(remote_mem) -> 
      Printf.printf "Pulling from leader";
      IrminLogMem.get_branch mempool_repo "internal" >>= fun ib ->
      IrminLogMem.Sync.pull remote_mem mempool_master_branch `Merge >>= fun _ ->
      IrminLogMem.Sync.pull remote_mem ib `Merge
    | _ -> Lwt.return `Error

  let rec flat_map = function 
    | [] -> []
    | (Some(x)::xs) -> (x::(flat_map xs))
    | (None::xs) -> flat_map xs

  let get_all_transactions_from_blockchain () = 
    pull_block >>= fun _ ->
    IrminLogBlock.get_cursor blockchain_master_branch [] >>= function 
      | Some(cursor) -> IrminLogBlock.read_all blockchain_master_branch [] >>= (function encoded_list ->
        let list = (List.map (Config.LogCoder.decode_string) encoded_list) in 
        Lwt.return @@ `Ok (flat_map list))
      | _ -> Lwt.return `Error

  let get_transactions_from_blockchain n = 
    pull_block >>= fun _ ->
    IrminLogBlock.get_cursor blockchain_master_branch [] >>= function 
      | Some(cursor) -> IrminLogBlock.read cursor n >>= (function
        | (encoded_list, _) -> let list = (List.map (Config.LogCoder.decode_string) encoded_list) in 
          Lwt.return @@ `Ok (flat_map list))
      | _ -> Lwt.return `Error
  
  (*This function will not attempt to validate any transaction*)
  let force_transaction_to_mempool value =
    let add_local_message_to_mempool message =
      IrminLogMem.clone_force mempool_master_branch "wip" >>= fun wip_branch ->
      IrminLogMem.append ~message:"Entry added to the blockchain" wip_branch ~path:[] message >>= fun _ ->
      IrminLogMem.merge wip_branch ~into:mempool_master_branch in
    let message = Config.LogCoder.encode_string value in 
    match Config.leader_uri with
      | None -> add_local_message_to_mempool message >>= fun _ -> Lwt.return `Ok
      | _ -> Lwt.catch 
        (fun _ -> pull_mem) 
        (fun _ -> Lwt.return `Error) >>= (function
          | `Ok -> add_local_message_to_mempool message >>= fun _ -> Lwt.return `Ok
          | _ -> Lwt.return `Could_Not_Pull_From_Remote)

  let add_transaction_to_mempool value =
    match Config.validator with 
      | Some(f) -> (get_all_transactions_from_blockchain() >>= function
        | `Ok blockchain -> (let should_commit = f blockchain value in
          match should_commit with 
          | true -> force_transaction_to_mempool value
          | false -> Lwt.return `Validation_Failure)
        | _ -> Lwt.return `Validation_Failure)
      | None -> force_transaction_to_mempool value

end
