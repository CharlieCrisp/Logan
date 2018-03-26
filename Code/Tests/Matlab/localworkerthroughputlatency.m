format long;
data = importdata("~/Documents/PartIILogs/single_local_worker_anil_3.log", ' ');
%filter NaN rows
data(any(isnan(data), 2), :) = [];
data = flipud(data);
rates = unique(data(:,3));
result_length = size(rates,1);

[latency_means, throughput_data] = get_data_means(data, result_length);

[latency_deviation_pos, latency_deviation_neg] = get_data_std(data, latency_means, result_length);

data = remove_outliers(data, latency_means, latency_deviation_neg, latency_deviation_pos, result_length);

[latency_means, throughput_data] = get_data_means(data, result_length);

[latency_deviation_pos, latency_deviation_neg] = get_data_std(data, latency_means, result_length);

scale = 1000;
latency_means = latency_means * scale;

figure
%e = errorbar(throughput_data, latency_means, latency_deviation_neg, latency_deviation_pos, 'x');
e = plot(throughput_data, latency_means,'x');
%e.LineStyle = "none";
ylim([0 50]);
xlabel("Throughput, txs/s");
ylabel("Latency, ms");

overload_transition = 10; %10 last readings are when system is overloaded

P = polyfit(throughput_data(1:end-overload_transition),latency_means(1:end-overload_transition),1);
yfit = P(1)*throughput_data(1:end-overload_transition)+P(2);
hold on;
lms1 = plot(throughput_data(1:end-overload_transition),yfit);
legend(lms1,"Before system is overloaded");
 
% P = polyfit(throughput_data(end-overload_transition:end),latency_means(end-overload_transition:end),1);
% yfit = P(1)*throughput_data(end-overload_transition:end)+P(2);
% lms2 = plot(throughput_data(end-overload_transition:end),yfit);
% legend([lms1 lms2],{"Before system is overloaded", "After system is overloaded"});
