pid=`ps -f | grep "TrEMOLO/pipeline/lib/bash/load.sh" | awk '$8=="bash" {print $2}'`
#echo "PID=${pid}"
kill -s 9 ${pid} 