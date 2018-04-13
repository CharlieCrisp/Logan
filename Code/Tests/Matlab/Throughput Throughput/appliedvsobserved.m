data = importdata("~/Documents/PartIILogs/Throughput Throughput Logs/appliedvsobserved", ' ', 1);
data = data.data;
applied = data(:,1);
observed = data(:,2);

data = importdata("~/Documents/PartIILogs/Throughput Throughput Logs/appliedvsobserved1l1r", ' ', 1);
data = data.data;
applied_with_local = data(:,1);
observed_with_local = data(:,2);

hold on
%plot single remote
scatter(applied,observed,'x');

%plot single remote and single local
%scatter(applied_with_local, observed_with_local,'o');

%plot reference line
ref = 1:1:30;
plot(ref,ref);

xlabel("Applied Throughput");
ylabel("Observed Throughput");
%l = legend("Without Participant on Leader Machine", "With Participant on Leader Machine");
