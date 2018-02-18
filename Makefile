all:
	jbuilder build Code/Examples/LeaderDemo.exe
	jbuilder build Code/Examples/ParticipantDemo.exe

lead:
	_build/default/Code/Examples/LeaderDemo.exe

part:
	_build/default/Code/Examples/ParticipantDemo.exe

part_man:
	jbuilder build Code/Examples/ManualParticipantDemo.exe
	_build/default/Code/Examples/ManualParticipantDemo.exe

tester:
	_build/default/Code/Tests/test_single_machine_speed.exe

flush:
	jbuilder clean
	rm -rf /tmp/ezirminl
	jbuilder build Code/Examples/LeaderDemo.exe
	jbuilder build Code/Examples/ParticipantDemo.exe
