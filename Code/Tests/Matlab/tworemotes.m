format long;
data = importdata("~/Documents/PartIILogs/PureGit/throughputlatency1.log", ' ');
data2 = importdata("~/Documents/PartIILogs/PureGit/throughputlatency2.log", ' ');
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

blue = [0 0.4470 0.7410];
red = [0.8500 0.3250 0.0980];

figure
hold on
p1 = plot(throughput_data, latency_means,'x');
p1.Color = blue;
p2 = plot(throughput_data2, latency_means2, 'o');
p2.Color = red;
xlabel("Throughput, txs/s");
ylabel("Latency, s");
ylim([0 30]);

[throughput_data, I] = sort(throughput_data);
latency_means = latency_means(I);

[throughput_data2, I] = sort(throughput_data2);
latency_means2 = latency_means2(I);


P = polyfit(throughput_data, latency_means, 2);
yfit = P(1) * (throughput_data .^ 2)+ P(2) * throughput_data + P(3);
lms1 = plot(throughput_data, yfit);
lms1.Color = blue;

P2 = polyfit(throughput_data2, latency_means2, 2);
yfit2 = P2(1) * (throughput_data2 .^ 2) + P2(2) * throughput_data2 + P2(3);
lms2 = plot(throughput_data2, yfit2);
lms2.Color = red;


l = legend([p1 p2],[ "One remote Participant and one local Participant" "One remote Participant"]);
l.Location = 'northwest';
hold off