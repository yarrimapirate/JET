#!/bin/sh

#  112dg.sh

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.


chmod +x ./adb 
chmod +x ./fastboot 
chmod +x ./emmc_recovery
#chmod +x ./getbrickdrive.sh

clear

echo  "Script for HTC EVO 4G LTE bootloader downgrade to v1.12."
echo  ""
echo  "This script will put backup critical partition data and then put your phone"
echo  "into Qualcomm download mode (AKA Brick)."
echo  ""
echo  "Before running this script, you should have TWRP loaded onto your phone."
echo  "This script requires that you are root (sudo) on the linux host (not the "
echo  "phone).  If you need to, please press Ctrl-C to exit and run this script "
echo  "as root.  Plug your phone in via USB and ensure both USB debugging and "
echo  "fastboot are enabled."
echo ""

read -p "Press Enter to continue..." p

echo  ""
echo  "Preparing..."
./adb kill-server > /dev/null
./adb start-server > /dev/null

clear
echo  "Phase 1"
echo  ""
echo  "This phase backs up /dev/mmcblk0p4 from your phone to this machine.  In" 
echo  "addition, we will fetch your IMEI from the phone and use it to create an"
echo  "additional partition 4 replacement to use as a failsafe.  From our"
echo  "experience, as long as you have a valid partition 4 file (your backup" 
echo  "or the failsafe) it is not possible to irrevocably brick your device."
echo  ""
echo  "Please stand by..."
echo  ""
echo  "Rebooting to bootloader..."
echo  ""

./adb reboot bootloader

./fastboot getvar imei 2> imei2.txt				# Get IMEI from phone
echo  "Getting IMEI value..."
echo ""

echo  "Building failsafe P4 file..."
echo ""

cat imei2.txt | grep "imei:" | sed s/"imei: "// > imei.txt	# Filter output to just number
dd if=blankp4 bs=540 count=1 > ./fsp4 2> /dev/null		# First part of our failsafe P4 file
dd if=imei.txt bs=15 count=1 >> ./fsp4 2> /dev/null		# Add IMEI
dd if=blankp4 bs=555 skip=1 >> ./fsp4 2> /dev/null		# Last part

rm imei.txt					# Cleanup
rm imei2.txt

echo  "Success.  Rebooting phone."
echo ""

./fastboot reboot 2> /dev/null
./adb kill-server > /dev/null
./adb wait-for-device > /dev/null

echo  "Rebooting to recovery..."
echo ""

./adb reboot recovery
sleep 30
./adb kill-server > /dev/null
./adb start-server > /dev/null

echo  "Pulling /dev/block/mmcblk0p4 backup from phone..."
echo  ""

./adb shell "dd if=/dev/block/mmcblk0p4 of=/sdcard/bakp4"  	#  Copy P4 data to internal storage
./adb pull /sdcard/bakp4 ./bakp4				#  Pull file from internal storage to local machine

read -p "Press Enter to continue..." p

clear

echo "Phase 2"
echo ""
echo  "Now that we have backups, we're going to intentionally corrupt the" 
echo  "data on /dev/block/mmcblk0p4.  This will cause the phone to enter"
echo  "Qualcomm download mode (or brick if you prefer)."
echo  ""
echo  "THE SCRIPT CURRENTLY ENDS HERE SO THIS IS A ONE WAY STREET!!"
echo  ""
echo  "It is strongly advised that you verify the presence of the files fsp4"
echo  "and bakp4 in your working directory before continuing.  These are "
echo  "critical in restoring your phone to operational status.  Do this in"
echo  "another terminal window or in file manager."
echo  ""
echo  "LAST CHANCE.  If you need to exit this script press Ctrl-C now!"
echo  ""

read -p  "Press Enter to continue..." p

echo ""
echo "Corrupting /dev/block/mmcblk0p4..."

./adb push ./killp4 /sdcard										# Load corrupt p4 file onto internal storage
./adb shell "dd if=/sdcard/killp4 of=/dev/block/mmcblk0p4"		# Flash corrupt p4 file
./adb shell "rm /sdcard/killp4"									# Clean up
./adb reboot													# Complete force QDL

echo ""
echo "Success."
echo ""
echo ""

echo "Your phone should now appear to be off, with no charging light on."
echo "You should now proceed with the steps listed on post 106 of the"
echo "XDA thread starting after the blue *POOF*"
echo ""


lastdrive=$(ls -r /dev/sd? | sed 's\/dev/sd\\' | dd bs=1 count=1 2> /dev/null)	# Get all current /dev/sd* and filter to single letter of last drive
ldascii=$(printf '%d\n' "'$lastdrive")											# Convert letter to ASCII value
bdascii=$((ldascii+1))															# Increment ASCII Value, store in new variable
brickdrive=$(printf \\$(printf '%03o' $bdascii))								# Convert brick drive ASCII value to character, store for later use
printf "Your bricked phone should be accessible at /dev/sd$brickdrive\n\n"		# Print variable (testing)


sudo modprobe -r qcserial							
sudo mknod /dev/ttyUSB0 c 188 0

