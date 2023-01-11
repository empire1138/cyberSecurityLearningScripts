#!/bin/bash 

#trying out building a menu do basic things

clear
echo "
Please Select one of the following Options 

1.Display System Information
2.Display Disk Space
3.Display Home Space Utilization
0. Quit
"

read -p "Enter Selection [0-3]"

if [[ "$REPLY" =~ ^[0-3]$ ]]; then
        if [["$REPLY" == 0 ]]; then 
            echo "Program terminated."
            exit
        fi 
        if [["$REPLY" == 1 ]]; then
            echo "Hostname: $HOSTNAME"
            uptime 
            exit
        fi
        if [["$REPLY" == 2 ]]; then 
            df -h 
            exit
        fi
        if [["$REPLY" == 3 ]]; then
            if [["$id -u" -eq 0 ]]; then
                echo "Home Space Utilization (All Users)"
                du -sh /home/*
            else
                echo "Home Space Utilization ($USER)"
                du -sh "$HOME"
            fi
            exit
        fi
else 
    echo "Invaild Entry" >&2
    exit 1
fi