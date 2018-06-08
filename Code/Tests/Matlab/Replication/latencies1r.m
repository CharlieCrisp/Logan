format long;
extra_latencies = importdata("~/Documents/PartIILogs/Replication/commitlatencies1r", ' ');
original_latencies = importdata("~/Documents/PartIILogs/Replication/fulllatencies1r", ' ');
benchmark = importdata("~/Documents/PartIILogs/Replication/benchmark", ' ');
benchmark2 = importdata("~/Documents/PartIILogs/Replication/benchmark2", ' ');
benchmark = benchmark(:,2) - benchmark(:,1);
benchmark2 = benchmark2(:,2) - benchmark2(:,1);
original_latencies = (original_latencies(:,2) - original_latencies(:,1));
full_latencies = original_latencies + extra_latencies;

figure
hold on
plot(1:length(extra_latencies),extra_latencies);
plot(1:length(full_latencies),full_latencies); 
xlabel("Blockchain Size, txns");
ylabel("Latency, s");
hold off
figure
hold on
plot(1:length(original_latencies), original_latencies);
plot(1:length(benchmark), benchmark);
xlabel("Blockchain Size, txns");
ylabel("Latency, s");
hold off
figure
hold on
plot(1:length(benchmark), benchmark);
plot(1:length(benchmark2), benchmark2);