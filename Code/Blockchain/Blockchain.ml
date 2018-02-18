module type I_LeaderRemotes = Leader.I_Remotes
module MakeLeader = Leader.Make
module type I_ParticipantConfig = Participant.I_ParticipantConfig
module MakeParticipant = Participant.Make
module type I_LogStringCoder = Participant.I_LogStringCoder
