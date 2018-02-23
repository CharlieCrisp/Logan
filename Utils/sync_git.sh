DESTINATION=$1
if [ -z "$DESTINATION" ]
then
echo "Please give me something to sync from, in the form user@host" 
else
LOCATION="ssh://$DESTINATION/tmp/ezirminl/lead/mempool"
git clone $LOCATION /tmp/ezirminl/part/mempool
cd /tmp/ezirminl/part/mempool
git checkout -b internal origin/internal
git checkout master
cd -
fi