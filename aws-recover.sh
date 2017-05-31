#!/usr/bin/env bash

# ------------------------------------------------------------------------------
#
# Amazon Web Services - Recovery Script
#
# Version:  1.0
# Date:     June 2012
# Author:   Vladimir Akhmarov
#
# Description:
#   This script prints menu with available instances. When user selects one of
#   the instances to recover the script prints available dates to recover to.
#   When user selects one of the available dates the script creates new volumes
#   from snapshots done at selected date, stops selected instance, detaches all
#   volumes, attaches new volumes, starts instance and deletes old detached
#   volumes
#
# ------------------------------------------------------------------------------

function usage
{
    echo -e "\nUsage: aws-recover.sh -c CERT -k KEY -r REGION [-t SEARCH]"
    echo -e ''
    echo -e 'Mandatory:'
    echo -e '  -c -- absolute path to EC2 certificate file'
    echo -e '  -k -- absolute path to EC2 private key file'
    echo -e '  -r -- region name of the EC2 instances'
    echo -e 'Optional:'
    echo -e '  -t -- name search template of the EC2 instances'
    echo -e ''

    exit 1
}

while getopts ':c:k:r:t:' VAR; do
    case $VAR in
        c)
            EC2_CERT=$OPTARG
            ;;
        k)
            EC2_PRIVATE_KEY=$OPTARG
            ;;
        r)
            EC2_REGION=$OPTARG
            ;;
        t)
            SEARCH_TEMPLATE=$OPTARG
            ;;
        :)
            echo "ERROR: Option -$OPTARG requires an argument" >&2
            usage
            ;;
        \?)
            echo "ERROR: Invalid option -$OPTARG" >&2
            usage
            ;;
    esac
done

if [ $# -eq 0 ]; then
    usage
fi

# ------------------------------------------------------------------------------
. $(dirname $0)/libaws.sh
. $(dirname $0)/libmisc.sh
# ------------------------------------------------------------------------------

libaws_check

#
# Get list of instances, print the whole list and select one instance
#

INSTANCE_ID=( $(libaws_instance_get_id $SEARCH_TEMPLATE) )
INSTANCE_NAME=( $(libaws_instance_get_name $SEARCH_TEMPLATE) )
INSTANCE_ZONE=( $(libaws_instance_get_zone $SEARCH_TEMPLATE) )

if [ ${#INSTANCE_ID[*]} -eq 0 ]; then
    echo -e "\nERROR: None instances found" >&2
    exit 1
fi

libmisc_menu_print "${INSTANCE_NAME[*]}"
sel_inst=$(libmisc_menu_select ${#INSTANCE_NAME[*]})

if [ $sel_inst -eq 0 ]; then
    exit 0
else
    sel_inst=$(($sel_inst-1))
fi

#
# Get list of the instance backup dates, print it and select one date
#

SNAPSHOT_DATE=( $(libaws_snapshot_get_rdate ${INSTANCE_ID[$sel_inst]}) )

if [ ${#SNAPSHOT_DATE[*]} -eq 0 ]; then
    echo -e "\nERROR: None snapshots found" >&2
    exit 1
fi

libmisc_menu_print "${SNAPSHOT_DATE[*]}"
sel_date=$(libmisc_menu_select ${#SNAPSHOT_DATE[*]})

if [ $sel_date -eq 0 ]; then
    exit 0
else
    sel_date=$(($sel_date-1))
fi

echo -e "\nStarting recovery process ..."

#
# Select snapshots for recovery and create volume IDs from them
#

SNAPSHOT_SERIAL=$(libaws_snapshot_get_rserial ${INSTANCE_ID[$sel_inst]} ${SNAPSHOT_DATE[$sel_date]})
SNAPSHOT_ID=( $(libaws_snapshot_get_id ${INSTANCE_ID[$sel_inst]} $SNAPSHOT_SERIAL) )

for (( i=0; i<${#SNAPSHOT_ID[*]}; i++ ))
{
    VOLUME_ID_NEW[$i]=$(libaws_volume_create ${SNAPSHOT_ID[$i]} ${INSTANCE_ZONE[$sel_inst]})

    if [ -z "$VOLUME_ID_NEW[$i]" ]; then
        echo 'ERROR: Missing new volume ID' >&2
        exit 1
    fi

    libaws_volume_wait ${VOLUME_ID_NEW[$i]} 'available'
}

#
# Stop instance
#

libaws_instance_stop ${INSTANCE_ID[$sel_inst]}
libaws_instance_wait ${INSTANCE_ID[$sel_inst]} 'stopped'

#
# Get instance's current volume names
# Get instance's current volume IDs and detach them
#

VOLUME_NAME=( $(libaws_volume_get_name ${INSTANCE_ID[$sel_inst]}) )
VOLUME_ID_OLD=( $(libaws_volume_get_id ${INSTANCE_ID[$sel_inst]}) )

if [ ${#VOLUME_ID_NEW[*]} -ne ${#VOLUME_ID_OLD[*]} ]; then
    echo 'ERROR: Missing backup snapshots' >&2
    exit 1
fi

for (( i=0; i<${#VOLUME_ID_OLD[*]}; i++ ))
{
    libaws_volume_detach ${VOLUME_ID_OLD[$i]}
    libaws_volume_wait ${VOLUME_ID_OLD[$i]} 'available'
}

for (( i=0; i<${#VOLUME_ID_NEW[*]}; i++ ))
{
    libaws_volume_attach ${INSTANCE_ID[$sel_inst]} ${VOLUME_ID_NEW[$i]} ${VOLUME_NAME[$i]}
    libaws_volume_wait ${VOLUME_ID_NEW[$i]} 'in-use'
}

#
# Start instance
#

libaws_instance_start ${INSTANCE_ID[$sel_inst]}

#
# Delete old volumes
#

for (( i=0; i<${#VOLUME_ID_OLD[*]}; i++ ))
{
    libaws_volume_delete ${VOLUME_ID_OLD[$i]}
}

echo -e "\nDone!"
