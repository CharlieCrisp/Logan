module BookLogStringCoder: Blockchain.I_LogStringCoder with type t = string * string * string = struct
  
  type t = string * string * string 

  type log_item = 
      { time: float;
        sender_id: string;
        receiver_id: string;
        book_id: string }

  let build_json ((sender_id, receiver_id, book_id):t) = 
    let str = Ezjsonm.string in 
    let now = Unix.time() in 
    let time = ("Time", str (string_of_float now)) in
    let send = ("sender_id", str sender_id) in 
    let receiver = ("receiver_id", str receiver_id) in
    let book = ("book_id", str book_id) in
    Ezjsonm.dict [time;send;receiver;book]

  let encode_string (value:t) = 
    let json = build_json value
    in Ezjsonm.to_string json

  let rec get_value (dict:(string * Ezjsonm.value) list) desired_key = match dict with 
    | [] -> ""
    | ((key, `String v)::_) when key = desired_key -> v
    | ((str, _)::xs) -> get_value xs desired_key

  let decode_string str = 
    try
      let json = Ezjsonm.from_string str in
      let dict = Ezjsonm.get_dict json in
      let sender = get_value dict "sender_id" in
      let receiver = get_value dict "receiver_id" in
      let book = get_value dict "book_id" in 
      Some((sender, receiver, book):t)
    with 
      | _ -> None
end
