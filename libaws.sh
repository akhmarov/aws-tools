#!/usr/bin/env bash

# ------------------------------------------------------------------------------
#
# Amazon Web Services - API Wrapper Library
#
# Version:  1.0
# Date:     June 2012
# Author:   Vladimir Akhmarov
#
# Description:
#   This script is a collection of AWS API functions wrapped up with various
#   checks and limits. Script expects to find EC2_PRIVATE_KEY, EC2_CERT and
#   EC2_REGION environment variables to be properly set. Look for the AWS Guide
#   to setup this ones. Partially covered topics: INSTANCE, SNAPSHOT, VOLUME
#
# ------------------------------------------------------------------------------

AWS_AUTO_SCALING_HOME="/opt/aws/apitools/as"
AWS_CLOUDWATCH_HOME="/opt/aws/apitools/mon"
AWS_ELB_HOME="/opt/aws/apitools/elb"
AWS_IAM_HOME="/opt/aws/apitools/iam"
AWS_PATH="/opt/aws"
AWS_RDS_HOME="/opt/aws/apitools/rds"
EC2_AMITOOL_HOME="/opt/aws/amitools/ec2"
EC2_AUTH="--private-key $EC2_PRIVATE_KEY --cert $EC2_CERT --region $EC2_REGION"
EC2_HOME="/opt/aws/apitools/ec2"
JAVA_HOME="/usr/lib/jvm/jre"
PATH="$PATH:/opt/aws/bin"

export AWS_AUTO_SCALING_HOME
export AWS_CLOUDWATCH_HOME
export AWS_ELB_HOME
export AWS_IAM_HOME
export AWS_PATH
export AWS_RDS_HOME
export EC2_AMITOOL_HOME
export EC2_AUTH
export EC2_HOME
export JAVA_HOME
export PATH

USED_TOOLS=(
    'ec2-describe-instances'
    'ec2-start-instances'
    'ec2-stop-instances'
    'ec2-create-snapshot'
    'ec2-delete-snapshot'
    'ec2-describe-snapshots'
    'ec2-attach-volume'
    'ec2-create-volume'
    'ec2-delete-volume'
    'ec2-detach-volume'
    'ec2-describe-volumes'
    'ec2-version'
)

# ------------------------------------------------------------------------------

#
# Function: libaws_check
#
# Arguments:
#   -none-
#
# Returns:
#   -none-
#
# Description:
#   Function checks the presence of every AWS API tool that is used in this
#   library version. If the tool will be found it will be hashed in BASH
#   internal structures to speed up access to the executable. If at least one
#   tool is missing the program will be terminated immediately. If selected
#   private key or certificate files are missing an error will be risen too. If
#   environmental variables EC2_CERT, or EC2_PRIVATE_KEY, or EC2_REGION will be
#   empty the script will be terminated with error also
#

function libaws_check
{
    if [ -z "$EC2_CERT" ] || [ -z "$EC2_PRIVATE_KEY" ] || [ -z "$EC2_REGION" ]; then
        echo "ERROR: $FUNCNAME -- Missing authentication data" >&2
        exit 1
    fi

    for TOOL in ${USED_TOOLS[*]}; do
        hash "$TOOL" >/dev/null 2>&1
        if [ $? -eq 1 ]; then
            echo "ERROR: $FUNCNAME -- AWS API tool $TOOL not found" >&2
            exit 1
        fi
    done

    ec2-version | grep 'Not found' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "ERROR: $FUNCNAME -- Private key of certificate file not found" >&2
        exit 1
    fi
}

# ------------------------------------------------------------------------------

#
# Function: libaws_instance_get_id
#
# Arguments:
#   $1 -- Filter string [OPTIONAL]
#
# Returns:
#   Array
#
# Description:
#   Function lists all instance IDs with name prefix defined in argument $1
#

function libaws_instance_get_id
{
    if [ $# -eq 1 ] && [ "x$1" != 'x' ]; then
        ec2-describe-instances $EC2_AUTH --filter $1 | grep INSTANCE | cut --fields=2
    else
        ec2-describe-instances $EC2_AUTH | grep INSTANCE | cut --fields=2
    fi
}

#
# Function: libaws_instance_get_name
#
# Arguments:
#   $1 -- Filter string [OPTIONAL]
#
# Returns:
#   Array
#
# Description:
#   Function lists all instance names with prefix defined in argument $1
#

function libaws_instance_get_name
{
    if [ $# -eq 1 ] && [ "x$1" != 'x' ]; then
        ec2-describe-instances $EC2_AUTH --filter $1 | grep TAG | cut --fields=5
    else
        ec2-describe-instances $EC2_AUTH | grep TAG | cut --fields=5
    fi
}

#
# Function: libaws_instance_get_zone
#
# Arguments:
#   $1 -- Filter string [OPTIONAL]
#
# Returns:
#   Array
#
# Description:
#   Function lists all instance availability zones with prefix defined in
#   argument $1
#

function libaws_instance_get_zone
{
    if [ $# -eq 1 ] && [ "x$1" != 'x' ]; then
        ec2-describe-instances $EC2_AUTH --filter $1 | grep INSTANCE | cut --fields=12
    else
        ec2-describe-instances $EC2_AUTH | grep INSTANCE | cut --fields=12
    fi
}

#
# Function: libaws_instance_start
#
# Arguments:
#   $1 -- Instance ID
#
# Returns:
#   -none-
#
# Description:
#   Function starts instance ID defined in argument $1
#

function libaws_instance_start
{
    if [ $# -ne 1 ] || [ "x$1" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    ec2-start-instances $EC2_AUTH $1 >/dev/null 2>&1
}

#
# Function: libaws_instance_stop
#
# Arguments:
#   $1 -- Instance ID
#
# Returns:
#   -none-
#
# Description:
#   Function stops instance ID defined in argument $1
#

function libaws_instance_stop
{
    if [ $# -ne 1 ] || [ "x$1" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    ec2-stop-instances $EC2_AUTH $1 >/dev/null 2>&1
}

#
# Function: libaws_instance_wait
#
# Arguments:
#   $1 -- Instance ID
#   $2 -- Expected instance status
#
# Returns:
#   -none-
#
# Description:
#   Function wait while status of instance ID define in argument $1 becomes as
#   defined in argument $2
#

function libaws_instance_wait
{
    if [ $# -ne 2 ] || [ "x$1" == 'x' ] || [ "x$2" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    while true; do
        local STATUS=$(ec2-describe-instances $EC2_AUTH | grep INSTANCE | grep $1 | cut --fields=6)
        sleep 5
        [ "$STATUS" == "$2" ] || break
    done
}

# ------------------------------------------------------------------------------

#
# Function: libaws_snapshot_create
#
# Arguments:
#   $1 -- Instance ID
#   $2 -- Volume ID
#   $3 -- Volume Name
#   $4 -- Serial number
#
# Returns:
#   -none-
#
# Description:
#   Function creates snapshot for volume ID defined in argument $2 of instance
#   ID defined in argument $1. The description field for new snapshot consists
#   of the constant string, instance ID, volume name defined in argument $3 and
#   serial number defined in argument $4
#

function libaws_snapshot_create
{
    if [ $# -ne 4 ] || [ "x$1" == 'x' ] || [ "x$2" == 'x' ] || [ "x$3" == 'x' ] || [ "x$4" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    ec2-create-snapshot $EC2_AUTH --description "Automated backup :: $1 :: $3 :: $4" $2 >/dev/null 2>&1
}

#
# Function: libaws_snapshot_delete
#
# Arguments:
#   $1 -- Snapshot ID
#
# Returns:
#   -none-
#
# Description:
#   Function deletes snapshot with ID defined in argument $1
#

function libaws_snapshot_delete
{
    if [ $# -ne 1 ] || [ "x$1" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    ec2-delete-snapshot $EC2_AUTH $1 >/dev/null 2>&1
}

#
# Function: libaws_snapshot_get_id
#
# Arguments:
#   $1 -- Instance ID
#   $2 -- Volume ID or serial
#
# Returns:
#   Array
#
# Description:
#   Function lists all backup snapshot IDs for volume ID defined in argument $2
#   of instance ID defined in argument $1. Instead of volume ID the search can
#   be made by serial field
#

function libaws_snapshot_get_id
{
    if [ $# -ne 2 ] || [ "x$1" == 'x' ] || [ "x$2" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    ec2-describe-snapshots $EC2_AUTH | grep "Automated backup :: $1" | grep $2 | cut --fields=2
}

#
# Function: libaws_snapshot_get_name
#
# Arguments:
#   $1 -- Instance ID
#   $2 -- Volume ID
#
# Returns:
#   Array
#
# Description:
#   Function lists all volume names saved in backup snapshot for volume ID
#   defined in argument $2 of instance ID defined in argument $1
#

function libaws_snapshot_get_name
{
    if [ $# -ne 2 ] || [ "x$1" == 'x' ] || [ "x$2" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    # TODO: check!
    ec2-describe-snapshots $EC2_AUTH | grep "Automated backup :: $1" | grep $2 | cut --fields=9-
}

#
# Function: libaws_snapshot_get_rdate
#
# Arguments:
#   $1 -- Instance ID
#
# Returns:
#   Array
#
# Description:
#   Function lists all backup snapshot dates in ascending chronological order
#   for root volume of instance ID defined in argument $1
#

function libaws_snapshot_get_rdate
{
    if [ $# -ne 1 ] || [ "x$1" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    ec2-describe-snapshots $EC2_AUTH | grep "Automated backup :: $1 :: /dev/sda1" | grep 'completed' | cut --fields=5 | sort
}

#
# Function: libaws_snapshot_get_rserial
#
# Arguments:
#   $1 -- Instance ID
#   $2 -- Snapshot date
#
# Returns:
#   String
#
# Description:
#   Function extracts snapshot's serial of root volume for instance ID defined
#   in argument $1 made on date defined in argument $2
#

function libaws_snapshot_get_rserial
{
    if [ $# -ne 2 ] || [ "x$1" == 'x' ] || [ "x$2" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    ec2-describe-snapshots $EC2_AUTH | grep "Automated backup :: $1 :: /dev/sda1" | grep 'completed' | grep $2 | awk '{print $NF}'
}

# ------------------------------------------------------------------------------

#
# Function: libaws_volume_attach
#
# Arguments:
#   $1 -- Instance ID
#   $2 -- Volume ID
#   $3 -- Volume name
#
# Returns:
#   -none-
#
# Description:
#   Function attaches volume ID defined in argument $2 to instance ID defined in
#   argument $1 with volume name defined in argument $3
#

function libaws_volume_attach
{
    if [ $# -ne 3 ] || [ "x$1" == 'x' ] || [ "x$2" == 'x' ] || [ "x$3" == 'x' ] ; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    ec2-attach-volume $EC2_AUTH $2 --instance $1 --device $3 >/dev/null 2>&1
}

#
# Function: libaws_volume_create
#
# Arguments:
#   $1 -- Snapshot ID
#   $2 -- Availability zone
#
# Returns:
#   String
#
# Description:
#   Function creates volume from snapshot ID defined in argument $1. The volume
#   is created in availability zone defined in argument $2. The volume ID of the
#   new EBS volume is returned to user
#

function libaws_volume_create
{
    if [ $# -ne 2 ] || [ "x$1" == 'x' ] || [ "x$2" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    echo $(ec2-create-volume $EC2_AUTH --snapshot $1 --availability-zone $2 2>/dev/null | cut --fields=2)
}

#
# Function: libaws_volume_delete
#
# Arguments:
#   $1 -- Volume ID
#
# Returns:
#   -none-
#
# Description:
#   Function volume ID define in argument $1
#

function libaws_volume_delete
{
    if [ $# -ne 1 ] || [ "x$1" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    ec2-delete-volume $EC2_AUTH $1 >/dev/null 2>&1
}

#
# Function: libaws_volume_detach
#
# Arguments:
#   $1 -- Volume ID
#
# Returns:
#   -none-
#
# Description:
#   Function detaches volume ID defined in argument $1 from appropriate instance
#

function libaws_volume_detach
{
    if [ $# -ne 1 ] || [ "x$1" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    ec2-detach-volume $EC2_AUTH $1 >/dev/null 2>&1
}

#
# Function: libaws_volume_get_id
#
# Arguments:
#   $1 -- Instance ID
#
# Returns:
#   Array
#
# Description:
#   Function lists all volume IDs for instance ID defined in argument $1
#

function libaws_volume_get_id
{
    if [ $# -ne 1 ] || [ "x$1" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    ec2-describe-volumes $EC2_AUTH | grep $1 | cut --fields=2
}

#
# Function: libaws_volume_get_name
#
# Arguments:
#   $1 -- Instance ID
#
# Returns:
#   Array
#
# Description:
#   Function lists all volume names for instance ID defined in argument $1
#

function libaws_volume_get_name
{
    if [ $# -ne 1 ] || [ "x$1" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    ec2-describe-volumes $EC2_AUTH | grep $1 | cut --fields=4
}

#
# Function: libaws_volume_wait
#
# Arguments:
#   $1 -- Volume ID
#   $2 -- Expected volume status
#
# Returns:
#   -none-
#
# Description:
#   Function wait while status of volume ID define in argument $1 becomes as
#   defined in argument $2
#

function libaws_volume_wait
{
    if [ $# -ne 2 ] || [ "x$1" == 'x' ] || [ "x$2" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    while true; do
        local STATUS=$(ec2-describe-volumes $EC2_AUTH | grep ATTACHMENT | grep $1 | cut --fields=5)
        sleep 5
        [ "$STATUS" == "$2" ] || break
    done
}
