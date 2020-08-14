#!/bin/sh
####################################################
# Sysinfo.sh : Basic OS level process/system debugger
# Usage      : sh sysinfo.sh &
#
# Todo List  :
#              - Time: Duration: Counter
#              - CPU load tracker
#              - Os mem tracker
#              - Thread tracker
#              - File descriptor tracker
#              - Pid tracker (including time)
#              - Create alert for suspicious actions.
#              - Track zombie process.
#              - Track /proc/buddyinfo
#              - Track filesystem location(s) placed
#                memory.
#
# Date       : 18/04/2018
# Author     : @ Airties
#####################################################

# Colors
RESET='\033[0m'           # Text Reset
BLACK='\033[0;30m'        # Black
RED='\033[0;31m'          # Red
GREEN='\033[0;32m'        # Green
YELLOW='\033[0;33m'       # Yellow
BLUE='\033[0;34m'         # Blue
PURPLE='\033[0;35m'       # Purple
CYAN='\033[0;36m'         # Cyan
WHITE='\033[0;37m'        # White

# Colors Underline
UBLACK='\033[4;30m'       # Black
URED='\033[4;31m'         # Red
UGREEN='\033[4;32m'       # Green
UYELLOW='\033[4;33m'      # Yellow
UBLUE='\033[4;34m'        # Blue
UPURPLE='\033[4;35m'      # Purple
UCYAN='\033[4;36m'        # Cyan
UWHITE='\033[4;37m'       # White

HEADER=${UCYAN}
ERROR=$RED

## Variables
PID_LOCK=1024
COUNTER=0
TIME=`date`

echo -e "Starting $(basename $0) time: $TIME"

# Below function simply generate sleep functionality
# without tiggering /bin/sleep to avoid creating subprocess.
# Find a better way to handle stdin interrupt.

rsleep()
{
  read -t $1 -u 1
}

print_stats ()
{
        read _PID _COMM _STATE _PPID _PGRP _SESSION _TTY_NR _TPGID _FLAGS _MINFLT _CMINFLT _MAJFLT \
             _CMAJFLT _UTIME _STIME _CUTIME _CSTIME _PRIORITY _NICE _NUM_THREADS _IRETVALUE \
             _STARTTIME _VSIZE _RSS _RSSLIM _STARTCODE _ENDCODE _STARTSTACK _KSTKESP _KSTKEIP \
             _SIGNAL _BLOCKED _SIGIGNORE _SIGCATCH _WCHAN _NSWAP _CNSWAP _EXIT_SIGNAL _PROCESSOR \
             _RT_PRIORITY _POLICY _JUNK < /proc/$PID_TO_SHOW/stat

        case $_POLICY in
        "0")
                POLICY="TS"
                RTPRIO="- "
                ;;
        "1")
                POLICY="FF"
                RTPRIO=$_RT_PRIORITY
                ;;
        "2")
                POLICY="RR"
                RTPRIO=$_RT_PRIORITY
                ;;
        *)
                POLICY="??"
                RTPRIO="- "
        esac

        read _WCHAN < /proc/$PID_TO_SHOW/wchan
        echo -e "$_PID\t$_TID\t$POLICY\t$RTPRIO\t$_NICE\t$_STATE\t$_VSIZE\t$_RSS\t$_COMM\t$_WCHAN"
}

# Main Loop
while :
do
## Process
        echo -e "" ;echo -e "${HEADER}Process Info${RESET}"; echo -e "";
        for p in /proc/[0-9] /proc/[0-9][0-9] /proc/[0-9][0-9][0-9] /proc/[0-9][0-9][0-9][0-9] /proc/[0-9][0-9][0-9][0-9][0-9]; do
                PID=$(basename $p)
                if [ $PID -lt $PID_LOCK ]; then
                        continue
                fi
                # /proc/[pid]/status
                if [ -f /proc/$PID/status ]; then
                        NAME=$(awk '/^Name/ {print $2}' /proc/$PID/status)
                        PPID=$(awk '/^PPid/ {print $2}' /proc/$PID/status)
                        STATE=$(awk '/^State/ {print $2}' /proc/$PID/status)
                        VMPEAK=$(awk '/^VmPeak/ {print $2}' /proc/$PID/status)
                        VMSIZE=$(awk '/^VmRSS/ {print $2}' /proc/$PID/status)
                        THREADS=$(awk '/^Threads/ {print $2}' /proc/$PID/status)
                        NUMOFFD=`ls /proc/$PID/fd | wc -l`
                        PID_TO_SHOW=$PID
                        echo -e "${YELLOW}[ $PID ]: $NAME: $STATE${RESET}"
                        echo -e "\t${UGREEN} Process Info:${RESET}"
                        echo -e "\tNumOfThread(s): $THREADS"
                        echo -e "\tNumOfFd(s)    : $NUMOFFD"
                        echo -e "\tVMSIZE : $VMSIZE , VMPEAK: $VMPEAK"
                fi
                # /proc/[pid]/smaps
                if [ -f /proc/$PID/smaps ]; then
                        RSS=$(awk 'BEGIN {i=0} /^Rss/ {i = i + $2} END {print i}' /proc/$PID/smaps)
                        PSS=$(awk 'BEGIN {i=0} /^Pss/ {i = i + $2 + 0.5} END {print i}' /proc/$PID/smaps)
                        S_CLEAN=$(awk 'BEGIN {i=0} /^Shared_Clean/ {i = i + $2} END {print i}' /proc/$PID/smaps)
                        S_DIRTY=$(awk 'BEGIN {i=0} /^Shared_Dirty/ {i = i + $2} END {print i}' /proc/$PID/smaps)
                        P_CLEAN=$(awk 'BEGIN {i=0} /^Private_Clean/ {i = i + $2} END {print i}' /proc/$PID/smaps)
                        P_DIRTY=$(awk 'BEGIN {i=0} /^Private_Dirty/ {i = i + $2} END {print i}' /proc/$PID/smaps)
                        echo -e "\t${UGREEN} Memory Info:${RESET}"
                        echo -e "\tRSS: $RSS kB"
                        echo -e "\tPSS: $PSS kB"
                        echo -e "\tSHARED_CLEAN : $S_CLEAN ,SHARED_DIRTY :$S_DIRTY"
                        echo -e "\tPRIVATE_CLEAN: $P_CLEAN ,PRIVATE_DIRTY:$P_DIRTY"
                fi
                # /proc/[pid]/task/*
                echo -e "\t${UGREEN} Thread Info:${RESET}"
                for t in $p/task/*; do
                        TID=$(basename $t)
                        PID_TO_SHOW=$TID
                        print_stats
                done
        done

## Os
        TIME=`date`
        echo -e "" ;echo -e "${HEADER}System Info${RESET}";
        echo -e "${YELLOW}Counter: ${WHITE}$COUNTER${RESET}"
        echo -e "${YELLOW}Time   : ${WHITE}$TIME${RESET}"
        echo -e ""
        ## TODO: Add CPU usage tracker
        echo -e "${RED}Todo: Add CPU usage statistics here${RESET}"; echo -e ""

        if [ -f /proc/meminfo ]; then
                MEMTOTAL=$(awk '/^MemTotal/ {print $2}' /proc/meminfo)
                MEMFREE=$(awk '/^MemFree/ {print $2}' /proc/meminfo)
                HIGHTOTAL=$(awk '/^HighTotal/ {print $2}' /proc/meminfo)
                HIGHFREE=$(awk '/^HighFree/ {print $2}' /proc/meminfo)
                LOWTOTAL=$(awk '/^LowTotal/ {print $2}' /proc/meminfo)
                LOWFREE=$(awk '/^LowFree/ {print $2}' /proc/meminfo)
                VMALLOCTOTAL=$(awk '/^VmallocTotal/ {print $2}' /proc/meminfo)
                VMALLOCUSED=$(awk '/^VmallocUsed/ {print $2}' /proc/meminfo)
                CMATOTAL=$(awk '/^CmaTotal/ {print $2}' /proc/meminfo)
                CMAFREE=$(awk '/^CmaFree/ {print $2}' /proc/meminfo)
                echo -e "${PURPLE}MemUsed     :${WHITE} $((MEMTOTAL-MEMFREE))  ${PURPLE}MemFree    :${WHITE} $MEMFREE${RESET}"
                echo -e "${PURPLE}HighTotal   :${WHITE} $HIGHTOTAL  ${PURPLE}HighFree   :${WHITE} $HIGHFREE${RESET}"
                echo -e "${PURPLE}LowTotal    :${WHITE} $LOWTOTAL   ${PURPLE}LowFree    :${WHITE} $LOWFREE${RESET}"
                echo -e "${PURPLE}VmallocTotal:${WHITE} $VMALLOCTOTAL ${PURPLE}  VmallocUsed:${WHITE} $VMALLOCUSED${RESET}"
                echo -e "${PURPLE}CmaTotal    :${WHITE} $CMATOTAL  ${PURPLE}CmaFree    :${WHITE} $CMAFREE${RESET}"
        fi
        echo -e ""; echo -e "${YELLOW}Clearing pagecache/dentries/inodes${RESET}"; echo -e ""
        `echo 3 > /proc/sys/vm/drop_caches`
        if [ -f /proc/meminfo ]; then
                MEMTOTAL=$(awk '/^MemTotal/ {print $2}' /proc/meminfo)
                MEMFREE=$(awk '/^MemFree/ {print $2}' /proc/meminfo)
                HIGHTOTAL=$(awk '/^HighTotal/ {print $2}' /proc/meminfo)
                HIGHFREE=$(awk '/^HighFree/ {print $2}' /proc/meminfo)
                LOWTOTAL=$(awk '/^LowTotal/ {print $2}' /proc/meminfo)
                LOWFREE=$(awk '/^LowFree/ {print $2}' /proc/meminfo)
                VMALLOCTOTAL=$(awk '/^VmallocTotal/ {print $2}' /proc/meminfo)
                VMALLOCUSED=$(awk '/^VmallocUsed/ {print $2}' /proc/meminfo)
                CMATOTAL=$(awk '/^CmaTotal/ {print $2}' /proc/meminfo)
                CMAFREE=$(awk '/^CmaFree/ {print $2}' /proc/meminfo)
                echo -e "${PURPLE}MemUsed     :${WHITE} $((MEMTOTAL-MEMFREE))  ${PURPLE}MemFree    :${WHITE} $MEMFREE${RESET}"
                echo -e "${PURPLE}HighTotal   :${WHITE} $HIGHTOTAL  ${PURPLE}HighFree   :${WHITE} $HIGHFREE${RESET}"
                echo -e "${PURPLE}LowTotal    :${WHITE} $LOWTOTAL   ${PURPLE}LowFree    :${WHITE} $LOWFREE${RESET}"
                echo -e "${PURPLE}VmallocTotal:${WHITE} $VMALLOCTOTAL ${PURPLE}  VmallocUsed:${WHITE} $VMALLOCUSED${RESET}"
                echo -e "${PURPLE}CmaTotal    :${WHITE} $CMATOTAL  ${PURPLE}CmaFree    :${WHITE} $CMAFREE${RESET}"
        fi
## Filesystem
        echo -e "${HEADER}Filesystem${RESET}"
        echo -e "\t/       :" `du -s /`
        echo -e "\t/var    :" `du -s /var`
        echo -e "\t/tmp    :" `du -s /tmp`
        echo -e "\t/mnt    :" `du -s /mnt`
        echo -e "\t/opera  :" `du -s /opera`
        echo -e "\t/airties  :" `du -s /airties`


## REPORT: Evaluate changes here

        let "COUNTER=COUNTER+1";
        # Wait a bit..
        sleep 180
done


