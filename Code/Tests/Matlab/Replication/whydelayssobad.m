data = importdata("~/Documents/PartIILogs/Replication/delays.log", ' ');

important = [1 2 9];
figure 
hold on
for i = important
    plotdata = data(:,i+1) - data(:,i);
    plot(1:length(plotdata),plotdata);
end
hold off
leg = int2str(important');
xlabel("Mempool size, txns");
ylabel("Number of Updates");
legend(leg);

figure
important = 1:(length(data(1,:))-1);
hold on
for i = important
    plotdata = data(:,i+1) - data(:,i);
    plot(1:length(plotdata),plotdata);
end
hold off
leg = int2str(important');
xlabel("Mempool size, txns");
ylabel("Number of Updates");
legend(leg);