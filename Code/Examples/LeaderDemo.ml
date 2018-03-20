(*
This class demonstrates how a blockchain leader may be used 
In this example, a list of remote participants is read from the command line
Therefore, this can be used as such... bin/LeaderDemo user1@host1 user2@host2
*)

open Lwt.Infix

let format_remote str = Printf.printf "Using remote: %s\n%!" str; str

let remotes = List.map format_remote (List.tl (Array.to_list Sys.argv))

(*The following function can be used to demonstrate a validation mechanism*)
(* let fil a b = List.filter (function |("charlie", _,_) -> true | _ -> false) b  *)

module Config : Blockchain.I_LeaderConfig with type t = string * string * string = struct 
  type t = string * string * string
  module LogCoder = LogStringCoder.BookLogStringCoder
  let remotes = remotes
  let validator = None
end

module Leader = Blockchain.MakeLeader(Config);;
Lwt_main.run @@ (Leader.init_leader() >>= fun start_leader ->
  Lwt_io.write Lwt_io.stdout  "\027[95m\nBlockchain initialised. Press any key to start the leader: \027[39m" >>= fun _ ->
  Lwt_io.read_line Lwt_io.stdin >>= fun _ ->
  start_leader());;