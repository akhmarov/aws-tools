#!/usr/bin/env bash

# ------------------------------------------------------------------------------
#
# Amazon Web Services - Misc Library
#
# Version:  1.0
# Date:     June 2012
# Author:   Vladimir Akhmarov
#
# Description:
#   This script is a collection of miscellaneous routines to make using AWS API
#   much easier.
#
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------

#
# Function: libmisc_rng_hex
#
# Arguments:
#   $1 -- Number of symbols [OPTIONAL]
#
# Returns:
#   String
#
# Description:
#   Function generates random HEX number with length defined in argument $1. If
#   total length is not defined the function will generate 16-symbol string by
#   default
#

function libmisc_rng_hex
{
    if [ $# -eq 1 ] && [ "${1+x}" != 'x' ]; then
        hexdump -v -n $1 -e '1/1 "%02x"' /dev/urandom
    else
        hexdump -v -n 16 -e '1/1 "%02x"' /dev/urandom
    fi
}

# ------------------------------------------------------------------------------

#
# Function: libmisc_menu_print
#
# Arguments:
#   $1 -- Array
#
# Returns:
#   -none-
#
# Description:
#   Function prints menu from a single column array and prefixes each row with
#   it's appropriate index value started from 1. The first value will always be
#   "0 --- Exit"
#

function libmisc_menu_print
{
    if [ $# -ne 1 ] || [ "x$1" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    echo -e "\n 0 --- Exit"

    ARRAY=( $1 )
    for (( i=0; i<${#ARRAY[*]}; i++ ))
    {
        echo "" $(($i+1)) "--- ${ARRAY[$i]}"
    }

    echo -e ""
}

#
# Function: libmisc_menu_select
#
# Arguments:
#   $1 -- Maximum allowed number
#
# Returns:
#   Integer
#
# Description:
#   Function prints prompt string and awaits for user to input selected number.
#   Menu table is expected to contains value "0 --- Exit" always
#

function libmisc_menu_select
{
    if [ $# -ne 1 ] || [ "x$1" == 'x' ]; then
        echo "ERROR: $FUNCNAME -- Invalid input" >&2
        exit 1
    fi

    read -p "Select menu item: " SELECT

    if [ 0 -gt $SELECT ] || [ $SELECT -gt $1 ]; then
        echo "ERROR: $FUNCNAME -- Value out of range" >&2
        exit 1
    fi

    echo $SELECT
}
