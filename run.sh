#!/bin/bash
set -m

#set -e # stop on errors

HOME="/home/odroid"
CURR_DIR=$PWD
BBENCH_DIR="/home/odroid/bbench-3.0"
STHHAMP_DIR="/home/odroid/experimental-platform-software"
PERF_DIR="/home/odroid/data-collector-dup/perf-data"

PERF="/home/odroid/bin/perf"

MONOUT_DIR="$CURR_DIR/powmon-data"
JSON_DIR="$CURR_DIR/json-data"
THREADDATA_DIR="$CURR_DIR/process-monitoring/data"
TIMESTAMP_DIR="$CURR_DIR/process-monitoring/data"
SUFFIX="all"

AVAIL_GOVS="/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors"
BIG_CPU_GOV="/sys/devices/system/cpu/cpu7/cpufreq/scaling_governor"
LIL_CPU_GOV="/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
OLD_BIG_CPU_GOV=""
OLD_LIL_CPU_GOV=""

DUMMY_SERVER_FILE="http://was42@tucunare.cs.pitt.edu:8080/index.html"

INTERNET_WAS_OFF="yes"
GDM_WAS_OFF="yes" 

PROFILE_SAMPLE_PERIOD_US=100000 #10Hz for Powmon

THREADMON_SAMPLE_PERIOD_US=100000 #10Hz for thread monitor
THREADMON_DIR="threadmon"
THREADMON_LOG_FILE="threadmon.log" #10Hz for thread monitor

COMMAND_TO_RUN="./monitor $THREADMON_SAMPLE_PERIOD_US -1 b $THREADMON_LOG_FILE python -m flamegraph -o perf.log sel.py" # firefox $BBENCH_DIR/index.html 
SITES=("amazon" "bbc" "cnn" "craigslist" "ebay" "google" "msn" "slashdot" "twitter" "youtube")

PROG_NAME=$0
CORE_CONFIG=$1
OUTPUT_FILE=$2
GOV_STR=$3
SITE=$4
MODE=$5
ITERATIONS=$6


give_usage() {
	echo -e \
"usage: sudo $PROG_NAME\t[core-config]\n\
\t\t\t[output-filename]\n\
\t\t\t[governors: pi,ip,pp,ii]\n\
\t\t\t[website]\n\
\t\t\t[mode: collect, configs, or test]\n\
\t\t\t[number of iterations]\n" >&2
	exit 1
}

array_contains () {
	local array="$1[@]"
	local seeking=$2
	local in=1
	for element in "${!array}"; do
		if [[ $element == $seeking ]]; then
			in=0
			break
		fi
	done
	return $in
}

check_core_config() {
	if ! [[ `echo $1 | grep -i B` ]] || ! [[ `echo $1 | grep -i L` ]]; then # there's a missing b/l
		echo "error"
		return
	fi
	l=$( echo $1 | grep -io [0-9]*l | grep -o [0-9]* )
	b=$( echo $1 | grep -io [0-9]*b | grep -o [0-9]* )

	if [ "$l" -lt 0 ]; then
		echo "error: less than 0 little cores"
	elif [ "$b" -lt 0 ]; then
		echo "error: less than 0 big cores"
	elif [ "$l" -gt 4 ]; then
		echo "error: more than 4 little cores"
	elif [ "$b" -gt 4 ]; then
		echo "error: more than 4 big cores"
	elif [ "$l" -eq 0 ]; then
		if [ "$b" -eq 0 ]; then
			echo "error: no cores"
		fi
	fi
}

get_config() {
	l=$( echo $1 | grep -io [0-9]*l | grep -o [0-9]* )
	b=$( echo $1 | grep -io [0-9]*b | grep -o [0-9]* )
	lilStr=""
	bigStr=""

	if [ $l -eq 4 ]; then
		if [ $b -eq 4 ]; then
			echo "0-7"
			return
		else
			if [ $b -eq 0 ]; then
				echo "0-3"
				return
			else
				lilStr="0-3"
			fi
		fi
	elif [ $b -eq 4 ]; then
		if [ $l -eq 0 ]; then
			echo "4-7"
			return
		else
			bigStr="4-7"
		fi
	fi

	declare -a littles bigs
	if [ -z $lilStr ]; then
		for (( i=1; i<=$l; i++ )) # get lists of random cores
		do
			x=$( echo $RANDOM % 4 | bc )
			array_contains littles "$x"
			while [ $? -eq 0 ]; do
				x=$( echo $RANDOM % 4 | bc )
				array_contains littles "$x"
			done
			littles=("${littles[@]}" "$x")
		done
	fi

	if [ -z $bigStr ]; then
		for (( i=1; i<=$b; i++ ))
		do
			x=$( echo $RANDOM % 4 + 4 | bc )
			array_contains bigs "$x"
			while [ $? -eq 0 ]; do
				x=$( echo $RANDOM % 4 + 4 | bc )
				array_contains bigs "$x"
			done
			bigs=("${bigs[@]}" "$x")
		done
	fi

	declare -a lilSorted bigSorted

	if [ ${#littles[@]} -gt 0 ]; then
		IFS=$'\n' lilSorted=($(sort <<<"${littles[*]}"))
		unset IFS
		lilStr="${lilSorted[*]}"
	fi
	if [ ${#bigs[@]} -gt 0 ]; then
		IFS=$'\n' bigSorted=($(sort <<<"${bigs[*]}"))
		unset IFS
		bigStr="${bigSorted[*]}"
	fi

	if ! [ -z "$lilStr" ]; then
		if ! [ -z "$bigStr" ]; then
			config_str="$lilStr $bigStr"
		else
			config_str="$lilStr"
		fi
	else
		config_str="$bigStr"
	fi

	echo ${config_str// /,}
}

set_governor() {
	if ! [[ `cat $AVAIL_GOVS` ]]; then # no available governors
		echo "error: unable to read available governors"
		exit 1
	elif ! [[ `cat $AVAIL_GOVS | grep performance` ]]; then # no performance governor
		echo "error: no performance governor available"
		exit 1
	fi

	NEW_BIG_CPU_GOV="performance"
	NEW_LIL_CPU_GOV="performance"

	if [[ "${1:0:1}" == "i" ]]; then
		NEW_LIL_CPU_GOV="interactive"
	elif [[ "${1:0:1}" == "p" ]]; then
		NEW_LIL_CPU_GOV="performance"
	elif [[ "${1:0:1}" == "c" ]]; then
		NEW_LIL_CPU_GOV="conservative"
	elif [[ "${1:0:1}" == "s" ]]; then
		NEW_LIL_CPU_GOV="powersave"
	elif [[ "${1:0:1}" == "o" ]]; then
		NEW_LIL_CPU_GOV="ondemand"
	else
		echo "error: invalid governor string"
		exit 1
	fi
	
	if [[ "${1:1:1}" == "i" ]]; then
		NEW_BIG_CPU_GOV="interactive"
	elif [[ "${1:1:1}" == "p" ]]; then
		NEW_BIG_CPU_GOV="performance"
	elif [[ "${1:1:1}" == "c" ]]; then
		NEW_BIG_CPU_GOV="conservative"
	elif [[ "${1:1:1}" == "s" ]]; then
		NEW_BIG_CPU_GOV="powersave"
	elif [[ "${1:1:1}" == "o" ]]; then
		NEW_BIG_CPU_GOV="ondemand"
	else
		echo "error: invalid governor string"
		exit 1
	fi

	OLD_BIG_CPU_GOV=`cat $BIG_CPU_GOV` # save the old state
	OLD_LIL_CPU_GOV=`cat $LIL_CPU_GOV`

	if [ -z $OLD_BIG_CPU_GOV ]; then
		echo "error: unable to save big cluster governor"
	fi
	if [ -z $OLD_LIL_CPU_GOV ] ; then
		echo "error: unable to save little cluster governor"
	fi

	echo $NEW_BIG_CPU_GOV > "$BIG_CPU_GOV"
	echo $NEW_LIL_CPU_GOV > "$LIL_CPU_GOV"
	
	echo "Big: $NEW_BIG_CPU_GOV"
	echo "Little: $NEW_LIL_CPU_GOV"
	
	# governor did not change...
	if ! [[ `cat $BIG_CPU_GOV | grep $NEW_BIG_CPU_GOV` ]] || ! [[ `cat $LIL_CPU_GOV | grep $NEW_LIL_CPU_GOV` ]]; then
		echo "error: unable to change governor"
		exit 1
	fi
}

restore_governor() {
	if [ -z $OLD_BIG_CPU_GOV ]; then # couldn't save, don't try to restore
		return
	elif [ -z $OLD_LIL_CPU_GOV ] ; then
		return
	fi
	echo "restoring governors to $OLD_BIG_CPU_GOV and $OLD_LIL_CPU_GOV"

	echo $OLD_BIG_CPU_GOV > $BIG_CPU_GOV
	echo $OLD_LIL_CPU_GOV > $LIL_CPU_GOV
}

sigint() {
	echo "signal INT caught, cleaning up"
	echo "killing cdatalog..."
	kill `pgrep cdatalog`
	echo "killed"

	echo "killing python and selenium..."
	kill `pgrep python` # kill all the processes involved with selenium
	kill `pgrep chromedriver` #TODO find a simpler/cleaner way to do this
	kill `pgrep chromium-browse`
	kill `pgrep Xvfb`
	echo "killed"

	#echo "killing firefox"
	#if [[ `pgrep firefox` ]]; then
	#	kill `pgrep firefox`
	#fi

	if ! [ -f $CURR_DIR/output.json ]; then
		echo "error: '$COMMAND_TO_RUN' did not create a file called 'output.json'"
	else 
		echo "mv $CURR_DIR/output.json $JSON_DIR/$OUTPUT_FILE-$SUFFIX.json"
		mv $CURR_DIR/output.json $JSON_DIR/$OUTPUT_FILE-$SUFFIX.json
	fi
	echo "restoring governor..."
	restore_governor

	#if [[ "$INTERNET_WAS_OFF" == "no" ]]; then # restart internet if it was disabled by this script
	#	echo "ifconfig eth0 up"
	#	ifconfig eth0 up
	#fi

	#if [[ "$GDM_WAS_OFF" == "no" ]]; then # restart gdm if need be
	#	echo "service gdm3 start"
	#	service gdm3 start
	#fi
	exit 2 # want to return that we hit a ctrl-c
}

trap 'sigint' SIGINT 

# Startup checks
if [ "$EUID" -ne 0 ]; then
	echo "error: sudo privileges needed by this script"
	give_usage
elif [ $# -lt 6 ]; then
	echo "error: not enough args"
	give_usage
fi



if [[ `service gdm3 status | grep running` ]]; then # gdm is being run, stop it
	GDM_WAS_OFF="no"
	#service gdm3 stop
	echo "please disable gdm"
	echo "example command: sudo service gdm3 stop"
	give_usage
fi

if [[ $MODE == "test" ]]; then
	echo "performing a dry run..."
else 
	echo "contacting server..."
	NUM_RETRIES=20 # retry the connection a few times
	wget -q -O /dev/null $DUMMY_SERVER_FILE # try to load a test file from the server 
	RET_VAL=$?
	while ! [[ $NUM_RETRIES == "0" ]] && ! [[ $RET_VAL == "0" ]]; do # while we haven't exceeded our tries and have a bad return value
		sleep 0.5 # wait for a little
		echo "trying again to contact server..." 
		NUM_RETRIES=$(( $NUM_RETRIES - 1 ))
		wget -q -O /dev/null $DUMMY_SERVER_FILE # try to load a test file from the server 
		RET_VAL=$?
	done
	if ! [ $RET_VAL -eq 0 ]; then
		echo "error: unable to connect to server, error returned from wget was $RET_VAL"
		echo "trying using 'man wget' to find out more information"
		#INTERNET_WAS_OFF="no"
		#ifconfig eth0 down # old way was to disable internet and load from disk
		give_usage
	fi
	echo "Connected to server!"
fi

# Preprocessing 
#core_config_flag=$(get_config $CORE_CONFIG)
core_config_flag=$CORE_CONFIG
ID=`mktemp -u XXXXXXXX`
SUFFIX="$CORE_CONFIG-$GOV_STR-$ID"


echo ""

echo "experiment id is $ID"
echo "starting up command with cores: $core_config_flag..."
echo "sudo -u odroid taskset -c $core_config_flag $COMMAND_TO_RUN &"


echo ""

# "collect" mode collects process data to help determine key processes
if [[ $MODE == "collect" ]]; then
	echo "setting governor with str $GOV_STR..."
	set_governor $GOV_STR # check that it is in correct mode

	# Run Chromium in the background, and start the script that monitors each process
	sudo -u odroid $COMMAND_TO_RUN $SITE $ITERATIONS &
	g++ threadmonitoring.cpp -o threadm
	sleep 1
	val=$(ps ax | grep chromium | awk '{printf $1"\n"}')
	# If you want to collect data on the child threads of one of the processes, comment out "./threadm "$val"" and use these three lines instead
	#processes=(${val// / })
	#children=$(ls /proc/${processes[5]}/task)
	#./threadm "$children" "${processes[5]}"
	./threadm "$val"
	fg		# Make sure Chromium finishes
	
	if [[ `pgrep cdatalog` ]]; then # if the power monitor hasn't finished yet
		echo "killing cdatalog..."
		pkill cdatalog # kill it
	fi

    # Copy the output files to the appropriate folders
	if ! [ -f $CURR_DIR/threaddata.csv ]; then
		echo "error: '$CURR_DIR/threaddata.csv' did not write out a thread data file"
	else
		echo "moving thread time data..."
		mv $CURR_DIR/threaddata.csv $THREADDATA_DIR/${SITES[$SITE]}-$OUTPUT_FILE-$SUFFIX.csv # save cdatalog output
	fi

	if ! [ -f $CURR_DIR/output.json ]; then
		echo "error: '$COMMAND_TO_RUN' did not write out a json file"
	else
		echo "moving timestamp data..."
		python extract_timestamps.py $CURR_DIR/output.json $TIMESTAMP_DIR/${SITES[$SITE]}-$OUTPUT_FILE-$SUFFIX.txt
	fi

	# Restoring state
	restore_governor
fi
# "configs" mode measures energy and time usage for different core configurations
if [[ $MODE == "configs" ]]; then
	echo "setting governor with str $GOV_STR..."
	set_governor $GOV_STR # check that it is in correct mode

    # start up the southhampton monitor
    # options are: [outputfile] [period (us)] [use-pmcs] [performance counters...]
	# assign the power monitor to core 0, which never turns off
	taskset -c 0 "$STHHAMP_DIR/datalogging_code/cdatalog" "$CURR_DIR/cdatalog-output" $PROFILE_SAMPLE_PERIOD_US 1 0x08 0x19 0x16 0x17 0x08 0x19 0x1D 0x16 0x17 0x61 &

	# Start Chromium in the background
	# Don't specify cores for the default option
	if [[ $CORE_CONFIG == "Default" ]]; then
		sudo -u odroid $COMMAND_TO_RUN $SITE $ITERATIONS &
	# Specify big cores for AllBig
	elif [[ $CORE_CONFIG == "AllBig" ]]; then
		sudo -u odroid taskset -c 4-7 $COMMAND_TO_RUN $SITE $ITERATIONS &
	# Otherwise start with small cores. We will move some of the processes to big cores later
	else
		sudo -u odroid taskset -c 0-3 $COMMAND_TO_RUN $SITE $ITERATIONS &
	fi
	
	# Get a list of processes
	val=$(ps ax | grep chromium | awk '{printf $1":"}')
	IFS=':' read -r -a processes <<< "$val"
	# Should be 8 processes in total (plus one more for the ps ax | grep chromium command)
	while [ ${#processes[@]} -lt 9 ]
	do
		val=$(ps ax | grep chromium | awk '{printf $1":"}')
		IFS=':' read -r -a processes <<< "$val"
	done
	echo $val
	
	# For some configs, we have to move processes to different cores
	# For 1Big, put the sixth process on a big core
	if [[ $CORE_CONFIG == "1Big" ]]; then
		taskset -cp 4 "${processes[5]}"
	# For 2Big, put the sixth and first processes on big cores
	elif [[ $CORE_CONFIG == "2Big" ]]; then
		taskset -cp 4 "${processes[5]}"
		taskset -cp 5 "${processes[0]}"
	# For 3Big, put the sixth, first, and fourth processes on big cores
	elif [[ $CORE_CONFIG == "3Big" ]]; then
		taskset -cp 4 "${processes[5]}"
		taskset -cp 5 "${processes[0]}"
		taskset -cp 6 "${processes[3]}"
	# For 4Big, put the sixth, first, fourth, and fifth processes on big cores
	elif [[ $CORE_CONFIG == "4Big" ]]; then
		taskset -cp 4 "${processes[5]}"
		taskset -cp 5 "${processes[0]}"
		taskset -cp 6 "${processes[3]}"
		taskset -cp 7 "${processes[4]}"
	fi
	
	# For the dynamic configuration, we will continuously monitor the first process for activity
	if [[ $CORE_CONFIG == "Dynamic" ]]; then
		declare -i finished=0
		declare -i big=0
		
		prev_time=$(date '+%s%N' | cut -b1-13)
		stats=$(cat /proc/${processes[5]}/stat)
		prev_ticks="$(echo $stats | cut -d' ' -f14)"
		sleep 0.04
		while [ $finished -eq 0 ]
		do
			# Get the current system time, and the sixth process' user time so far from the proc folder
			current_time=$(date '+%s%N' | cut -b1-13)
			stats=$(cat /proc/${processes[5]}/stat)
			pid="$(echo $stats | cut -d' ' -f1)"
			usertime="$(echo $stats | cut -d' ' -f14)"
			ratio=100
			# If the number of ticks isn't 0, compute time elapsed / ticks used by the process
			if [ $usertime -gt $prev_ticks ]
			then
				ratio="$(( ($current_time - $prev_time) / ($usertime - $prev_ticks) ))"
			fi
			echo $ratio
			# If the ratio of time elapsed/ticks used by the process is low, activity is high and we should move the sixth process to a big core
			if [ $ratio -lt 10 ]
			then
				if [ $big -eq 0 ]
				then
					taskset -cp 4 "${processes[5]}"
					big=1
				fi
			# Otherwise it should go to a small core
			else
				if [ $big -eq 1 ]
				then
					taskset -cp 0-3 "${processes[5]}"
					big=0
				fi
			fi
			# If the process' proc file was empty, it is finished, so we will exit the loop
			if [ "$pid" == '' ]
			then
				finished=1
			fi
			prev_time=$current_time
			prev_ticks=$usertime
			sleep 0.04
		done
	fi
	fg
	
	if [[ `pgrep cdatalog` ]]; then # if the power monitor hasn't finished yet
		echo "killing cdatalog..."
		pkill cdatalog # kill it
	fi

    # Copy the output files to the appropriate folders
	if ! [ -f $CURR_DIR/cdatalog-output ]; then
		echo "error: '$STHHAMP_DIR/datalogging_code/cdatalog' did not write out a profile"
	else 
		echo "moving power monitoring data..." 
		mv $CURR_DIR/cdatalog-output $MONOUT_DIR/$OUTPUT_FILE-$SUFFIX # save cdatalog output
	fi

	if ! [ -f $CURR_DIR/output.json ]; then
		echo "error: '$COMMAND_TO_RUN' did not write out a json file"
	else 
		echo "moving timestamp data..."
		mv $CURR_DIR/output.json $JSON_DIR/$OUTPUT_FILE-$SUFFIX.json # save command output
	fi

	# Restoring state
	restore_governor
fi
# Dry run that doesn't collect any data
if [[ $MODE == "test" ]]; then
	echo "setting governor with str $GOV_STR..."
	set_governor $GOV_STR

	echo "starting southhampton monitor"
	echo "taskset -c 0 $CURR_DIR/cdatalog-output $MONOUT_DIR/$OUTPUT_FILE-$SUFFIX $PROFILE_SAMPLE_PERIOD_US 1 0x08 0x16 0x60 0x61 0x08 0x40 0x41 0x14 0x50 0x51 &"

	echo "starting command"
	echo "sudo $PERF record -F 10 --call-graph fp -T -s -d -- sudo -u odroid taskset -c $core_config_flag $COMMAND_TO_RUN"
	echo "sudo -u odroid taskset -c $core_config_flag $COMMAND_TO_RUN"

	echo ""
	echo "moving cdatalog output file"
	echo "mv $CURR_DIR/cdatalog-output $MONOUT_DIR/$OUTPUT_FILE-$SUFFIX" 

	echo ""
	echo "moving perf output file"
	echo "mv $CURR_DIR/perf.data $PERF_DIR/$OUTPUT_FILE-$SUFFIX.data"


	echo ""
	echo "moving selenium output file"
	echo "mv $CURR_DIR/output.json $JSON_DIR/$OUTPUT_FILE-$SUFFIX.json"

	restore_governor

	if [[ "$INTERNET_WAS_OFF" == "no" ]]; then # restart internet if it was disabled by this script
		echo "ifconfig eth0 up"
		#ifconfig eth0 up
	fi
	if [[ "$GDM_WAS_OFF" == "no" ]]; then # restart gdm if need be
		echo "service gdm3 start"
		service gdm3 start
	fi
fi
