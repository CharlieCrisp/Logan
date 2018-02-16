module BookLogStringCoder: Participant.I_LogStringCoder with type t = string * string * string = struct
  open Core_extended.Std
  type t = string * string * string 

  type log_item = 
      { time: Time.t;
        sender_id: string;
        receiver_id: string;
        book_id: string }

  let build_json ((sender_id, receiver_id, book_id):t) = 
    let str = Ezjsonm.string in 
    let now = Time.to_string (Time.now()) in 
    let time = ("Time", str now) in
    let send = ("sender_id", str sender_id) in 
    let receiver = ("receiver_id", str receiver_id) in
    let book = ("book_id", str book_id) in
    Ezjsonm.dict [time;send;receiver;book]

  let encode_string (value:t) = 
    let json = build_json value
    in Ezjsonm.to_string json
end