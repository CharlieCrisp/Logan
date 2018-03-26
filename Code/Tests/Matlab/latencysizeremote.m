clear
format long;
data = importdata("~/Documents/PartIILogs/remote_worker_latency_size2.log", ' ');
%filter NaN rows
data(any(isnan(data), 2), :) = [];
git_bad_latency = [1.441 1.637 1.644 1.706 1.751];
irmin_git_bad_latency = [2.497 3.727 4.619 5.581 6.437];
git_sizes = [ 0 1000 2000 3000 4000];

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
ylim([0 15.0]);
hold on
plot(git_sizes, irmin_git_bad_latency);
legend('Logan transaction latency','Irmin Pull Latency')
%least mean squares plot
% X = [ones(length(result),1) (transactions')];
% size(X)
% size(result)
% b = X \ (result);
% ycalc = X * b;
% hold on
% plot(transactions, ycalc);
hold off
figure
irmin_add_bad = [5.161 5.585 10.438 15.439 18.00];
irmin_sizes = [ 0 1000 2000 3000 4000];
plot(irmin_sizes, irmin_add_bad);
