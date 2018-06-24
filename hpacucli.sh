#Peter Kowalsky - 23.06.2018
#HP RAID Monitoring (hpacucli) -> InfluxDB
#Usage : ./hpacucli.sh RAID_CONTROLLER_NUMBER -> ./hpacucli.sh 0
#/bin/bash

HOSTNAME=$(hostname)
INFLUX_DB_LOC="http://localhost:8086/write?db=opentsdb"
CURL_ARGS="-i -XPOST"
HPACUCLI="/usr/sbin/hpacucli"

declare -a DRIVE_STATUS
declare -a DRIVE_PORT

#$1 RAID Card Slot -> Output to DRIVE_STATUS
function getDriveStatus () {
	GET_ALL_DRIVES="$HPACUCLI ctrl slot=$1 pd all show status"
	DRIVE_STATUS_RAW=$($GET_ALL_DRIVES | sed -n '1!p')
	i=0
	while IFS= read -r line
	do
		DRIVE_STATUS[$i]=$(echo $line | cut -d' ' -f 9)
		DRIVE_PORT[$i]=$(echo $line | cut -d' ' -f 2)
		i=$((i+1))
	done <<< "$DRIVE_STATUS_RAW"
}

getDriveStatus $1

i=0
for s in "${DRIVE_STATUS[@]}"
do
	if [ "$s" = "OK" ]
	then
		curl $CURL_ARGS $INFLUX_DB_LOC --data-binary "hpacucli,host=$HOSTNAME,drive=${DRIVE_PORT[$i]} value=1"
	else
		curl $CURL_ARGS $INFLUX_DB_LOC --data-binary "hpacucli,host=$HOSTNAME,drive=${DRIVE_PORT[$i]} value=0"
	fi
	i=$((i+1))
done
