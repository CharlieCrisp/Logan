data = importdata("~/Documents/PartIILogs/Throughput Throughput Logs/appliedvsobserved1r", ' ', 1);
data = data.data;
applied = data(:,1);
observed = data(:,2);

hold on
%plot single remote
scatter(applied,observed,'x');

%plot single remote and single local
%scatter(applied_with_local, observed_with_local,'o');

%plot reference line
ref = 0:1:70;
plot(ref,ref);
hold off

xlabel("Applied Throughput, tps");
ylabel("Observed Throughput, tps");
%l = legend("Without Participant on Leader Machine", "With Participant on Leader Machine");
