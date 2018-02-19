let format_remote str = let value = Printf.sprintf "git+ssh://%s/tmp/ezirminl/part/mempool" str in
  Printf.printf "Using remote: %s\n%!" value; value

let remotes = List.map format_remote (List.tl (Array.to_list Sys.argv))

module Config : Blockchain.I_LeaderConfig = struct
  let remotes = remotes
end

module Leader = Blockchain.MakeLeader(Config);;
Lwt_main.run @@ Leader.start_leader();;