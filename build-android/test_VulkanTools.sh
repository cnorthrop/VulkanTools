#!/bin/bash

set -e

#
# Parse parameters
#

function printUsage {
   echo "Supported parameters are:"
   echo "    -p|--platform <platform> (optional)"
   echo "    -a|--abi <abim>"
   echo "    -s|--serial <target device serial number>"
   echo
   echo "i.e. ${0##*/} -p <platform> -a armeabi-v7a -s <serial number>"
   exit 1
}

if [[ $(($# % 2)) -ne 0 ]]
then
    echo Parameters must be provided in pairs.
    echo parameter count = $#
    echo
    printUsage
    exit 1
fi

while [[ $# -gt 0 ]]
do
    case $1 in
        -p|--platform)
            platform="$2"
            shift 2
            ;;
        -a|--abi)
            abi="$2"
            shift 2
            ;;
        -s|--serial)
            # include the flag, because we need to leave it off if not provided
            serial="$2"
            serialFlag="-s $serial"
            shift 2
            ;;
        -*)
            # unknown option
            echo Unknown option: $1
            echo
            printUsage
            exit 1
            ;;
    esac
done

echo platform = $platform
echo abi = $abi
echo serial = $serial


if [[ -z $abi ]]
then
    echo Please provide an ABI.
    echo
    printUsage
    exit 1
fi

if [[ -z $serial ]]
then
    echo Please provide a serial number.
    echo
    printUsage
    exit 1
fi

if [[ $(adb devices) != *"$serial"* ]]
then
    echo Device not found: $serial
    echo
    printUsage
    exit 1
fi

#
# Start up
#

# Grab our Android test mutex
# Wait for any existing test runs on the devices

# Blow away the lock if tests run too long, avoiding infinite loop
lock_seconds=1200                                # Duration in seconds.
lock_end_time=$(( $(date +%s) + lock_seconds ))  # Calculate end time.

until mkdir /var/tmp/VkLayerValidationTests.$serial.lock
do
    sleep 5
    echo "Waiting for existing Android test to complete on $serial"

    if [ $(date +%s) -gt $lock_end_time ]
    then
        echo "Lock timeout reached: $lock_seconds seconds"
        echo "Deleting /var/tmp/VkLayerValidationTests.$serial.lock"
        rm -r /var/tmp/VkLayerValidationTests.$serial.lock
    fi
done

# Clean up our lock on any exit condition
function finish {
   rm -r /var/tmp/VkLayerValidationTests.$serial.lock
}
trap finish EXIT

# Clear the log
adb $serialFlag logcat -c

# Call test script
./vktracereplay.sh \
 --serial $serial \
 --abi $abi \
 --apk ../demos/android/cube-with-layers/bin/NativeActivity-debug.apk \
 --package com.example.CubeWithLayers \
 --activity android.app.NativeActivity \
 --frame 100

exit $?
