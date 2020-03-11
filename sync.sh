#!/bin/bash
#WHY sync.sh? to do specific/reliable transfers when connection didn't allow for "fluid" X11 edition of remote files
#WARN: Replicate modifications in excluded dirs (find . | egrep "*$excluded*" --color)

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
".*.pyc"
".fuse*"
".nfs*")


maxsize="1G" #File size limit
logging=true
logdirs="$HOME/syncs/gpi:~/syncs" #(LOCAL:REMOTE)

main(){
    if [ "$1" != "" ] && [ "$2" != "" ]; then
        actionARG=`echo $1 | awk -F= '{print tolower($1)}'`
        projectARG=`echo $2 | awk -F= '{print tolower($1)}'`

        #Project
        case $projectARG in
          "tfg")
          # blacklist+=("**/corelib/include/rtabmap/core/Version.h") #custom exclude
          paths="$HOME/workspace/tfg:~/workspace/tfg" #paths to sync (LOCAL:REMOTE)
            #   ;;
            # "imp")
            #     paths="$HOME/gpi/important:~/important"
            #     logging=false
            #     if [[ ! $actionARG =~ g.* ]]; then
            #         echo "ERROR: \"${paths%%:*}\" can only be get!"; exit -1; fi
            #     ;;
            # "out")
            #     paths="$HOME/gpi/outputs:~/outputs"
            #     maxsize="1M"
            #     logging=false
            #     if [[ ! $actionARG =~ g.* ]]; then
            #         echo "ERROR: \"${paths%%:*}\" can only be get!"; exit -1; fi
            #     ;;
            *)
                echo "ERROR: unknown project name: \"$projectARG\""
                exit 1
                ;;
        esac

        if [[ ! -d "${logdirs%%:*}" ]]; then mkdir -p "${logdirs%%:*}"; fi

        #Action
        dryrun=""
        if [[ $actionARG == *"dry" ]]; then
            dryrun="--dry-run"
        fi
        case $actionARG in
            "g"* )
                get
                ;;
            "setloop"* | "sl"* )
                setloop true
                ;;
            "s"* )
                setloop false
                ;;
            *)
                echo "ERROR: unknown action: \"$actionARG\""
                exit 1
                ;;
        esac

    else
        echo "Usage: $0 action project"
    fi
}

get(){

    create_excludes #Create array of excludes from blacklist

    #LOG start
    if $logging; then
        printf "gpi " >> ${logdirs%%:*}/$projectARG.txt
        trap "printf ' Exit with error\n' >> ${logdirs%%:*}/$projectARG.txt" ERR #Log ERROR exits
        trap "printf ' Exit by USER\n' >> ${logdirs%%:*}/$projectARG.txt; trap - ERR" INT #Log USER exits (and reset ERR)
    fi

    #Get remotedir/folname
    echo -e "\n\n************* Geting gpi ${paths##*:} ****************\n"
    rsync -rltgoDv $dryrun --delete -e 'ssh -p 2225' --progress ${excludes[*]} --max-size ${maxsize}\
    oscar.lorente@calcula.tsc.upc.edu:${paths##*:}/ ${paths%%:*}/
    echo -e "OK!  ${paths##*:}\n"

    #LOG end
    if $logging; then
        echo '--> '`cat /etc/hostname`'    '`date` >> ${logdirs%%:*}/$projectARG.txt

        #Upload logs to remote
        trap - INT ERR #reset signal handling to default
        rsync -rltgoDq $dryrun --delete -e 'ssh -p 2225' ${logdirs%%:*}/ oscar.lorente@calcula.tsc.upc.edu:${logdirs##*:}
        if (($? == 0)); then echo -e "syncs uploaded"; fi
    fi

    date +"%T"; echo
}

setloop(){

    create_excludes #Create array of excludes from blacklist

    while true; do

        #LOG start
        if $logging; then
            printf `cat /etc/hostname` >> ${logdirs%%:*}/$projectARG.txt
            trap "printf ' Exit with error\n' >> ${logdirs%%:*}/$projectARG.txt" ERR #Log ERROR exits
            trap "printf ' Exit by USER\n' >> ${logdirs%%:*}/$projectARG.txt; trap - ERR" INT #Log USER exits (and reset ERR)
        fi

        #Set remotedir/folname
        echo -e "\n\n---------------------- Set gpi ${paths##*:} ----------------------\n"
        rsync -rltgoDv $dryrun --delete -e 'ssh -p 2225' --progress ${excludes[*]} \
        ${paths%%:*}/ oscar.lorente@calcula.tsc.upc.edu:${paths##*:}/
        echo -e "OK!  ${paths##*:}\n"

        #LOG end
        if $logging; then
            echo " --> gpi    "`date` >> ${logdirs%%:*}/$projectARG.txt

            #Upload logs to remote
            trap - INT ERR #reset signal handling to the default
            rsync -rltgoDq $dryrun --delete -e 'ssh -p 2225' ${logdirs%%:*}/ oscar.lorente@calcula.tsc.upc.edu:${logdirs##*:}
            if (($? == 0)); then echo -e "syncs uploaded"; fi
        fi

        date +"%T"; echo

        #LOOPING
        if $1; then
            sleep 0.2
            #Trigger when an event occurs
            if inotifywait -r -e create,delete,modify,move ${paths%%:*}/; then
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
