read -p "Enter your destination username: " username
read -p "Enter your destination ip: " ip
LOCATION="ssh://$username@$ip/tmp/ezirminl/lead/mempool"
git clone $LOCATION /tmp/ezirminl/part/mempool