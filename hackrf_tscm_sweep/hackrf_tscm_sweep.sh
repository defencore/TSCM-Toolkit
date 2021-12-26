#!/bin/bash
DATABASE="sweep.db"
SIGNAL_FILE="signals.csv"

# HackRF Config
freq_start=50
freq_stop=6000
lna=8		# Low Noise Amplifier 0-40dB / 8dB step
# 5000000 = 5MHz
# 500000  = 500KHz
# 50000   = 50KHz
# 5000    = 5KHz
fft=50000 # FFT bin width (frequency resolution) in Hz, 2445-5000000

SWEEP_PID='/tmp/sweep.pid'
MERGE_PID='/tmp/merge.pid'

sys_init(){
	resolution=$((5*1000000/${fft})) # 5MHz / 50kHz = 100
	timeout=10	# Split scans for 10 seconds
	threshold=5	# Signal detection threshold
}
sys_init

structure_init(){
	x1=''; x2=''; x3=''; x4=''
	for((i=0;i<=$resolution;i++));do
		x1+=",offset_$(($i * $fft)) integer"
		x2+=", MAX(offset_$(($i * $fft)))"
		x3+=", MAX(offset_$(($i * $fft))) AS offset_$(($i * $fft))"
		x4+=", offset_$(($i * $fft))"
	done
	TABLE_STRUCTURE="(date integer, time integer, hz_low integer, hz_high integer, hz_bin_width integer, num_samples integer${x1});"
	TABLE_SELECT="hz_low$x2"
	TABLE_AS_OFFSET="hz_low$x3"
	TABLE_INSERT="(hz_low$x4)"
}

kill_sweep(){
	[ -f $SWEEP_PID ] && kill -9 $(cat $SWEEP_PID) >/dev/null && killall hackrf_sweep && rm -rf $SWEEP_PID
	[ -f $MERGE_PID ] && kill -9 $(cat $MERGE_PID) >/dev/null && rm -rf $MERGE_PID
	rm -rf tmp_* scan_*
}

run_sweep(){
	echo ">>> Starting SWEEP SCAN"
	kill_sweep
	while true; do
		scan=$(date +%s)
		timeout $timeout hackrf_sweep -w ${fft} -a 0 -p 0 -l ${lna} -f ${freq_start}:${freq_stop} > tmp_${scan}
		# Here we have a delay. Implement through a pipe
		mv tmp_${scan} scan_${scan}
	done 2>/dev/null &
	echo "$!" > ${SWEEP_PID}
	echo "SWEEP_PID: $(cat ${SWEEP_PID})"
}

build_table(){
	# Tables: TSCM_MASK SCAN SCAN_MASK TMP
	sqlite3 ${DATABASE} "CREATE TABLE IF NOT EXISTS TSCM_MASK ${TABLE_STRUCTURE}"
	sqlite3 ${DATABASE} "CREATE TABLE IF NOT EXISTS SCAN ${TABLE_STRUCTURE}"
	sqlite3 ${DATABASE} "CREATE TABLE IF NOT EXISTS SCAN_MASK ${TABLE_STRUCTURE}"
	sqlite3 ${DATABASE} "CREATE TABLE IF NOT EXISTS TMP ${TABLE_STRUCTURE}"
}

function merge_tables(){
	while true; do
		# $1 = TABLE: SCAN_MASK OR TSCM_MASK
		x=0
		for f in $(ls scan_*); do
			echo "File -> $f"
			sqlite3 ${DATABASE} "CREATE TABLE IF NOT EXISTS SCAN ${TABLE_STRUCTURE}"
			sqlite3 ${DATABASE} "DELETE FROM SCAN"
			sqlite3 ${DATABASE} ".import --csv $f SCAN"
			sqlite3 ${DATABASE} "DELETE FROM TMP"
			sqlite3 ${DATABASE} "INSERT INTO TMP ${TABLE_INSERT} SELECT ${TABLE_SELECT} FROM (SELECT ${TABLE_AS_OFFSET} FROM $1 GROUP BY hz_low UNION SELECT ${TABLE_AS_OFFSET} FROM SCAN GROUP BY hz_low) GROUP BY hz_low"
			sqlite3 ${DATABASE} "DELETE FROM $1; INSERT INTO $1 SELECT * FROM TMP"
			echo "<<< $f IMPORTED"
			sleep 2
			# add check what to do if not imported
			rm -rf $f
			x=$(($x+1))
		done
		sqlite3 ${DATABASE} "DELETE FROM TMP"
		sqlite3 ${DATABASE} "DELETE FROM SCAN"
	done 2>/dev/null &
	echo "$!" > ${MERGE_PID}
	echo "MERGE_PID: $(cat ${MERGE_PID})"
}

function compare_tables(){
	echo ">>> COMPARE TABLES $1 with TSCM_MASK"
	x5=''
	for((i=0;i<=$resolution;i++));do
		x5+="$1.offset_$(($i * $fft)) > ${threshold}+(SELECT offset_$(($i * $fft)) FROM TSCM_MASK WHERE TSCM_MASK.hz_low = $1.hz_low) OR "
	done
	TABLE_COMPARE="${x5::-4}"
	sqlite3 ${DATABASE} "SELECT ${TABLE_SELECT} FROM $1 WHERE ${TABLE_COMPARE} GROUP BY hz_low;" > ${SIGNAL_FILE}
	while read ALERT; do
		echo $ALERT
		FREQ=$(echo "$ALERT" | cut -d '|' -f 1)
#		x=2
#		for((i=0;i<=$resolution;i++));do
#			echo $(echo "scale=2; $(($FREQ+$i*50000))/1000000" | bc -l )","$(echo "$ALERT" | cut -d "|" -f $x)
#			x=$(($x+1))
#		done
	done < "$SIGNAL_FILE"
}

structure_init

case $@ in
	"--mask" )
		echo ">>> GET SIGNAL MASK"
		run_sweep
		build_table
		merge_tables TSCM_MASK
		sleep 10
		while true; do
			read -p "Press [ENTER] to stop scanning ..."
			kill_sweep
			exit
		done
	;;
	"--scan" )
		echo ">>> GET SIGNAL MASK"
		run_sweep
		build_table
		sleep 10
		sqlite3 ${DATABASE} "DELETE FROM SCAN"
		sqlite3 ${DATABASE} "DELETE FROM SCAN_MASK"
		merge_tables SCAN_MASK
		while true; do
			read -p "Press [ENTER] to stop scanning ..."
			kill_sweep
			exit
		done
	;;
	"--compare" )
		compare_tables SCAN_MASK
	;;
	"--reset" )
		echo ">>> RESET SIGNAL DATABASE"
		sqlite3 ${DATABASE} "DELETE FROM TMP"
		sqlite3 ${DATABASE} "DELETE FROM SCAN"
		sqlite3 ${DATABASE} "DELETE FROM SCAN_MASK"
		sqlite3 ${DATABASE} "DELETE FROM TSCM_MASK"
		[ -f ${SIGNAL_FILE} ] && rm -rf ${SIGNAL_FILE}
		rm -rf scan_*
	;;
	*)
		kill_sweep
		echo "--mask    | Get signal mask"
		echo "--scan    | Record scan"
		echo "--compare | Show found signals"
		echo "--reset   | Reset database"
	;;
esac
