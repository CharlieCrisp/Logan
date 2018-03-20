format long;
data = importdata("../../../output.log", ' ');
%filter NaN rows
data(any(isnan(data), 2), :) = [];
data = flipud(data);

latencies = zeros(1, length(data));
throughputs = zeros(1, length(data));
for i = 1:size(data,1)-2
    t_s1 = data(i, 1);
    t_e1 = data(i, 2);
    t_s2 = data(i + 1, 1);
    %data is currently cumulative
    throughput = abs(1 / (t_s2 - t_s1));
    latency = t_e1 - t_s1;
    if throughput < 20
        throughputs(i) = throughputs(i) + throughput;
        latencies(i) = latencies(i) + latency;
    else
        throughputs(i) = [];
        latencies(i) = [];
    end
end

scatter(throughputs,latencies);