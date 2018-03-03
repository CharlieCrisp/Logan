format long;
data = importdata("../../../output.log");
%filter NaN rows
data(any(isnan(data), 2), :) = [];
data = flipud(data);
latency_data = zeros(1, bins);
throughput_data = zeros(1, bins);

length = size(data,1);
bins = 30;
binsize = floor(length/bins);

for i = 1:bins
    start_index = i * binsize;
    end_index = (i+1)*binsize;
    if (end_index > length)
        end_index = length;
    end
    this_bin_size = end_index - start_index;
    start_time = data(i * binsize, 1);
    end_time = data(end_index, 1);
    
    total_latency = 0;
    throughput = this_bin_size / (end_time - start_time);
   
    for j = 1:binsize
       index = (i-1) * binsize + j;
       latency = data(index,2) - data(index,1); 
       total_latency = total_latency + latency;
    end
    throughput_data(i) = throughput;
    latency_data(i) = total_latency/this_bin_size;
end

scatter(throughput_data, latency_data, "filled");
xlabel({"Throughput";"transactions s^{-1}";""});
ylabel({"Latency";"s"});