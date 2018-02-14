module Remote : Blockchain.Remotes= struct
  let remotes = ["asdfasdfsd"]
end

module Leader = Blockchain.Leader(Remote);;
Lwt_main.run @@ Leader.start_leader();;