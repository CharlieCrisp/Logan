all:
	jbuilder build src/Leader/LogCreator.exe
	jbuilder build src/Participant/ParticipantRunner.exe

leader:
	_build/default/src/Leader/LogCreator.exe

participant:
	_build/default/src/Participant/ParticipantRunner.exe

clean:
	jbuilder clean
	rm *~