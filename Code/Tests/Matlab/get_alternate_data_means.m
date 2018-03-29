function [latency_means, throughput_data] = get_data_means(data,result_length)
%GET_DATA_MEANS Summary of this function goes here
%   Detailed explanation goes here
latency_means = zeros(1, result_length);
throughput_data = zeros(1, result_length);
data_size = zeros(1, result_length);
last_rate = data(1,3);
result_index = 1;
%Calculate the mean values of the sets of data which are marked with the
%same throughput rate
first_time = data(1,1);
for i = 1:size(data,1)-1
    t_s1 = data(i, 1);
    t_e1 = data(i, 2);
    %data is currently cumulative
    latency = t_e1 - t_s1;
    
    current_rate = data(i,3);
    if last_rate ~= current_rate
        last_rate = current_rate;
        throughput = 1 / (data(i-1,1) - first_time)
        first_time
        first_time = t_s1;
        data(i-2,1)
        if (result_index <= result_length)
            throughput_data(result_index) = throughput;
        end
        result_index = result_index + 1;
    end
    if (result_index > result_length) 
        break
    end
    data_size(result_index) = data_size(result_index) + 1;
    latency_means(result_index) = latency_means(result_index) + latency;
end
%account for last throughput
throughput_data(end) = 1/(data(end,1) - first_time);

throughput_data = throughput_data .* data_size;
latency_means = latency_means ./ data_size;
end