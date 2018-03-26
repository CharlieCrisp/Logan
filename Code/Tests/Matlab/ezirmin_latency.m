clear
format long;
data_azure = importdata("~/Documents/PartIILogs/ezirmin_latency_azure.log", ' ');
data_anil = importdata("~/Documents/PartIILogs/ezirmin_latency_anil.log", ' ');
data_charlie = importdata("~/Documents/PartIILogs/ezirmin_latency_charlie.log", ' ');
xs = (1:length(data_azure)) * 20;

cum_data_azure = cumsum(data_azure);
cum_data_anil = cumsum(data_anil);
cum_data_charlie = cumsum(data_charlie);

%plot
figure
plot(xs, data_azure, xs, data_anil, xs, data_charlie);
xlabel("Blockchain Size, transactions");
ylabel("Latency, ms");
legend("Machine 1","Machine 2", "Machine 3");

figure 
plot(xs, cum_data_azure, xs, cum_data_anil, xs, cum_data_charlie);
xlabel("Blockchain Size, transactions");
ylabel("Cumulative Latency, ms");
legend("Machine 1","Machine 2", "Machine 3");