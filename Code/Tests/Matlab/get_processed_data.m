function [throughput_data,latency_means, latency_deviation] = get_processed_data(data)
%GET_PROCESSED_DATA Get Throughput and Latency Data from output log
data(any(isnan(data), 2), :) = [];
data = flipud(data);
rates = unique(data(:,3));
result_length = size(rates,1);

latency_means = zeros(1, result_length);
latency_deviation = zeros(1, result_length);
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
    data_size(result_index) = data_size(result_index) + 1;
    %data is currently cumulative
    throughput_data(result_index) = throughput_data(result_index) + (1 / (t_s2 - t_s1));
    latency_means(result_index) = latency_means(result_index) + t_e1 - t_s1;
end

%divide cumulative data to get averate
throughput_data = throughput_data ./ data_size;
latency_means = latency_means ./ data_size;

last_rate = 0;
result_index = 0;
%Calculate the standard deviation values 
for i = 1:size(data,1)-2
    current_rate = data(i,3);
    if last_rate ~= current_rate
        result_index = result_index + 1;
        last_rate = current_rate;
    end
    t_s1 = data(i, 1);
    t_e1 = data(i, 2);
    latency= t_e1 - t_s1;
    %data is currently cumulative
    latency_deviation(result_index) = latency_deviation(result_index) + ... 
        (latency - latency_means(result_index))^2;
end

latency_deviation = sqrt(latency_deviation ./ (data_size - 1));
end

