data = importdata("~/Documents/PartIILogs/leader_delays_remote_fast.log", ' ');
data = data(1:end-1,:);
mempool_network = data(:,2) - data(:,1);
add_to_blockchain = data(:,10) - data(:,9);
sizes = [31 93 119 147 214 253 314 374 379 452 464 542 586 714 737 830 957 1050 ];
x = (1:length(mempool_network)) * 621;

figure 
hold on
yyaxis left
plot(x, mempool_network);
plot(x, add_to_blockchain);
ylabel("Latencies, s");
yyaxis right 
plot(x, sizes);
hold off
lgd = legend("Retrieving Mempool Updates over Network", "Adding Updates to Blockchain");
lgd.Location = 'northwest';

xlabel("Blockchain size, txns");
ylabel("Number of updates pulled");