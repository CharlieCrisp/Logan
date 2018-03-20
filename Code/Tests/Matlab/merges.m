format long;
data = importdata("../../../output.log", ' ');
%filter NaN rows
data(any(isnan(data), 2), :) = [];
first_time = data(1,1);
time = data(:,1) - first_time;
latencies = diff(data,1,2);
plot(time, latencies);
xlabel("Time elapsed, s");
ylabel("Mempool update latency, s");
title("Merge latencies in Ezirmin");