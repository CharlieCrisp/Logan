format long;
data = importdata("../../../output.log", ' ');
%filter NaN rows
data(any(isnan(data), 2), :) = [];
data = flipud(data);
rates = unique(data(:,3));
result_length = size(rates,1);

[latency_means, throughput_data] = get_data_means(data, result_length);

[latency_deviation_pos, latency_deviation_neg] = get_data_std(data, latency_means, result_length);

data = remove_outliers(data, latency_means, latency_deviation_neg, latency_deviation_pos);

[latency_means, throughput_data] = get_data_means(data, result_length);

[latency_deviation_pos, latency_deviation_neg] = get_data_std(data, latency_means, result_length);

figure
e = errorbar(throughput_data, latency_means, latency_deviation_neg, latency_deviation_pos, 'x');
e.LineStyle = "none";

X = [ones(result_length,1) (throughput_data')];
b = X \ (latency_means');
ycalc = X * b;
hold on
clear plot
plot(throughput_data, ycalc);
xlabel({"Throughput";"transactions s^{-1}";""});
ylabel({"Latency";"s"});
