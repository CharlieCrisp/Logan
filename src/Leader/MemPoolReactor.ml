open Lwt.Infix

let callback message = Lwt.return (Printf.printf "Message received: %s" message)
