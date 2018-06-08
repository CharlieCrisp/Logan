format long
confirmation_times = importdata("~/Documents/PartIILogs/Replication/confirmationtimes.log", ' ');
confirmation_times2 = importdata("~/Documents/PartIILogs/Replication/confirmationtimes2.log", ' ');
hold on
gap = 50;
plot(1:gap:length(confirmation_times),confirmation_times(1:gap:end), "-x");
plot(1:gap:length(confirmation_times2),confirmation_times2(1:gap:end), "-o");
xlabel("Blockchain size (transactions)");
ylabel("Time to push to Replica (seconds)");
legend(["One Replica", "Two Replicas"]);
xlim([0 5000]);
ylim([0 10]);
set(gca,'fontsize',14);

h = figure(1);
set(h,'Units','Inches');
pos = get(h,'Position');
set(h,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3), pos(4)])
print(h,'~/Documents/CompSci/PartIIDissertation/figs/confirmationlatencies.pdf','-dpdf','-r0')