#Peter Kowalsky - 23.06.2018
#HP Power Supply, Temperature and Fan Monitoring (hpasmcli) -> InfluxDB
#/bin/bash

HOSTNAME=$(hostname)
INFLUX_DB_LOC="http://localhost:8086/write?db=opentsdb"
CURL_ARGS="-i -XPOST"

declare -a P_STATUS
declare -a P_DRAW
declare -a F_SPEED
declare -a F_R_STATUS
declare -a T_ARR

#POWER SUPPLY STATUS -> Output to -
function getPowerStatus () {
	P_STATUS_RAW=$(/sbin/hpasmcli -s "show powersupply" | sed -n '1!p')
	i=0
	while IFS= read -r line
	do
		echo $line | grep Condition | cut -d':' -f 2
		i=$((i+1))
	done <<< "$P_STATUS_RAW"
}

#POWER SUPPLY DRAW -> OUTPUT to -
function getPowerDraw () {
        P_STATUS_RAW=$(/sbin/hpasmcli -s "show powersupply" | sed -n '1!p')
        i=0
        while IFS= read -r line
        do
                echo $line | grep Power | cut -d' ' -f3
                i=$((i+1))
        done <<< "$P_STATUS_RAW"
}

# get and prepare fan data
F_S_RAW=$(/sbin/hpasmcli -s "show fans" | sed -n '1!p')
i=2
while [ -n "$(echo $F_S_RAW | cut -d'#' -f$i)" ]
do
	line=$(echo $F_S_RAW | cut -d'#' -f$i)
	F_SPEED[$((i-1))]=$(echo $line | cut -d' ' -f5 | cut -d'%' -f1)
	if [[ $(echo $line | cut -d' ' -f6) = "Yes" ]]
	then
		F_R_STATUS[$((i-1))]="1"
	else
		F_R_STATUS[$((i-1))]="0"
	fi
	i=$((i+1))
done

# get data
RAW_DRAW=$(getPowerDraw)
RAW_COND=$(getPowerStatus)

# prepare data for influx and send it
i=0
while IFS= read -r line
do
	P_STATUS[$i]=$line
        i=$((i+1))
done <<< "$RAW_COND"

i=0
i2=0
while IFS= read -r line
do
	if [ $((i%2)) -eq 1 ]
	then
		i2=$((i2+1))
		P_DRAW[$i2]=$line
        fi
	i=$((i+1))
done <<< "$RAW_DRAW"

i=0
for s in "${P_STATUS[@]}"
do
	i=$((i+1))
	tag="supply-$i"
	if [[ $s = *"Ok"* ]]
	then
		curl $CURL_ARGS $INFLUX_DB_LOC --data-binary "hpasmcli.status,host=$HOSTNAME,supply=$tag value=1"
	else
		curl $CURL_ARGS $INFLUX_DB_LOC --data-binary "hpasmcli.status,host=$HOSTNAME,supply=$tag value=0"
	fi
done

i=0
for s in "${P_DRAW[@]}"
do
	if [ -n "$s" ]; then
		i=$((i+1))
        	tag="supply-$i"
		curl $CURL_ARGS $INFLUX_DB_LOC --data-binary "hpasmcli.draw,host=$HOSTNAME,supply=$tag value=$s"
	fi
done

i=0
for s in "${F_SPEED[@]}"
do
        if [ -n "$s" ]; then
                i=$((i+1))
                tag="fan-$i"
                curl $CURL_ARGS $INFLUX_DB_LOC --data-binary "hpasmcli.fan.speed,host=$HOSTNAME,fan=$tag value=$s"
        fi
done

i=0
for s in "${F_R_STATUS[@]}"
do
        if [ -n "$s" ]; then
                i=$((i+1))
                tag="fan-$i"
                curl $CURL_ARGS $INFLUX_DB_LOC --data-binary "hpasmcli.fan.redundant,host=$HOSTNAME,fan=$tag value=$s"
        fi
done

# get and prepare temp data
T_RAW=$(/sbin/hpasmcli -s "show temp" | sed -n '1!p')
i2=1
i=2
while [ -n "$(echo $T_RAW | cut -d'#' -f$i)" ]
do
        line=$(echo $T_RAW | cut -d'#' -f$i)
        if [[ $(echo $line | cut -d' ' -f3 | cut -d'C' -f1) != "-" ]]
        then
		T_ARR[$i]=$((i-1))-$(echo $line | cut -d' ' -f2 ),$(echo $line | cut -d' ' -f3 | cut -d'C' -f1)
        	i2=$((i2+1))
	fi
	i=$((i+1))
done

# send temp data
i=0
for s in "${T_ARR[@]}"
do
        if [ -n "$s" ]; then
                tag=$(echo $s | cut -d',' -f1)
                curl $CURL_ARGS $INFLUX_DB_LOC --data-binary "hpasmcli.temp,host=$HOSTNAME,sensor=$tag value=$(echo $s | cut -d',' -f2)"
        fi
done
