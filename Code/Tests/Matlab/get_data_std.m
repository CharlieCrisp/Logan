function [latency_deviation_pos,latency_deviation_neg] = get_data_std(data, latency_means, result_length)
%GET_DATA_STD Summary of this function goes here
%   Detailed explanation goes here

%divide cumulative data to get averate
latency_deviation_pos = zeros(1, result_length);
latency_deviation_neg = zeros(1, result_length);
latency_pos_size = ones(1,result_length);
latency_neg_size = ones(1,result_length);

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
    
    if latency >= latency_means(result_index)
        latency_deviation_pos(result_index) = latency_deviation_pos(result_index) + ... 
            (latency - latency_means(result_index))^2;
        latency_pos_size(result_index) = latency_pos_size(result_index) + 1;
    else
        latency_deviation_neg(result_index) = latency_deviation_neg(result_index) + ... 
            (latency - latency_means(result_index))^2;
        latency_neg_size(result_index) = latency_neg_size(result_index) + 1;
    end
end
latency_deviation_pos = sqrt(latency_deviation_pos ./ (latency_pos_size - 1));
latency_deviation_neg = sqrt(latency_deviation_neg ./ (latency_neg_size - 1));
end

