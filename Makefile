all:
	jbuilder build src/Examples/LeaderDemo.exe
	jbuilder build src/Examples/ParticipantDemo.exe

lead:
	_build/default/src/Examples/LeaderDemo.exe

part:
	_build/default/src/Examples/ParticipantDemo.exe

tester:
	_build/default/src/Tests/test_single_machine_speed.exe

flush:
	jbuilder clean
	rm -rf /tmp/ezirminl
	jbuilder build src/Examples/LeaderDemo.exe
	jbuilder build src/Examples/ParticipantDemo.exe