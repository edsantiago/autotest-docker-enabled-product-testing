#!/bin/bash

# Brings up an openstack kommandir (if not found)
# using old nova command-line calls (widly available / compatible).
# Assumes all the proper authentication env. vars. are setup.

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
SSHKEY="$2"
USERDATA="$3"
KMNDRIMG="CentOS-7-x86_64-GenericCloud"
KMNDRFLAVOR="m1.micro"
DELIM="@"

. $(dirname $0)/nova_funcs.sh

showusage() {
    if [ -n "$1" ]
    then
        teeecho "Error: $1"
    fi
    teeecho "Usage: $(basename $0) <name hint> <key> [userdata]"
    teeecho
    teeecho "Where <name hint> is the new or existing kommandir name,"
    teeecho "and <key> is the full path to an ssh private key file."
    teeecho "Public key file assumed as the same, with .pub extension."
    teeecho "Optionally, userdata may specify the path to a file containing"
    teeecho "cloud-init userdata to use when provisioning the kommandir."
    teeecho "N/B: if userdata specified, then key will be ignored."
}

kommandir_yaml() {
    # Attempt to output ansible inventory YAML for kommandir
    # return 0 if successful and non-zero otherwise

    # Optional
    PREFER=$1

    KMNDRIP=$(vmexists "$KMNDRNAME")
    if [ "$?" -eq "0" ]
    then
        logecho "Found $KMNDRNAME at $KMNDRIP"

        if [ -n "$PREFER" ]
        then
            logecho "Using preferred IP $PREFER"
            KMNDRIP="$PREFER"
        fi

        # Don't assume which version of ansible is in use
        cat <<EOF
# hostname: $KMNDRNAME
inventory_hostname: kommandir
ansible_host: $KMNDRIP
ansible_ssh_host: $KMNDRIP
ansible_ssh_private_key_file: $SSHKEY
EOF
        return 0
    else
        return 1
    fi
}

provision_kommandir() {
    # Provision a new kommandir VM and return non-zero if unsuccessful

    KEYCONTENTS="$(head -1 ${SSHKEY}.pub)"
    if [ -z "$USERDATA" ] || [ ! -r "$USERDATA" ]
    then
        # cd $WORKSPACE above
        cat << EOF > userdata
#cloud-config
timezone: US/Eastern
disable_root: false
ssh_pwauth: True
ssh_import_id: [root]
ssh_authorized_keys:
    - $KEYCONTENTS
users:
    - name: root
      primary-group: root
      homdir: /root
      system: true
EOF
        USERDATA="userdata"
    fi
    logecho "provision_kommandir userdata: $USERDATA"
    logecho "$(cat $USERDATA)"
    logecho "..."
    # Polling mode guarantees VM is in "BUILD" state where IP can be assigned
    OUTPUT=$(nova boot --flavor $KMNDRFLAVOR \
                       --image $KMNDRIMG \
                       --user-data $USERDATA \
                       --poll \
                       $KMNDRNAME)
    logecho -e "nova boot output:\n$OUTPUT"
    return $?
}

echo_unassigned() {
    # Loop over each line in $1, stopping and
    # echoing column 2 (IP) if column 3 (assignment) is '-'

    while read ROW
    do
        # This will be a "-" when unassigned
        ASSIGNMENT=$(headfield "$ROW" 3)
        if [ "$ASSIGNMENT" == "-" ]
        then
            echo $(headfield "$ROW" 2)
            break
        fi
    done
}

first_pubip() {
    # Return 0 and echo the first available public ip
    # otherwise return 1 if none
    AVAILABLE=$(nova floating-ip-list | scrapetable | echo_unassigned)
    if [ -n "$AVAILABLE" ]
    then
        logecho "first_pubip found $AVAILABLE"
        echo $AVAILABLE
        return 0
    else
        return 1
    fi
}


##### Main #####

if [ "$#" -lt "2" ]
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
elif [ ! -r "$SSHKEY" ]
then
    teeecho $(showusage "Couldn't read ssh key file: \"$SSHKEY\"")
    exit 7
elif [ ! -r "${SSHKEY}.pub" ]
then
    teeecho $(showusage "Couldn't read ssh key file: \"${SSHKEY}.pub\"")
    exit 13
fi


# Splats YAML to stdout when successful
if kommandir_yaml
then
    exit 0
else
    OUTPUT=$(provision_kommandir)

    if [ "$?" -ne "0" ]
    then
        teeecho "Error provisioning kommandir:"
        teeecho "$OUTPUT"
        exit 8
    fi

    # Time of IP allocate != time of associate, assume concurrency!

    POOLS=$(nova floating-ip-pool-list | scrapetable)
    NRPOOLS=$(echo "$POOLS" | wc -l)
    # Try three times for each available pool
    let "IPALLOCTRIES=NRPOOLS*3"

    for (( TRIES=0 ; TRIES<IPALLOCTRIES ; TRIES++ ))
    do
        logecho "Try #$[TRIES+1] of max $IPALLOCTRIES"
        AVAILABLE=$(first_pubip)

        if [ "$?" -ne "0" ] || [ -z "$AVAILABLE" ]
        then
            # Select pool based on try modulo number of pools
            let "POOL=TRIES%NRPOOLS"
            let "POOL++"  # zero based -> one based
            # Select only one
            POOL=$(echo "$POOLS" | tail -n +$POOL | head -1)
            POOL=$(headfield "$POOL" 1)

            if [ -z "$POOL" ]
            then
                teeecho "Error, empty pool encountered from:"
                teeecho "$POOLS"
                exit 12
            fi

            logecho "Creating new floating IP from $POOL"
            logecho $(nova floating-ip-create "$POOL")

            if [ "$?" -ne "0" ]
            then
                teeecho "Error creating new floating IP, quota exceeded?"
                exit 9
            fi

            continue  # If still available, try associating
        else
            logecho "Associating $AVAILABLE to $KMNDRNAME"
            logecho $(nova floating-ip-associate "$KMNDRNAME" "$AVAILABLE")
            if [ "$?" -eq "0" ]
            then
                GOTIP="$AVAILABLE"
                break
            else
                logecho "Association failed, deleting $AVAILABLE"
                logecho $(nova floating-ip-delete "$AVAILABLE")
                logecho "Trying next pool"
            fi

            # Allow small window for resources to become available
            sleep 1s
            continue  # try again
        fi
    done

    if [ -z "$GOTIP" ]
    then
        teeecho "Error creating/associating IP to \"$KMNDRNAME\", exceeded $IPALLOCTRIES"
        teeecho "Deleting $KMNDRNAME"
        # attempt to clean up (ignore failures)
        teeecho $(nova delete "$KMNDRNAME")
        exit 10
    fi

    # Splats YAML to stdout when successful
    if kommandir_yaml $GOTIP
    then
        exit 0
    else
        teeecho "Error contacting just provisioned \"$KMNDRNAME\" at $GOTIP"
        teeecho "Deleting $KMNDRNAME" | tee -a "$OUTPUTLOG"
        # attempt to clean up (ignore failures)
        teeecho $(nova delete "$KMNDRNAME")
        exit 11
    fi
fi
