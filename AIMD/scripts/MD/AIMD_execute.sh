#!/bin/sh 
 
cat 'AIMD_preplist.txt' | while read condition_number ; do 


    echo "#### Preparing AIMD for "$condition_number
    mkdir './AIMS/'"$condition_number"'/AIMD'


    ls -l './AIMS/'"$condition_number"/TrajDump.* | awk '{print $9}' > './tmp_traj.txt'

    cat 'tmp_traj.txt' | while read traj ; do 
        traj_num=$(echo "${traj: 21}")

        final_line_traj=$(tail -1 $traj)
        state=$(echo $final_line_traj | awk '{print $NF}')

        echo "$traj_num"" is in state ""$state" 

        if [[ $state != 1.0000 ]] ; then
            continue
        fi 
        

        echo "Preparing Trajectory "$traj_num


        mkdir './AIMS/'"$condition_number"'/AIMD/'"$traj_num"
        cp "./AIMD_prep/tc.in" './AIMS/'"$condition_number"'/AIMD/'"$traj_num"
        cp "./AIMD_prep/submit.sh" './AIMS/'"$condition_number"'/AIMD/'"$traj_num"

        ref_geomdat='./AIMS/'"$condition_number"'/Geometry.dat'
        AIMD_coords='./AIMS/'"$condition_number"'/AIMD/'"$traj_num"'/coords.xyz' 
        AIMD_vels='./AIMS/'"$condition_number"'/AIMD/'"$traj_num"'/vels.xyz' 


            
        natoms=$(sed -n '2p' $ref_geomdat)
            
        echo $natoms > $AIMD_coords
        echo "$condition_number""     ""$traj_num" >> $AIMD_coords 

        echo $natoms > $AIMD_vels
        echo "$condition_number""     ""$traj_num" >> $AIMD_vels


        
        counter=1

        for i in $(seq 1 $natoms)
            do 

            atom_type=$(awk -v line="$((i+2))" 'NR == line {print $1}' $ref_geomdat) 

            #Write Position File -----------

            x_col=$((counter+1))
            y_col=$((counter+2))
            z_col=$((counter+3))

                
            #convert bohr to angst >:[
            x_pos=$(echo "$final_line_traj" | awk -v col="$x_col" '{printf "%.10f",  $col * 0.529177 }') 
            y_pos=$(echo "$final_line_traj" | awk -v col="$y_col" '{printf "%.10f", $col * 0.529177 }')
            z_pos=$(echo "$final_line_traj" | awk -v col="$z_col" '{printf "%.10f", $col * 0.529177 }') 
                



            echo "$atom_type""  ""$x_pos""   ""$y_pos""    ""$z_pos" >> $AIMD_coords

            #Write Velocity File -------------



            if [[ $atom_type == 'H' ]]
                then 
                mass=1822.886962890
            elif [[ $atom_type == 'C' ]]
                then
                mass=21874.64355469
            elif [[ $atom_type == 'O' ]]
                then 
                mass=29166.19140620
            else 
                echo "mass not defined, exiting program" 
		        exit 
            fi 

            x_col_mom=$((counter+(natoms*3)+1))
            y_col_mom=$((counter+(natoms*3)+2))
            z_col_mom=$((counter+(natoms*3)+3))

            x_mom=$(echo "$final_line_traj" | awk -v col="$x_col_mom" '{printf "%.10f", $col / 0.000935003962776}') 
            y_mom=$(echo "$final_line_traj" | awk -v col="$y_col_mom" '{printf "%.10f", $col / 0.000935003962776}') 
            z_mom=$(echo "$final_line_traj" | awk -v col="$z_col_mom" '{printf "%.10f", $col / 0.000935003962776}') 


            x_vel=$(printf "%.10f" "$(echo "$x_mom / $mass" | bc -l)")
            y_vel=$(printf "%.10f" "$(echo "$y_mom / $mass" | bc -l)")
            z_vel=$(printf "%.10f" "$(echo "$z_mom / $mass" | bc -l)")

                
            echo "$atom_type""   ""$x_vel""   ""$y_vel""    ""$z_vel"  >> $AIMD_vels

            counter=$((counter+3))

            #echo $counter
        done 


        cd './AIMS/'"$condition_number"'/AIMD/'"$traj_num" 
        sbatch submit.sh 
        cd ../
        cd ../
        cd ../
        cd ../

    done
        rm 'tmp_traj.txt'



done
