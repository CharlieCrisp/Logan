USER=$1
HOST=$2 
if [ -z "$USER" ] || [ -z "$HOST" ] ;
then
echo "Please give me something to sync from, in the form user host" 
else
LOCATION="$USER@$HOST:/$USER/PartIIProject/output.log"
scp $LOCATION .
fi