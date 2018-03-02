module Logger = struct
  let error str = 
    let log = open_out_gen [Open_creat; Open_text; Open_append] 0o640 "blockchain.log" in
    Printf.fprintf log "[ERROR] %s\n" str;
    close_out log

  let debug str = 
    let log = open_out_gen [Open_creat; Open_text; Open_append] 0o640 "blockchain.log" in
    Printf.fprintf log "[DEBUG] %s\n" str;
    close_out log

  let info str = 
    let log = open_out_gen [Open_creat; Open_text; Open_append] 0o640 "blockchain.log" in
    Printf.fprintf log "[INFO] %s\n" str;
    close_out log
  
  let log str = 
    let log = open_out_gen [Open_creat; Open_text; Open_append] 0o640 "output.log" in
    Printf.fprintf log "%s\n" str;
    close_out log
end