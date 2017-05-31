#!/usr/bin/env bash

# ------------------------------------------------------------------------------
#
# Amazon Web Services - Backup Script
#
# Version:  1.0
# Date:     June 2012
# Author:   Vladimir Akhmarov
#
# Description:
#   This script walks through all instances with specified name prefix and makes
#   backups (with help of snapshots) of all attached volumes. All backup
#   snapshots have similar names "Automated backup :: INSTANCE_ID :: VOLUME_NAME
#   :: RANDOM_STRING". Backup snapshot storage is organized like a circular
#   buffer. So there will be no more than BACKUP_LEVEL snapshots for each
#   volume. If there is no space left in buffer the oldest snapshot will be
#   deleted.
#
#   For example:
#   Let there be 5 instances with 2 volumes each. And we set up backup task with
#   BACKUP_LEVEL to 7. So there will be 5 * 2 = 10 volumes total and 10 * 7 = 70
#   backup snapshots total
#
# ------------------------------------------------------------------------------

DEFAULT_BACKUP_LEVEL=10

function usage
{
    echo -e "\nUsage: aws-backup.sh -c CERT -k KEY -r REGION [-t SEARCH] [-l LEVEL]"
    echo -e ''
    echo -e 'Mandatory:'
    echo -e '  -c -- absolute path to EC2 certificate file'
    echo -e '  -k -- absolute path to EC2 private key file'
    echo -e '  -r -- region name of the EC2 instances'
    echo -e 'Optional:'
    echo -e '  -t -- name search template of the EC2 instances'
    echo -e '  -l -- backup level, number of last snapshots of each volume. There'
    echo -e '        will be 10 snapshots for each volume if nothing is specified'
    echo -e ''

    exit 1
}

while getopts ':c:k:r:t:l:' VAR; do
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
        l)
            BACKUP_LEVEL=$OPTARG
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

if [ -z "$BACKUP_LEVEL" ] || [[ "$BACKUP_LEVEL" != [0-9]* ]] || [ "$BACKUP_LEVEL" -le 0 ]; then
    BACKUP_LEVEL=$DEFAULT_BACKUP_LEVEL
fi

# ------------------------------------------------------------------------------
. $(dirname $0)/libaws.sh
. $(dirname $0)/libmisc.sh
# ------------------------------------------------------------------------------

libaws_check

#
# Get list of instances
#

INSTANCE_ID=( $(libaws_instance_get_id $SEARCH_TEMPLATE) )

echo -e "\nInstances total: ${#INSTANCE_ID[*]}"

for (( i=0; i<${#INSTANCE_ID[*]}; i++ ))
{
    SERIAL=$(libmisc_rng_hex 8)

    echo -e "\n  Instance ID: ${INSTANCE_ID[$i]}"

    #
    # Get list of instance volumes
    #

    VOLUME_ID=( $(libaws_volume_get_id ${INSTANCE_ID[$i]}) )
    VOLUME_NAME=( $(libaws_volume_get_name ${INSTANCE_ID[$i]}) )

    echo -e "  Attached volumes: ${#VOLUME_ID[*]}"

    for (( j=0; j<${#VOLUME_ID[*]}; j++ ))
    {
        echo -e "\n    Volume ID: ${VOLUME_ID[$j]}"

        #
        # Create snapshot
        #

        libaws_snapshot_create ${INSTANCE_ID[$i]} ${VOLUME_ID[$j]} ${VOLUME_NAME[$j]} $SERIAL

        #
        # Get list of volume snapshots
        #

        SNAPSHOT_ID=( $(libaws_snapshot_get_id ${INSTANCE_ID[$i]} ${VOLUME_ID[$j]}) )

        echo -e "    Backup snapshots: ${#SNAPSHOT_ID[*]}\n"

        #
        # Delete the oldest ones if too many snapshots
        #

        while [ ${#SNAPSHOT_ID[*]} -gt $BACKUP_LEVEL ]; do
            echo -e "      - deleting backup snapshot ${SNAPSHOT_ID[0]}"
            libaws_snapshot_delete ${SNAPSHOT_ID[0]}
            SNAPSHOT_ID=( $(libaws_snapshot_get_id ${INSTANCE_ID[$i]} ${VOLUME_ID[$j]}) )
        done

        echo -e "\n      Snapshot IDs: ${SNAPSHOT_ID[*]}"
    }
}
