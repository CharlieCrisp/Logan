format long;
data = importdata("~/Documents/PartIILogs/remote_worker_throughput_latency3.log", ' ');
data2 = importdata("~/Documents/PartIILogs/output.log", ' ');
%filter NaN rows
rates = unique(data(:,3));
result_length = size(rates,1);
rates2 = unique(data2(:,3));
result_length2 = size(rates2,1);

[latency_means, throughput_data] = get_alternate_data_means(data, result_length);
[latency_deviation_pos, latency_deviation_neg] = get_data_std(data, latency_means, result_length);
data = remove_outliers(data, latency_means, latency_deviation_neg, latency_deviation_pos, result_length);
[latency_means, throughput_data] = get_alternate_data_means(data, result_length);
[latency_deviation_pos, latency_deviation_neg] = get_data_std(data, latency_means, result_length);

[latency_means2, throughput_data2] = get_alternate_data_means(data2, result_length2);

figure
hold on
plot(throughput_data, latency_means,'x');
plot(throughput_data2, latency_means2, 'o');
xlabel("Throughput, txs/s");
ylabel("Latency, s");

overload_transition = 10; %10 last readings are when system is overloaded

P = polyfit(throughput_data(1:end-overload_transition),latency_means(1:end-overload_transition),2);
yfit = P(1)*(throughput_data(1:end-overload_transition).^2)+ P(2)*throughput_data(1:end-overload_transition)+P(3);
hold on;
lms1 = plot(throughput_data(1:end-overload_transition),yfit);
 
% P = polyfit(throughput_data(end-overload_transition:end),latency_means(end-overload_transition:end),1);
% yfit = P(1)*throughput_data(end-overload_transition:end)+P(2);
% lms2 = plot(throughput_data(end-overload_transition:end),yfit);
% legend([lms1 lms2],{"Before system is overloaded", "After system is overloaded"});
