open Core_extended.Std;;

type logItem = 
    { time: Time.t;
      senderID: string;
      receiverID: string;
      bookID: string }

let buildJSON senderID receiverID bookID = 
  let str = Ezjsonm.string in 
  let now = Time.to_string (Time.now()) in 
  let time = ("Time", str now) in
  let send = ("SenderID", str senderID) in 
  let receiver = ("ReceiverID", str receiverID) in
  let book = ("BookID", str bookID) in
  Ezjsonm.dict [time;send;receiver;book]

let encodeString senderID receiverID bookID = 
  let json = buildJSON senderID receiverID bookID
  in Ezjsonm.to_string json