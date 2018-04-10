data = importdata("~/Documents/PartIILogs/leader_delays_10txns_ezirmingit.log", ' ');
mempool_network_delays = data(:,1);
add_to_blockchain_delays = data(:,2);
sizes = data(:,3);
x = cumsum(sizes);

figure 
hold on
plot(x, mempool_network_delays, x, add_to_blockchain_delays);
yyaxis left
ylabel("Latencies, s");
yyaxis right 
plot(x, sizes,'-');
xlim([0 5000]);
ylim([0 130]);
hold off

xlabel("Mempool size, txns");
ylabel("Number of Updates");

l = legend("Retrieving mempool updates over network","Adding updates to Blockchain","Updates pulled in each Leader poll");
l.Location = 'northwest';