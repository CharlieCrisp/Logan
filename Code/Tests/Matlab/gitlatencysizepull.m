% compare git latencies for different size pulls 
figure
data_git = importdata('~/Documents/PartIILogs/git_pulls_different_size_pull.log', ' ');
data_ezirmin = importdata('~/Documents/PartIILogs/ezirmin_pulls_different_size_pulls.log', ' ');
plot((0:length(data_git)-1 )* 100, data_git, (0:length(data_ezirmin)-1)* 100, data_ezirmin);
lgd = legend("Git Pull", "Ezirmin Pull");
lgd.Location = 'northwest';
xlabel("Number of transactions pulled");
ylabel("Latency, s");