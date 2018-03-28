clear
format long;
data = importdata("../../../../Documents/PartIILogs/remote_worker_sequential_latencies.log", ' ');

%filter NaN rows
data(any(isnan(data), 2), :) = [];
%calculate latencies
result = data(:,2) - data(:,1);

%calculate average of every n items
n = 50;
s1 = size(result, 1);
M  = s1 - mod(s1, n);
y  = reshape(result(1:M), n, []);
result = transpose(sum(y, 1) / n);


%plot
transactions = n*(1:length(result));
plot(transactions, result);
xlabel("Blockchain Size, transactions");
ylabel("Latency, s");
