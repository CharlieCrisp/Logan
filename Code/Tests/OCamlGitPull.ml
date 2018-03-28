open Lwt.Infix
let run = Lwt_main.run

module Log = Ezirmin.FS_log(Tc.String)

let repo = run @@ Log.init ~root:"/tmp/ezirminl/part/mempool" ~bare:true ()
let master = run @@ Log.master repo
let internal = run @@ Log.get_branch repo "internal"
let wip = run @@ Log.get_branch repo "wip"

let remote = Log.Sync.remote_uri "git+ssh://root@23.253.159.211/tmp/ezirminl/part/mempool";;

let first_time = Ptime_clock.now();;
run @@ Log.Sync.pull remote internal `Update;;
run @@ Log.Sync.pull remote master `Update;;
run @@ Log.Sync.pull remote wip `Update;;
let last_time = Ptime_clock.now()
let dif = (Ptime.to_float_s last_time) -. (Ptime.to_float_s first_time);;
Printf.printf "%f\n" dif ;; 