all:
	jbuilder build src/Leader/LogCreator.exe
	jbuilder build src/Participant/ParticipantRunner.exe

lead:
	_build/default/src/Leader/LogCreator.exe

part:
	_build/default/src/Participant/ParticipantRunner.exe

clean:
	jbuilder clean
	rm -rf /tmp/ezirminl
	rm *~