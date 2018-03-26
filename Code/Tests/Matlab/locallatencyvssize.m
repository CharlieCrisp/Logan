clear
format long;
data = importdata("../../../../Documents/PartIILogs/single_local_worker_validated.log", ' ');
data_unvalidated = importdata("../../../../Documents/PartIILogs/local_latency_blockchain_size.log", ' ');

%filter NaN rows
data(any(isnan(data), 2), :) = [];
data = flipud(data);
data_unvalidated(any(isnan(data_unvalidated), 2), :) = [];
data_unvalidated = flipud(data_unvalidated);

%calculate latencies
result = data(:,2) - data(:,1);
result = result * 1000;
result_unvalidated = data_unvalidated(:,2) - data_unvalidated(:,1);
result_unvalidated = result_unvalidated * 1000;

%Remove outliers
% mean = mean(result);
% std = std(result);
% above = result > (mean + 1.5 * std);
% below = result < (mean - 1.5 * std);
% keep = and(not(above), not(below));
% result = result(keep);

%calculate average of every n items
n = 50;
s1 = size(result, 1);
M  = s1 - mod(s1, n);
y  = reshape(result(1:M), n, []);
result = transpose(sum(y, 1) / n);

s1_u = size(result_unvalidated,1);
M_u = s1_u - mod(s1_u,n);
y_u = reshape(result_unvalidated(1:M_u), n, []);
result_unvalidated = transpose(sum(y_u, 1) / n);

%plot
transactions = n*(1:length(result));
transactions_u = n*(1:length(result_unvalidated));
plot(transactions, result, transactions_u, result_unvalidated);
ylim([0 100]);
xlim([0 4500]);
xlabel("Blockchain Size, transactions");
ylabel("Latency, ms");
legend("With validation","Without validation");
