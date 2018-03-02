all:
	@jbuilder build Code/Examples/LeaderDemo.exe
	@jbuilder build Code/Examples/ParticipantDemo.exe
	@jbuilder build Code/Tests/TestLeader.exe
	@jbuilder build Code/Tests/ThroughputLatencyTester.exe
	@jbuilder build Code/Tests/GatherLeaderResults.exe
	@mkdir -p bin
	@mv _build/default/Code/Examples/LeaderDemo.exe bin/lead.exe
	@mv _build/default/Code/Examples/ParticipantDemo.exe bin/part.exe
	@mv _build/default/Code/Tests/ThroughputLatencyTester.exe bin/ThroughputLatencyTester.exe
	@mv _build/default/Code/Tests/TestLeader.exe bin/TestLeader.exe
	@mv _build/default/Code/Tests/GatherLeaderResults.exe bin/GatherLeaderResults.exe

lead:
	@jbuilder build Code/Examples/LeaderDemo.exe
	@mkdir -p bin
	@mv _build/default/Code/Examples/LeaderDemo.exe bin/lead.exe

part:
	@jbuilder build Code/Examples/ParticipantDemo.exe
	@mkdir -p bin
	@mv _build/default/Code/Examples/ParticipantDemo.exe bin/part.exe

test:
	@jbuilder build Code/Tests/TestLeader.exe
	@jbuilder build Code/Tests/ThroughputLatencyTester.exe
	@jbuilder build Code/Tests/GatherLeaderResults.exe
	@mkdir -p bin
	@mv _build/default/Code/Tests/ThroughputLatencyTester.exe bin/ThroughputLatencyTester.exe
	@mv _build/default/Code/Tests/TestLeader.exe bin/TestLeader.exe
	@mv _build/default/Code/Tests/GatherLeaderResults.exe bin/GatherLeaderResults.exe

clean:
	@jbuilder clean
	@rm -rf /tmp/ezirminl
	@rm -rf ./bin
	@rm ./*.log
