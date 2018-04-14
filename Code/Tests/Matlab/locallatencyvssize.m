clear
format long;
data = importdata("../../../../Documents/PartIILogs/single_local_worker_new.log", ' ');
% data_unvalidated = importdata("../../../../Documents/PartIILogs/local_latency_blockchain_size.log", ' ');

%filter NaN rows
data(any(isnan(data), 2), :) = [];
data = flipud(data);

%calculate latencies
result = data(:,2) - data(:,1);
result = result * 1000;

transactions = 1:length(result);
outliers = result < 50;
result = result(outliers)';
transactions = transactions(outliers);

gap = 20;
result = result(1:gap:end);
transactions = transactions(1:gap:end);

%plot
plot(transactions, result);
ylim([0 100]);
xlim([0 5000]);
xlabel("Blockchain Size, txns");
ylabel("Latency, ms");
%legend("With validation","Without validation");
