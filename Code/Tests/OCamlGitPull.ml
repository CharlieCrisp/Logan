open Lwt.Infix
let run = Lwt_main.run

module Log = Ezirmin.FS_log(Tc.String)

let repo = run @@ Log.init ~root:"/tmp/ezirminl/part/mempool" ~bare:true ()
let master = run @@ Log.master repo
let internal = run @@ Log.get_branch repo "internal"

let remote = Log.Sync.remote_uri "git+ssh://charlie@13.93.85.207/tmp/ezirminl/part/mempool";;

let first_time = Ptime_clock.now();;
run @@ Log.Sync.pull remote internal `Update;;
let middle_time = Ptime_clock.now();;
run @@ Log.Sync.pull remote master `Update;;
let last_time = Ptime_clock.now()
let dif1 = (Ptime.to_float_s middle_time) -. (Ptime.to_float_s first_time);;
let dif2 = (Ptime.to_float_s last_time) -. (Ptime.to_float_s middle_time);;
Printf.printf "Time pulling internal: %f\nTime pulling master: %f\n%!" dif1 dif2;; 