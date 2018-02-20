read -p "Enter your destination username: " username
read -p "Enter your destination ip: " ip
LOCATION="ssh://$username@$ip/tmp/ezirminl/lead/mempool"
git clone --bare $LOCATION /tmp/ezirminl/part/mempool