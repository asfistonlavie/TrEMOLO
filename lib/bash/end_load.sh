#pid=`ps -f | grep "TrEMOLO/lib/bash/load.sh" | awk '$8=="bash" {print $2}'`
pid=`ps -f | grep "TrEMOLO/lib/nodejs/load.js" | awk '$8=="node" {print $2}'`
if [ -n "${pid}" ]; then
    kill -s 12 ${pid}
fi;
