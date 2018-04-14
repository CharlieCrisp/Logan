data = importdata("~/Documents/PartIILogs/Throughput Throughput Logs/appliedvsobserved2r", ' ', 1);
data = data.data;
applied = data(:,1);
observed = data(:,2);

hold on
%plot single remote
scatter(applied,observed,'x');

%plot reference line
ref = 0:1:100;
plot(ref,ref);
hold off

xlabel("Applied Throughput, tps");
ylabel("Observed Throughput, tps");
