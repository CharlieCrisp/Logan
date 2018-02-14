all:
	jbuilder build src/Examples/LogCreatorDemo.exe
	jbuilder build src/Participant/ParticipantRunner.exe
	jbuilder build src/Tests/test_single_machine_speed.exe

lead:
	_build/default/src/Examples/LogCreatorDemo.exe

part:
	_build/default/src/Participant/ParticipantRunner.exe

tester:
	_build/default/src/Tests/test_single_machine_speed.exe

flush:
	jbuilder clean
	rm -rf /tmp/ezirminl
	jbuilder build src/Tests/test_single_machine_speed.exe
	jbuilder build src/Examples/LogCreatorDemo.exe
	jbuilder build src/Participant/ParticipantRunner.exe