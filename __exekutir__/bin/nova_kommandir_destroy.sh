#!/bin/bash

# Brings down an openstack kommandir, all errors represented as warnings

if [ -n "$WORKSPACE" ]
then
    cd $WORKSPACE
fi

# Unless there's about to be a non-zero exit, logs everything
# because stdout will be used by caller
OUTPUTLOG="$(basename $0).log"

if [ -f "$OUTPUTLOG" ]
then
    rm -f "$OUTPUTLOG"
fi

KMNDRNAME="$1"
DELIM="@"

. $(dirname $0)/nova_funcs.sh

showusage() {
    if [ -n "$1" ]
    then
        teeecho "Error: $1"
    fi
    teeecho "Usage: $(basename $0) <name hint>"
    teeecho ""
    teeecho "Where <name hint> is the kommandir name, if it exists."
}

##### Main #####

if [ "$#" -lt "1" ]
then
    teeecho $(showusage "Not enough arguments")
    exit 1
elif [ -z "$OS_AUTH_URL" ]
then
    teeecho $(showusage "Missing \$OS_AUTH_URL env. var.")
    exit 2
elif [ -z "$OS_USERNAME" ]
then
    teeecho $(showusage "Missing \$OS_USERNAME env. var.")
    exit 4
elif [ -z "$OS_PASSWORD" ]
then
    teeecho $(showusage "Missing \$OS_PASSWORD env. var.")
    exit 5
elif [ -z "$OS_TENANT_NAME" ]
then
    teeecho $(showusage "Missing \$OS_TENANT_NAME env. var.")
    exit 3
elif ! which nova &>/dev/null
then
    teeecho $(showusage "Can't find nova command on path")
    exit 6
fi

OUTPUT=$(nova delete $KMNDRNAME 2>&1)

if [ "$?" -ne "0" ]
then
    teeecho "Warning: Error deleting kommandir:"
    teeecho "$OUTPUT"
else
    teeecho "$OUTPUT"
fi

# always!
exit 0
