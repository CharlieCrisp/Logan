clear
format long;
data_azure = importdata("~/Documents/PartIILogs/ezirmin_latency.log", ' ');
data_charlie = importdata("~/Documents/PartIILogs/ezirmin_latency_charlie.log", ' ');
xs_azure = (1:length(data_azure)) * 20;
xs_charlie = (1:length(data_charlie)) * 20;

cum_data_azure = cumsum(data_azure);
cum_data_charlie = cumsum(data_charlie);

%plot
figure
plot(xs_azure, data_azure);
xlabel("Blockchain Size, transactions");
ylabel("Latency, ms");
hold on
plot(xs_charlie, data_charlie);

figure 
plot(xs_azure, cum_data_azure, xs_charlie, cum_data_charlie);
xlabel("Blockchain Size, transactions");
ylabel("Cumulative Latency, ms");