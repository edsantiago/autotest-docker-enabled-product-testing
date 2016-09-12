#!/bin/bash

logecho() {
    # Only send output to log file

    echo "$@" >> "$OUTPUTLOG"
}

teeecho() {
    # Send output to stdout + log in file

    # For some reason using tee strips newlines to stdout
    logecho "$@"
    echo "$@" > /dev/stderr
}

scrapetable() {
    # Scrapes the nova output table into $DELIM separated values

    grep -v -- '---' | \
    tr -d '[:blank:]' | \
    # Some cell values contain commas
    awk -F '|' -r -e \
        '/|/{ for (idx=2; idx<NF; idx++) printf "%s'$DELIM'", $idx; print "" }' | \
    # The first line contains column headers, ignore them
    tail -n +2
}

headfield() {
    # Output column $2 from first row of $DELIM separated value $1

    echo "$1" | head -1 | awk -F "$DELIM" -r -e '{print $'$2'}' | tr -d '"'
}

vmexists() {
    # Return 0 if a VM named $1 exists and is reachable by IP
    # and send IP address to stdout.  Return non-zero otherwise

    OUTPUT=$(nova list --name ".*$1.*" | scrapetable)
    NAME=$(headfield "$OUTPUT" 2)
    STATUS=$(headfield "$OUTPUT" 3)
    NETWORKS=$(headfield "$OUTPUT" 6)
    if [ -n "$OUTPUT" ]
    then
        logecho "
vmexists NAME: $NAME
vmexists STATUS: $STATUS
vmexists NETWORKS: $NETWORKS
"
    fi

    if [ -z "$OUTPUT" ]
    then
        logecho "No vm named $1 found"
        return 1
    fi
    IPLIST=$(echo "$NETWORKS" | cut -d "=" -f 2 | tr "," " " )
    if [ -z "$IPLIST" ]
    then
        FIRSTLINE=$(echo "$OUTPUT" | head -1)
        logecho "No IP addresses found in: \"$FIRSTLINE\""
    fi
    for IPADDR in $IPLIST
    do
        # two dns timeouts plus one second == 13
        if ping -q -w 13 -c 1 $IPADDR >> $OUTPUTLOG
        then
            echo "$IPADDR"
            logecho "vmexists IP $IPADDR pinged successfully"
            return 0  # Received reply
        fi
    done
    return 2  # No replies
}
