module type TransactionRequest = sig
  type transaction
  val senderId: string
  val receiverId: string
  val transaction: transaction
end