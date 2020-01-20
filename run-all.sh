#!/bin/bash

FILEPREFIX=$1
ITERATIONS=$2
MODE=$3

declare -a configs governors iterconfig itergovernor # declare arrays
configs=("AllSmall" "Default" "Dynamic" "1Big" "2Big" "3Big" "4Big" "AllBig") # all core configs to test with
governors=("ii") # all core configs to test with

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

gen_iterconfig() { # generate a permutation of the configs
	CONFIG_COUNT=${#configs[@]}
	iterconfig=()
	for (( i=1; i <= $CONFIG_COUNT; i++ ))
	do
		x=$( echo "$RANDOM % $CONFIG_COUNT" | bc )
		array_contains iterconfig ${configs["$x"]}
		while [ $? -eq 0 ]; do
			x=$( echo "$RANDOM % $CONFIG_COUNT" | bc )
			array_contains iterconfig ${configs["$x"]}
		done
		iterconfig=("${iterconfig[@]}" ${configs["$x"]})
	done
}

gen_itergovernor() { # generate a permutation of the governors
	GOV_COUNT=${#governors[@]}
	itergovernor=()
	for (( i=1; i <= $GOV_COUNT; i++ ))
	do
		x=$( echo "$RANDOM % $GOV_COUNT" | bc )
		array_contains itergovernor ${governors["$x"]}
		while [ $? -eq 0 ]; do
			x=$( echo "$RANDOM % $GOV_COUNT" | bc )
			array_contains itergovernor ${governors["$x"]}
		done
		itergovernor=("${itergovernor[@]}" ${governors["$x"]})
	done
}

#startup checks
if [ "$EUID" -ne 0 ]; then
	echo "error: sudo privileges needed by this script"
	give_usage
elif [ $# -lt 3 ]; then
	echo "error: not enough args"
	echo -e \
"usage: sudo $PROG_NAME\t[file-prefix]\n\
\t\t\t[num-iterations]\n\
\t\t\t[mode: configs, collect, test]\n" >&2
	exit 1
fi


gen_itergovernor

# for each governor, could be for each config first,
# but the idea behind looping through various configs 
# in the inner loop is to possiblity that caching will help a config
# since it will not be run consecutively 
for gov in ${itergovernor[@]}; do  # for each governor, configs could be looped through first,
	if [ $MODE == "configs" ]; then
		gen_iterconfig
		for config in ${iterconfig[@]}; do
			# 0=amazon,1=bbc,2=cnn,3=craigslist,4=ebay,5=google,6=msn,7=slashdot,8=twitter,9=youtube
			for site in 0 1 2 3 4 5 6 7 8 9; do
				echo "site: $site"
				echo "running ./run.sh $config $FILEPREFIX $gov $site $MODE"
				./run.sh $config $FILEPREFIX $gov $site $MODE $ITERATIONS
				RETVAL=$?
				if [[ "$RETVAL" == "1" ]]; then # run.sh didn't like something...
					echo "run.sh exited with an error, see above output"
					exit
				elif [[ "$RETVAL" == "2" ]]; then # run.sh was hit with a ctrl-c
					echo  "run.sh caught a SIGINT, exiting..."
					exit
				fi
			done
		done
	else
		# 0=amazon,1=bbc,2=cnn,3=craigslist,4=ebay,5=google,6=msn,7=slashdot,8=twitter,9=youtube
		for site in 0 1 2 3 4 5 6 7 8 9; do
			config="Default"
			echo "site: $site"
			echo "running ./run.sh $config $FILEPREFIX $gov $site $MODE"
			./run.sh $config $FILEPREFIX $gov $site $MODE $ITERATIONS
			RETVAL=$?
			if [[ "$RETVAL" == "1" ]]; then # run.sh didn't like something...
				echo "run.sh exited with an error, see above output"
				exit
			elif [[ "$RETVAL" == "2" ]]; then # run.sh was hit with a ctrl-c
				echo  "run.sh caught a SIGINT, exiting..."
				exit
			fi
		done
	fi
done
