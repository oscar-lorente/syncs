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
    if [ "$1" != "" ]; then
        ARG=`echo $1 | awk -F= '{print tolower($1)}'`
        case $ARG in
            "phd")
                multirepo phd
                ;;
            "mth")
                blacklist+=("world3d-ros/") #custom exclude
                multirepo mth
                ;;
            *)
                echo "ERROR: unknown parameter \"$ARG\""
                exit 1
                ;;
        esac
    else
        echo "Usage: $0 what"
    fi
}

multirepo(){
    #Multiplerepo WARN: Replicate modifications in excluded dirs (find . | egrep "*excluded*" --color)
    
    local repo=$1 # Save first argument in a variable
    create_excludes #Create array of excludes from blacklist

    #LOG
    printf 'GPI ' >> ~/syncs/gpi/$repo.txt
    trap "printf ' Exit with error\n' >> ~/syncs/gpi/$repo.txt" ERR #Log ERROR exits
    trap "printf ' Exit by USER\n' >> ~/syncs/gpi/$repo.txt; trap - ERR" INT #Log USER exits (and reset ERR)

    #get workspace/repo
    echo -e "\n\n************* Geting gpi workspace/$repo ****************\n"
    rsync -rltgoDv --delete -e 'ssh -p 2225' --progress ${excludes[*]} \
    icaminal@calcula.tsc.upc.edu:~/workspace/$repo/ ~/github/$repo/
    echo -e "OK! - workspace/$repo\n"

    #LOG
    echo '--> '`cat /etc/hostname`'    '`date` >> ~/syncs/gpi/$repo.txt
    
    #Upload logs to remote
    trap - INT ERR #reset signal handling to default
    rsync -rltgoDq --delete -e 'ssh -p 2225' ~/syncs/gpi/ icaminal@calcula.tsc.upc.edu:~/syncs/
    if (($? == 0)); then echo -e "syncs uploaded"; fi

    date +"%T"; echo
}

create_excludes(){
    excludes=()
    for f in ${blacklist[@]}
    do
        excludes+=(--exclude $f)
    done
}

main "$@"
