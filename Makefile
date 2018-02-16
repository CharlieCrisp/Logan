all:
	jbuilder build src/Examples/LeaderDemo.exe
	jbuilder build src/Examples/ParticipantDemo.exe

lead:
	_build/default/src/Examples/LeaderDemo.exe

part:
	_build/default/src/Examples/ParticipantDemo.exe

part_man:
	jbuilder build src/Examples/ManualParticipantDemo.exe
	_build/default/src/Examples/ManualParticipantDemo.exe

tester:
	_build/default/src/Tests/test_single_machine_speed.exe

flush:
	jbuilder clean
	rm -rf /tmp/ezirminl
	jbuilder build src/Examples/LeaderDemo.exe
	jbuilder build src/Examples/ParticipantDemo.exe
