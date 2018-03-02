format long;
data = importdata("../../../output.log");
%filter NaN rows
data(any(isnan(data), 2), :) = [];
data = flipud(data);
latency_data = zeros(1, bins);
throughput_data = zeros(1, bins);

length = size(data,1);
bins = 10;
binsize = floor(length/bins);

for i = 1:bins
    total_latency = 0;
    start_time = data(i * binsize, 1);
    end_index = (i+1)*binsize;
    if (end_index > length)
        end_index = length;
    end
    end_time = data(end_index, 1);
    throughput = binsize / (end_time - start_time);
    for j = 1:binsize
       index = (i-1) * binsize + j;
       latency = data(index,2) - data(index,1); 
       total_latency = total_latency + latency;
    end
    throughput_data(i) = throughput;
    latency_data(i) = total_latency;
end

plot(throughput_data, latency_data);
