format long;
new_latencies = importdata("~/Documents/PartIILogs/Replication/new_latencies.log", ' ');
benchmark = importdata("~/Documents/PartIILogs/Replication/benchmark", ' ');
benchmark = benchmark(:,2) - benchmark(:,1);
new_latencies = (new_latencies(:,2) - new_latencies(:,1));

figure
hold on
plot(1:length(new_latencies), new_latencies);
plot(1:length(benchmark), benchmark);
xlabel("Blockchain Size, txns");
ylabel("Latency, s");
hold off
