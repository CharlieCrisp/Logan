function [latency_means, throughput_data] = get_data_means(data,result_length)
%GET_DATA_MEANS Summary of this function goes here
%   Detailed explanation goes here
latency_means = zeros(1, result_length);
throughput_data = zeros(1, result_length);
data_size = zeros(1, result_length);
last_rate = 0;
result_index = 0;
%Calculate the mean values of the sets of data which are marked with the
%same throughput rate
for i = 1:size(data,1)-2
    current_rate = data(i,3);
    if last_rate ~= current_rate
        result_index = result_index + 1;
        last_rate = current_rate;
    end
    t_s1 = data(i, 1);
    t_e1 = data(i, 2);
    t_s2 = data(i + 1, 1);
    %data is currently cumulative
    throughput = (1 / (t_s2 - t_s1));
    latency = t_e1 - t_s1;
    
    data_size(result_index) = data_size(result_index) + 1;
    throughput_data(result_index) = throughput_data(result_index) + throughput;
    latency_means(result_index) = latency_means(result_index) + latency;
end
throughput_data = throughput_data ./ data_size;
latency_means = latency_means ./ data_size;
end

