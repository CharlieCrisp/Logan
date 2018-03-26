format long;
data = importdata("../../../../../PartIILogs/single_local_worker_no_delay.log", ' ');
%filter NaN rows
data(any(isnan(data), 2), :) = [];
data = flipud(data);
rates = unique(data(:,3))+5;
result_length = size(rates,1);

[latency_means, throughput_data] = get_data_means(data, result_length);

[latency_deviation_pos, latency_deviation_neg] = get_data_std(data, latency_means, result_length);

data = remove_outliers(data, latency_means, latency_deviation_neg, latency_deviation_pos, result_length);

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

latencies = latencies(throughputs ~= 0);
throughputs = throughputs(throughputs ~= 0);

scatter(throughputs,latencies);
hold on
X = [ones(result_length-4,1) (throughput_data(1:end-4)')];
size(ones(1,result_length-4))
size(latency_means(1:end-4))
p = polyfit(ones(1,result_length-4),latency_means(1:end-4),7);
x1 = linspace(0,4*pi);
y1 = polyval(p,x1);
plot(x1,y1)
hold off

xlabel({"Throughput";"transactions s^{-1}";""});
ylabel({"Latency";"s"});