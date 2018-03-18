format long;
data = importdata("../../../single_local_worker_1s_delay.log");

[tp, lat_mean, lat_dev] = get_processed_data(data);

blue = [0, 0.4470, 0.7410];

figure
e = errorbar(tp, lat_mean, lat_dev, 'Color', blue);
e.LineStyle = "none";
e.Marker = 'x';

X = [ones(result_length,1) (tp')];
b = X \ (lat_mean');
ycalc = X * b;
hold on
pl = plot(tp, ycalc, 'Color', blue);
legend('Location', 'northwest');
legend([e;pl], 'Data for rtt = 2.2ms', 'Linear regression fit for rtt=2.2ms');

xlabel({"Throughput";"transactions s^{-1}";""});
ylabel({"Latency";"s"});
