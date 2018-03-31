clear
format long;
data = importdata("../../../../Documents/PartIILogs/PureGit/multiple_throughput_irmin_git.log", ' ');

len = length(unique(data(:,3)));
[thing, throughput_data] = get_data_means(data,len);

latencies = ones(len, 5000);
row = 0;
last_rate = -1;
column = 1;
for i=1:length(data)
    rate = data(i,3);
    if rate ~= last_rate
        column = 1;
        row = row + 1;
        latencies(row, column) = (data(i,2) - data(i,1));
        last_rate = rate;
        column = column + 1;
    else 
        if column <= 5000
            latencies(row, column) = (data(i,2) - data(i,1));
            column = column + 1;
        end
    end
end
n = 70;
figure
hold on
for i = 1:len
    lat = latencies(i,:)';
    s1 = size(lat, 1);
    M  = s1 - mod(s1, n);
    y  = reshape(lat(1:M), n, []);
    lat = transpose(sum(y, 1) / n);
    
    sizes = (1:length(lat)) * n;
    plot(sizes, lat);
end
hold off

txt = cell(len,1);
for i = 1:len
   txt{i}= sprintf('Throughput: %2.0f', throughput_data(i));
end
legend(txt, "Location", 'northwest')

xlabel("Blockchain size");
ylim([0 160]);
yticks(0:20:160);
ylabel("Latency");
grid on
