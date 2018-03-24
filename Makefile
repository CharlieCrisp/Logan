all:
	@jbuilder build Code/Examples/LeaderDemo.exe
	@jbuilder build Code/Examples/ParticipantDemo.exe
	@mkdir -p bin
	@mv _build/default/Code/Examples/LeaderDemo.exe bin/lead
	@mv _build/default/Code/Examples/ParticipantDemo.exe bin/part

test:
	@jbuilder build Code/Tests/TestLeader.exe
	@jbuilder build Code/Tests/ThroughputLatencyTester.exe
	@jbuilder build Code/Tests/GatherResults.exe
	@jbuilder build Code/Tests/AddNumberToBlockchain.exe
	@jbuilder build Code/Tests/PrintBlockchains.exe
	@jbuilder build Code/Tests/GetSize.exe
	@mkdir -p bin
	@mv _build/default/Code/Tests/ThroughputLatencyTester.exe bin/ThroughputLatencyTester
	@mv _build/default/Code/Tests/TestLeader.exe bin/TestLeader
	@mv _build/default/Code/Tests/GatherResults.exe bin/GatherResults
	@mv _build/default/Code/Tests/AddNumberToBlockchain.exe bin/AddNumberToBlockchain
	@mv _build/default/Code/Tests/PrintBlockchains.exe bin/PrintBlockchains
	@mv _build/default/Code/Tests/GetSize.exe bin/GetSize

clean:
	@jbuilder clean
	@rm -rf /tmp/ezirminl
	@rm -rf ./bin
	@rm ./*.log

clear: 
	@rm -rf /tmp/ezirminl
