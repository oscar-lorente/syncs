#!/bin/bash
#WARN: Replicate modifications in excluded dirs (find . | egrep "*excluded*" --color)

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


maxsize="1G" #File size limit
logging=true

main(){
    if [ "$1" != "" ] && [ "$2" != "" ]; then
        actionARG=`echo $1 | awk -F= '{print tolower($1)}'`
        folderARG=`echo $2 | awk -F= '{print tolower($1)}'`
        
        #Folder
        case $folderARG in
            "phd")
                folname="phd"
                localdir="$HOME/github"
                remotedir="~/workspace"
                ;;
            "mth")
                blacklist+=("world3d-ros/") #custom exclude
                folname="mth"
                localdir="$HOME/github"
                remotedir="~/workspace"
                ;;
            "imp")
                folname="important"
                localdir="$HOME/gpi"
                remotedir="~"
                logging=false
                if [[ ! $actionARG =~ g.* ]]; then 
                    echo "ERROR: Folder \"$folname\" can only be get!"; exit -1; fi
                ;;
            "out")
                folname="outputs"
                localdir="$HOME/gpi"
                remotedir="~"
                maxsize="1M"
                logging=false
                if [[ ! $actionARG =~ g.* ]]; then 
                    echo "ERROR: Folder \"$folname\" can only be get!"; exit -1; fi
                ;;
            *)
                echo "ERROR: unknown folder name: \"$folderARG\""
                exit 1
                ;;
        esac
        
        #Action
        case $actionARG in
            "get" | "g")
                get
                ;;
            "set" | "s")
                setloop false
                ;;
            "setloop" | "sl")
                setloop true
                ;;
            *)
                echo "ERROR: unknown action: \"$actionARG\""
                exit 1
                ;;
        esac
        
    else
        echo "Usage: $0 action folder"
    fi
}

get(){

    create_excludes #Create array of excludes from blacklist

    #LOG start
    if $logging; then
        printf "gpi " >> ~/syncs/gpi/$folname.txt
        trap "printf ' Exit with error\n' >> ~/syncs/gpi/$folname.txt" ERR #Log ERROR exits
        trap "printf ' Exit by USER\n' >> ~/syncs/gpi/$folname.txt; trap - ERR" INT #Log USER exits (and reset ERR)
    fi

    #Get remotedir/folname
    echo -e "\n\n************* Geting gpi $remotedir/$folname ****************\n"
    rsync -rltgoDv --delete -e 'ssh -p 2225' --progress ${excludes[*]} --max-size ${maxsize}\
    icaminal@calcula.tsc.upc.edu:$remotedir/$folname/ $localdir/$folname/
    echo -e "OK!  $remotedir/$folname\n"

    #LOG end
    if $logging; then
        echo '--> '`cat /etc/hostname`'    '`date` >> ~/syncs/gpi/$folname.txt
        
        #Upload logs to remote
        trap - INT ERR #reset signal handling to default
        rsync -rltgoDq --delete -e 'ssh -p 2225' ~/syncs/gpi/ icaminal@calcula.tsc.upc.edu:~/syncs/
        if (($? == 0)); then echo -e "syncs uploaded"; fi
    fi

    date +"%T"; echo
}

setloop(){

    create_excludes #Create array of excludes from blacklist
    
    while true; do
        
        #LOG start
        if $logging; then
            printf `cat /etc/hostname` >> ~/syncs/gpi/$folname.txt
            trap "printf ' Exit with error\n' >> ~/syncs/gpi/$folname.txt" ERR #Log ERROR exits
            trap "printf ' Exit by USER\n' >> ~/syncs/gpi/$folname.txt; trap - ERR" INT #Log USER exits (and reset ERR)
        fi
        
        #Set remotedir/folname
        echo -e "\n\n---------------------- Set gpi $remotedir/$folname ----------------------\n"
        rsync -rltgoDv --delete -e 'ssh -p 2225' --progress ${excludes[*]} \
        $localdir/$folname/ icaminal@calcula.tsc.upc.edu:$remotedir/$folname/
        echo -e "OK!  $remotedir/$folname\n"
        
        #LOG end
        if $logging; then
            echo " --> gpi    "`date` >> ~/syncs/gpi/$folname.txt
            
            #Upload logs to remote
            trap - INT ERR #reset signal handling to the default
            rsync -rltgoDq --delete -e 'ssh -p 2225' ~/syncs/gpi/ icaminal@calcula.tsc.upc.edu:~/syncs/
            if (($? == 0)); then echo -e "syncs uploaded"; fi
        fi
        
        date +"%T"; echo
        
        #LOOPING
        if $1; then
            sleep 0.2
            #Trigger when an event occurs
            if inotifywait -r -e create,delete,modify,move $localdir/$folname/; then
                continue
            else
                exit 1
            fi
        else
            exit
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
