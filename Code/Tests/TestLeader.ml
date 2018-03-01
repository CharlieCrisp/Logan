let format_remote str = let value = Printf.sprintf "git+ssh://%s/tmp/ezirminl/part/mempool" str in
  Printf.printf "Using remote: %s\n%!" value; value

let remotes = List.map format_remote (List.tl (Array.to_list Sys.argv))

(*The following function can be used to demonstrate a validation mechanism*)
(* let fil a b = List.filter (function |("charlie", _,_) -> true | _ -> false) b  *)

module Config : Blockchain.I_LeaderConfig with type t = string * string = struct 
  type t = string * string
  module LogCoder = LogStringCoder.TestLogStringCoder
  let remotes = remotes
  let validator = None
end

module Leader = Blockchain.MakeLeader(Config);;
Lwt_main.run @@ Leader.start_leader();;