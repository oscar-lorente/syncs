#!/bin/bash

#Exit if error
set -e

#Initial blacklist
blacklist=(
".gitignore"
".git/"
".git2/"
"build/"
"bin/"
"devel/"
".pyc"
".fuse*"
".nfs*")

main(){
    if [ "$1" != "" ] && [ "$2" != "" ]; then
        actARG=`echo $1 | awk -F= '{print tolower($1)}'`
        folARG=`echo $2 | awk -F= '{print tolower($1)}'`
        
        #Folder
        case $folARG in
            "phd")
                folname="phd"
                localdir="$HOME/github"
                ;;
            "mth")
                blacklist+=("world3d-ros/") #custom exclude
                folname="mth"
                localdir="$HOME/github"
                ;;
            *)
                echo "ERROR: unknown folder name: \"$folARG\""
                exit 1
                ;;
        esac
        
        #Action
        case $actARG in
            "get" | "g")
                get
                ;;
            "setloop" | "sl")
                setloop
                ;;
            *)
                echo "ERROR: unknown action: \"$actARG\""
                exit 1
                ;;
        esac
        
    else
        echo "Usage: $0 action folder"
    fi
}

get(){
    #Multiplerepo WARN: Replicate modifications in excluded dirs (find . | egrep "*excluded*" --color)
    
    create_excludes #Create array of excludes from blacklist

    #LOG
    printf 'GPI ' >> ~/syncs/gpi/$folname.txt
    trap "printf ' Exit with error\n' >> ~/syncs/gpi/$folname.txt" ERR #Log ERROR exits
    trap "printf ' Exit by USER\n' >> ~/syncs/gpi/$folname.txt; trap - ERR" INT #Log USER exits (and reset ERR)

    #get workspace/folname
    echo -e "\n\n************* Geting gpi workspace/$folname ****************\n"
    rsync -rltgoDv --delete -e 'ssh -p 2225' --progress ${excludes[*]} \
    icaminal@calcula.tsc.upc.edu:~/workspace/$folname/ $localdir/$folname/
    echo -e "OK! - workspace/$folname\n"

    #LOG
    echo '--> '`cat /etc/hostname`'    '`date` >> ~/syncs/gpi/$folname.txt
    
    #Upload logs to remote
    trap - INT ERR #reset signal handling to default
    rsync -rltgoDq --delete -e 'ssh -p 2225' ~/syncs/gpi/ icaminal@calcula.tsc.upc.edu:~/syncs/
    if (($? == 0)); then echo -e "syncs uploaded"; fi

    date +"%T"; echo
}

setloop(){
	#Multiplerepo WARN: Replicate modifications in excluded dirs (find . | egrep "*excluded*" --color)

    create_excludes #Create array of excludes from blacklist
    
	#Trigger when an event occurs
	while true; do
		
		#LOG
		printf `cat /etc/hostname` >> ~/syncs/gpi/$folname.txt
		trap "printf ' Exit with error\n' >> ~/syncs/gpi/$folname.txt" ERR #Log ERROR exits
	    trap "printf ' Exit by USER\n' >> ~/syncs/gpi/$folname.txt; trap - ERR" INT #Log USER exits (and reset ERR)
		
		#Set workspace/folname
		echo -e "\n\n---------------------- Set gpi workspace/$folname ----------------------\n"
		rsync -rltgoDv --delete -e 'ssh -p 2225' --progress ${excludes[*]} \
		$localdir/$folname/ icaminal@calcula.tsc.upc.edu:~/workspace/$folname/
		
		#LOG
		echo ' --> GPI    '`date` >> ~/syncs/gpi/$folname.txt
		
		#Upload logs to remote
	    trap - INT ERR #reset signal handling to the default
	    rsync -rltgoDq --delete -e 'ssh -p 2225' ~/syncs/gpi/ icaminal@calcula.tsc.upc.edu:~/syncs/
	    if (($? == 0)); then echo -e "syncs uploaded"; fi
		
		date +"%T"; echo

		sleep 0.2
		if inotifywait -r -e create,delete,modify,move $localdir/$folname/; then 
			continue
		else
			exit 1
		fi
	done
}

create_excludes(){
    excludes=()
    for f in ${blacklist[@]}
    do
        excludes+=(--exclude $f)
    done
}

main "$@"
