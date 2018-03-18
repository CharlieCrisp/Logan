function [data] = remove_outliers(data,means,upper_bounds,lower_bounds)
%REMOVE_OUTLIERS Summary of this function goes here
%   Detailed explanation goes here
last_rate = 0;
result_index = 0;
rows_to_keep = true([1 length(data)]);
first = false;
for i = 1:size(data,1)-2
    current_rate = data(i,3);
    if last_rate ~= current_rate
        result_index = result_index + 1;
        last_rate = current_rate;
        first = true;
    end
    t_s1 = data(i, 1);
    t_e1 = data(i, 2);
    latency= t_e1 - t_s1;
    upper = means(result_index) + 1.5 * upper_bounds(result_index);
    lower = means(result_index) - 1.5 * lower_bounds(result_index);
    if latency > upper || latency < lower
        rows_to_keep(i) = false;
    end
    if first
        first = false;
    end
end
data = data(rows_to_keep,:);
end

