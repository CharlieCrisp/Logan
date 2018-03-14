filename = '../git_pull_latency.txt';
delimiterIn = ' ';
headerlinesIn = 1;
A = importdata(filename,delimiterIn,headerlinesIn);
plot(A.data(:,1),A.data(:,2), A.data(:,1), A.data(:,3))