pid=`ps -f | grep "TrEMOLO/lib/bash/load.sh" | awk '$8=="bash" {print $2}'`
#echo "PID=${pid}"
if [ -n "${pid}" ]; then
    kill -s 2 ${pid} 
    kill -s 15 ${pid}
fi;
