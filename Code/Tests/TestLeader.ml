(*
This exe runs a Leader node which uses the LogStringCoder built for testing
*)

open Lwt.Infix
let format_remote str = Printf.printf "Using remote: %s\n%!" str; str

let remotes = List.map format_remote (List.tl (Array.to_list Sys.argv))

(*The following function can be used to demonstrate a validation mechanism*)
(* let fil a b = List.filter (function |("charlie", _,_) -> true | _ -> false) b  *)

module Config : Blockchain.I_LeaderConfig with type t = string * string * float = struct 
  type t = string * string * float
  module LogCoder = LogStringCoder.TestLogStringCoder
  module Validator = struct 
    type t = string * string * float
    let init _ = Lwt.return ()
    let filter list = Lwt.return list
  end
  let remotes = remotes
  let replicas = []
end

module Leader = Blockchain.MakeLeader(Config);;
Lwt_main.run @@ (Leader.init_leader() >>= fun start_leader ->
  Lwt_io.write Lwt_io.stdout  "\027[95m\nBlockchain initialised. Press any key to start the leader: \027[39m" >>= fun _ ->
  Lwt_io.read_line Lwt_io.stdin >>= fun _ ->
  start_leader());;