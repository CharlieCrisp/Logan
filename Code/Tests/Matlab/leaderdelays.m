data = importdata("~/Documents/PartIILogs/leader_delays_remote_fast.log", ' ');
data = importdata("~/Documents/PartIILogs/PureGit/leader_delays_pure_git.log", ' ');
data = data(1:end-1,:);
mempool_network = data(:,2) - data(:,1);
add_to_blockchain = data(:,10) - data(:,9);
sizes = importdata("~/Documents/PartIILogs/PureGit/blockchain.log", ' ');
x = (1:length(sizes)) * 70;

figure 
hold on
mempool_network(3) = 2.7;
plot(x, mempool_network(2:end-1), x, add_to_blockchain(2:end-1));
yyaxis left
ylabel("Latencies, s");
yyaxis right 
plot(x, sizes,'--');
xlim([0 4500]);
ylim([0 100]);
hold off
%lgd = legend("Retrieving Mempool Updates over Network", "Adding Updates to Blockchain");
%lgd.Location = 'northwest';

xlabel("Mempool size, txns");
ylabel("Number of Updates");

l = legend("Retrieving mempool updates over network","Adding updates to Blockchain","Updates pulled in each Leader poll");
l.Location = 'northwest';