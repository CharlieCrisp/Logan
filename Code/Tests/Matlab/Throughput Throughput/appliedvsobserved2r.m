data = importdata("~/Documents/PartIILogs/Throughput Throughput Logs/appliedvsobserved2r", ' ', 1);
data = data.data;
applied = data(:,1);
observed = data(:,2);

hold on
%plot single remote
scatter(applied,observed,'x');

%plot reference line
ref = 1:1:30;
plot(ref,ref);

xlabel("Applied Throughput");
ylabel("Observed Throughput");
