format long;
data = importdata("../../../../../PartIILogs/single_local_worker_no_delay.log", ' ');
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
    if throughput < 20 && latency < 0.1
        throughputs(i) = throughput;
        latencies(i) = latency;
    end
end

latencies = latencies(throughputs ~= 0)
throughputs = throughputs(throughputs ~= 0)

scatter(throughputs,latencies);