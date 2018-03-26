clear
format long;
data = importdata("~/Documents/PartIILogs/remote_worker_latency_size2.log", ' ');
%filter NaN rows
data(any(isnan(data), 2), :) = [];


%calculate latencies
result = data(:,2) - data(:,1);

%Remove outliers
mean = mean(result);
std = std(result);
above = result > (mean + 1.5 * std);
below = result < (mean - 1.5 * std);
keep = and(not(above), not(below));
result = result(keep);

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
ylim([1.5 15.0]);

%least mean squares plot
% X = [ones(length(result),1) (transactions')];
% size(X)
% size(result)
% b = X \ (result);
% ycalc = X * b;
% hold on
% plot(transactions, ycalc);