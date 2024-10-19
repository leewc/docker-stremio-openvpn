#! /bin/bash

. /etc/stremio/environment-variables.sh
source /etc/openvpn/utils.sh

# If transmission-pre-stop.sh exists, run it
# if [[ -x /scripts/transmission-pre-stop.sh ]]
# then
#     echo "Executing /scripts/transmission-pre-stop.sh"
#     /scripts/transmission-pre-stop.sh "$@"
#     echo "/scripts/transmission-pre-stop.sh returned $?"
# fi

echo "Sending kill signal to stremio server [$(pidof node)]"
PID=$(pidof node) #todofix 
kill "$PID"

echo "Sending kill signal to stremio frontend [$(pidof python3)]"
kill $(pidof python3) #or http-server

# Give stremio some time to shut down
STREMIO_TIMEOUT_SEC=${STREMIO_TIMEOUT_SEC:5}
for i in $(seq "$STREMIO_TIMEOUT_SEC")
do
    sleep 1
    [[ -z "$(pidof node)" ]] && break
    [[ $i == 1 ]] && echo "Waiting ${STREMIO_TIMEOUT_SEC}s for stremio server to die"
done

# Check whether stremio is still running
if [[ -z "$(pidof node)" ]]
then
    echo "Successfuly closed stremio"
else
    echo "Sending kill signal (SIGKILL) to stremio"
    kill -9 "$PID"
fi

# # If transmission-post-stop.sh exists, run it
# if [[ -x /scripts/transmission-post-stop.sh ]]
# then
#     echo "Executing /scripts/transmission-post-stop.sh"
#     /scripts/transmission-post-stop.sh "$@"
#     echo "/scripts/transmission-post-stop.sh returned $?"
# fi