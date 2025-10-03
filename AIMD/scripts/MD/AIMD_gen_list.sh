#!/bin/sh 
num_to_submit=25 # change this to fit the number of AIMS conditions you wish to continue 

AIMD_preplist=./AIMD_preplist.txt
rm -f $AIMD_preplist
counter=0



cat 'AIMS_summary.txt' | while read line ; do 

    condition_number=$(echo "$line" | awk '{print $1}')
    AIMS_status=$(echo "$line" | awk '{print $2}' )
    AIMD_status=$(echo "$line" | awk '{print $3}')

    #echo "$condition_number" 
    #echo "$AIMS_status"
    #echo "$AIMD_status" 
 
    if [[ $AIMS_status = 'done' ]] && [[ $AIMD_status = 'not_created' ]] && [ $counter != $num_to_submit ]
        then
        echo "$condition_number""   added to AIMD_preplist.txt" 
   
        echo $condition_number >> ./AIMD_preplist.txt 
        counter=$((counter+1))
    elif [ $counter == $num_to_submit ] 
        then
        exit 
    fi

done 
