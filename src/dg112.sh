#!/bin/sh

#  112dg.sh - yarrimapirate@XDA v0.1
#  
#  A script to aqutomate the force QDL process for downgrading HBoot to 1.12
#  on the HTC EVO 4G LTE.

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
chmod +x ./emmc_recover


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
echo  "This phase backs up /dev/block/mmcblk0p4 from your phone to this machine.  In" 
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
echo  ""
echo  "Rebooting..."

./adb reboot													# Complete force QDL

echo ""
echo "Success."
echo ""
echo ""
echo "Your phone should now appear to be off, with no charging light on."
echo ""
echo  "From here forward, DO NOT UNPLUG THE PHONE FROM THE USB CABLE!"
echo ""

read -p "Press Enter to continue..."

clear

# QDL device detection

lastdrive=$(ls -r /dev/sd? | sed 's\/dev/sd\\' | dd bs=1 count=1 2> /dev/null)	# Get all current /dev/sd* and filter to single letter of last drive
ldascii=$(printf '%d\n' "'$lastdrive")											# Convert letter to ASCII value
bdascii=$((ldascii+1))															# Increment ASCII Value, store in new variable
brickdrive=$(printf \\$(printf '%03o' $bdascii))								# Convert brick drive ASCII value to character, store for later use

echo  "Now we'll flash the 1.12 bootloader."
echo  ""
printf  "If this process hangs at \"Waiting for /dev/sd"$brickdrive"12...\"  Press and\n"
echo  "hold the power button on your phone for no less than 30 seconds and"
echo  "then release it.  The process should wake back up a few seconds afterwards."
echo  "Note that this process can take as long as 10 minutes to complete and you"
echo  "will see a lot of repetitive output from the recovery tool."

echo  ""
echo  "If this process fails to complete you will need to complete the manual steps"
echo  "using the post on XDA.  In that case, your bricked phone should be"
printf "accessible at /dev/sd$brickdrive\n\n"

sudo modprobe -r qcserial																	# Reset qcserial kernel module and clear old blocks
sudo mknod /dev/ttyUSB0 c 188 0																# Create block device for emmc_recover
sudo ./emmc_recover -f hboot_1.12.0000_signedbyaa.nb0 -d /dev/sd"$brickdrive"12 -c 24576	# Flash Signed 1.12 HBoot

echo  ""
echo  "Successfully loaded HBoot v1.12!"
echo  ""
read -p "Press Enter to continue..." p

clear

echo  "The final step is restoring your backup /dev/block/mmcblk0p4."
echo  ""
printf  "Once again, if this process hangs at \"Waiting for /dev/sd"$brickdrive"4...\"\n"
echo  "Press and hold the power button on your phone for no less than 30 seconds and"
echo  "then release it.  The process should wake back up a few seconds afterwards."
echo  ""
echo  "If this process fails to complete you will need to complete the manual steps"
echo  "using the post on XDA.  In that case, your bricked phone should be"
printf "accessible at /dev/sd$brickdrive\n\n"

sudo modprobe -r qcserial																	# Reset qcserial kernel module and clear old blocks
sudo mknod /dev/ttyUSB0 c 188 0																# Create block device for emmc_recover
sudo ./emmc_recover -f ./bakp4 -d /dev/sd"$brickdrive"4										# Flash backup p4 file

echo ""
echo  "Success!"
echo  ""
echo  "Your phone should now at least have a charging light on.  Some phones will"
echo  "immediately boot after restoration.  If yours doesn't, simply unplug the USB"
echo  "cable and hold your power button for a few seconds."
echo  ""
echo  "Enjoy HBoot 1.12!  You can now S-OFF with LazyPanda."
echo  ""