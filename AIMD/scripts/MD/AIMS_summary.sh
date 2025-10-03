#!/bin/sh


echo "#IC	AIMS_Status	AIMD_Status	AIMD_#" > "AIMS_summary.txt"

for i in $(ls -1 ./AIMS) 
	do
		
	FMSout="./AIMS/$i/FMS.out"
	if [ -f "$FMSout" ]; then 
       		 AIMS_status=$(grep -Fq " == FMS DONE ==" $FMSout && echo done || echo DNF)
	else 
		AIMS_status=$(echo "not_started") 
	fi 
	if [ -d "./AIMS/$i/AIMD" ] && [ $AIMS_status = 'done' ]; then
		AIMD_status=$(echo "created	" )
	    AIMD_total_count=$(ls -l ./AIMS/$i/AIMD | grep -c ^d)

		AIMD_finished_count='0'
	else
		AIMD_status=$(echo "not_created")
	        AIMD_total_count='0'
		AIMD_finished_count='0'	
	fi

	echo	"$i""	""$AIMS_status""		""$AIMD_status""	""$AIMD_finished_count"'/'"$AIMD_total_count" >> "./AIMS_summary.txt" 
done

cat 'AIMS_summary.txt'

