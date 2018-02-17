let format_remote str = let value = Printf.sprintf "git+ssh://%s/tmp/ezirminl/part/mempool" str in
  Printf.printf "Using remote: %s\n%!" value; value

let remotes = List.map format_remote (List.tl (Array.to_list Sys.argv))

module Remote : Blockchain.Remotes = struct
  let remotes = remotes
end

module Leader = Blockchain.Leader(Remote);;
Lwt_main.run @@ Leader.start_leader();;