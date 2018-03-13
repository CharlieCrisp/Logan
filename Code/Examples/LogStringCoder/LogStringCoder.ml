module BookLogStringCoder: Blockchain.I_LogStringCoder with type t = string * string * string = struct
  
  type t = string * string * string 

  type log_item = 
      { time: float;
        sender_id: string;
        receiver_id: string;
        book_id: string }

  let build_json ((sender_id, receiver_id, book_id):t) = 
    let str = Ezjsonm.string in 
    let now = Ptime.to_float_s (Ptime_clock.now()) in 
    let time = ("time", str (string_of_float now)) in
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

  exception DecodeError
  let decode_log_item str = 
    try
      let json = Ezjsonm.from_string str in
      let dict = Ezjsonm.get_dict json in
      let sender_id = get_value dict "sender_id" in
      let receiver_id = get_value dict "receiver_id" in
      let book_id = get_value dict "book_id" in
      let time = float_of_string(get_value dict "time") in
      {time;sender_id;receiver_id;book_id}
    with 
      | _ -> raise DecodeError

  let is_equal item1 item2 = 
    if item1.time = item2.time then true else false
  
  let get_time_diff item1 item2 =
    abs_float(item1.time -. item2.time)
  let get_time item = item.time
  let get_rate item = 0.0
  let get_machine item = ""
end

module TestLogStringCoder: Blockchain.I_LogStringCoder with type t = string * string * float = struct
  
  type t = string * string * float
  type log_item = 
    { time: float;
      machine_id: string;
      txn_id: string;
      rate: float}

  let build_json ((machine_id, txn_id, rate):t) = 
    let str = Ezjsonm.string in 
    let flt = Ezjsonm.float in
    let now = Ptime.to_float_s (Ptime_clock.now()) in 
    let time = ("time", flt now) in
    let machine = ("machine_id", str machine_id) in 
    let txn = ("txn_id", str txn_id) in
    let rate = ("rate", Ezjsonm.float rate) in
    Ezjsonm.dict [time;machine;txn;rate]

  let encode_string (value:t) = 
    let json = build_json value
    in Ezjsonm.to_string json

  let rec get_value_string (dict:(string * Ezjsonm.value) list) desired_key = match dict with 
    | [] -> ""
    | ((key, `String v)::_) when key = desired_key -> v
    | ((str, _)::xs) -> get_value_string xs desired_key

  let rec get_value_float (dict:(string * Ezjsonm.value) list) desired_key = match dict with 
  | [] -> 0.0
  | ((key, `Float v)::_) when key = desired_key -> v
  | ((str, _)::xs) -> get_value_float xs desired_key

  let decode_string str = 
    try
      let json = Ezjsonm.from_string str in
      let dict = Ezjsonm.get_dict json in
      let machine = get_value_string dict "machine_id" in
      let txn = get_value_string dict "txn_id" in
      let rate = get_value_float dict "rate" in 
      Some((machine, txn, rate):t)
    with 
      | _ -> None

  exception DecodeError
  let decode_log_item str = 
    try
      let json = Ezjsonm.from_string str in
      let dict = Ezjsonm.get_dict json in
      let machine_id = get_value_string dict "machine_id" in
      let txn_id = get_value_string dict "txn_id" in
      let time = get_value_float dict "time" in
      let rate = get_value_float dict "rate" in
      {time;machine_id;txn_id;rate}
    with 
      | _ -> raise DecodeError

  let is_equal item1 item2 = 
    if item1.txn_id = item2.txn_id && item1.machine_id = item2.machine_id then true else false
  
  let get_time_diff item1 item2 =
    abs_float(item1.time -. item2.time)

  let get_time item = item.time

  let get_rate item = item.rate
  let get_machine item = item.machine_id
end
