###########
#
# FUNCIONES
#
# ------------------------------------------------------------------------------------------------------- #
whiptail_message()
{
    whiptail \
        --title "$TITLE" \
        --backtitle "$BACKTITLE" \
        --textbox "$1" \
        "$2" "$3"
}
# ------------------------------------------------------------------------------------------------------- #
whiptail_input()
{
while [ -z $INPUT ]
do
    INPUT=$(whiptail --title "$TITLE" --backtitle "$BACKTITLE" \
    --inputbox "$1" 7 78 3>&1 1>&2 2>&3)
done
}
# ------------------------------------------------------------------------------------------------------- #
whiptail_password()
{
while [ -z $INPUT ]
do
    INPUT=$(whiptail --title "$TITLE" --backtitle "$BACKTITLE" \
    --passwordbox "$1" 12 78 3>&1 1>&2 2>&3)
done
}
# ------------------------------------------------------------------------------------------------------- #
spinner()
{
    local pid=$!
    local delay=0.75
    local spinstr='...'
    echo "Loading "
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "%s  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b"
    done
    printf "    \b\b\b\b"
}
# ------------------------------------------------------------------------------------------------------- #
progressBar()
{
#   Slick Progress Bar
#   Created by: Ian Brown (ijbrown@hotmail.com)
#   Please share with me your modifications
# Functions
PUT(){ echo -en "\033[${1};${2}H";}
DRAW(){ echo -en "\033%";echo -en "\033(0";}
WRITE(){ echo -en "\033(B";}
HIDECURSOR(){ echo -en "\033[?25l";}
NORM(){ echo -en "\033[?12l\033[?25h";}
function showBar {
        percDone=$(echo 'scale=2;'$1/$2*100 | bc)
        halfDone=$(echo $percDone/2 | bc) #I prefer a half sized bar graph
        barLen=$(echo ${percDone%'.00'})
        halfDone=`expr $halfDone + 6`
        tput bold
        PUT 7 28; printf "%4.4s  " $barLen%     #Print the percentage
        PUT 5 $halfDone;  echo -e "\033[7m \033[0m" #Draw the bar
        tput sgr0
        }
# Start Script
clear
HIDECURSOR
echo -e "$Cyan"
echo -e ""
DRAW    #magic starts here - must use caps in draw mode
echo -e "      PROCESO TERMINADO - LIMPIANDO ARCHIVOS TEMPORALES "
echo -e "    lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk"
echo -e "    x                                                   x"
echo -e "    mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj"
WRITE
#
sleep 2
#
for (( i=0; i<=50; i++ ))
do
    showBar $i 50  #Call bar drawing function "showBar"
    echo -e "$Cyan"
    sleep .1
done
# End of your script
# Clean up at end of script
PUT 10 12
echo -e ""
NORM
}
# ------------------------------------------------------------------------------------------------------- #
calculate(){ ## The Calculator! 'How many angels on a pidhead?'
    echo "Highly technical, time-consuming process here..."
    sleep .5  # sleep for 10 minutes
}
# ------------------------------------------------------------------------------------------------------- #
showprogress(){                                        ## The Gauge:  Produce the number stream
    start=$1; end=$2; shortest=$3; longest=$4

    for n in $(seq $start $end); do
        echo $n
        pause=$(shuf -i ${shortest:=1}-${longest:=3} -n 1)  # random wait between 1 and 3 seconds
        sleep .1
    done
}
# ------------------------------------------------------------------------------------------------------- #
processgauge(){                                         ## The Caller:  Start the gauge and watch the PID
    process_to_measure=$1
    message=$2
    backmessage=$3
    eval $process_to_measure &
    thepid=$!
    num=25
    while true; do
        showprogress 1 $num 1 3
        sleep 2
        while $(ps aux | grep -v 'grep' | grep "$thepid" &>/dev/null); do
            if [[ $num -gt 97 ]] ; then num=$(( num-1 )); fi
            showprogress $num $((num+1))
            num=$((num+1))
        done
        showprogress 99 100 3 3
    done  | whiptail --backtitle "$backmessage" --title "Progress Gauge" --gauge "$message" 6 70 0
}
# ------------------------------------------------------------------------------------------------------- #
calculate(){
    logfile="/tmp/fifo.tmp"
    length=2
    [[ -f $logfile ]] && rm $logfile
    echo "=== START ===" &>$logfile
    for ((i=0; i<=$length; i+=1))
	do
        echo "$i:" &>>$logfile
        date +"%D::%N" &>>$logfile
    done
    echo "=== END ===" &>>$logfile
}
# ------------------------------------------------------------------------------------------------------- #
