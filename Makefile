all:
	jbuilder build Code/Examples/LeaderDemo.exe
	jbuilder build Code/Examples/ParticipantDemo.exe
	mkdir -p bin
	mv _build/default/Code/Examples/LeaderDemo.exe bin/lead.exe
	mv _build/default/Code/Examples/ParticipantDemo.exe bin/part.exe

lead:
	jbuilder build Code/Examples/LeaderDemo.exe
	mkdir -p bin
	mv _build/default/Code/Examples/LeaderDemo.exe bin/lead.exe

part:
	jbuilder build Code/Examples/ParticipantDemo.exe
	mkdir -p bin
	mv _build/default/Code/Examples/ParticipantDemo.exe bin/part.exe

test:
	jbuilder build Code/Tests/test_single_machine_speed.exe
	mkdir -p bin
	mv _build/default/Code/Tests/test_single_machine_speed.exe bin/test_single_machine_speed.exe

clean:
	jbuilder clean
	rm -rf /tmp/ezirminl
	rm -rf ./bin
	rm ./blockchain.log
