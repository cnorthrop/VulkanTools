#!/bin/bash

# Copyright 2017 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#set -vex

default_target_abi=$(adb shell getprop ro.product.cpu.abi)

function printUsage {
   echo "Supported parameters are:"
   echo "    --serial <target device serial number>"
   echo "    --abi <abi to install>"
   echo
   echo "i.e. ${0##*/} --serial 01234567 \\"
   echo "              --abi arm64-v8a \\"
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
        --serial)
            # include the flag, because we need to leave it off if not provided
            serial="$2"
            serialFlag="-s $serial"
            shift 2
            ;;
        --abi)
            target_abi="$2"
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

echo serial = $serial

if [[ -z $serial ]]
then
    echo Please provide a serial number.
    echo
    printUsage
    exit 1
fi

if [[ $(adb devices) != *"$serial"* ]];
then
    echo Device not found: $serial
    echo
    printUsage
    exit 1
fi

if [[ -z $target_abi ]];
then
    echo Using default target_abi
    target_abi=$default_target_abi
fi
echo target_abi = $target_abi

function printLayerBuild() {
    echo "To build layers:"
    echo "./update_external_sources_android.sh"
    echo "./android-generate.sh"
    echo "ndk-build -j"
}

#
# If any parameter not found, print how to build it
#


#
# Check for required tools
#

adb_path=$(which adb)
if [[ $? == 0 ]];
then
    echo using $adb_path
else
    echo adb not found, exiting
    echo check your NDK for it and add to path
    exit 1
fi

#
# Ensure APKs can be traced
#

#
# Start up
#

# We want to halt on errors here
set -e

# Wake up the device
adb $serialFlag shell input keyevent "KEYCODE_MENU"
adb $serialFlag shell input keyevent "KEYCODE_HOME"

# possibly turn json file into a parameter
adb $serialFlag shell rm -f /sdcard/Android/tiny1.json

# remove any other files added during the run
#rm -f $package.$frame.vktrace.ppm

# Push the layer
adb $serialFlag shell mkdir -p /data/local/debug/vulkan/
adb $serialFlag push libs/$target_abi/libVkLayer_device_simulation.so /data/local/debug/vulkan/

# device simulation parameters, ported from devsim_layer_test.sh
adb $serialFlag push ../tests/devsim_test1.json /sdcard/Android/devsim_test1.json
adb $serialFlag shell setprop debug.vulkan.devsim.filepath /sdcard/Android/tiny1.json
#adb $serialFlag shell setprop debug.vulkan.devsim.debugenable 1
#adb $serialFlag shell setprop debug.vulkan.devsim.exitonerror 1


adb $serialFlag shell setprop debug.vulkan.layer.1 VK_LAYER_LUNARG_device_simulation

adb $serialFlag shell cmd gpu vkjson #&> devsim.output


# clean up
adb $serialFlag shell setprop debug.vulkan.layer.1 '""'

# don't halt in the exit code below
set +e

# the rest is a quick port from vktracereplay.sh

if [ -t 1 ] ; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    NC=''
fi

# compare vkjson output against gold for the #lines of input
NUM_LINES=$(cut -f1 -d' ' <(wc -l devsim.output))
diff <(head -n ${NUM_LINES} ../tests/devsim_test1_gold.json) <(head -n ${NUM_LINES} devsim.output) >/dev/null
RES=$?
rm ${FILENAME_01_OUT}

if [ "$RES" -eq 0 ] ; then
   printf "$GREEN[  PASSED  ]$NC ${PGM}\n"
else
   printf "$RED[  FAILED  ]$NC file compare failed\n"
   printf "TEST FAILED\n"
   exit 1
fi

exit 0
