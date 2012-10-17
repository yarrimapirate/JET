#!/bin/sh

#  dg112.sh - yarrimapirate@XDA v0.1 Alpha 2
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

if [ "$(whoami)" != 'root' ]; then
        printf "$0 requires root.  (sudo $0)\n"
        exit 1;
fi

#  Check for required files

if [ ! -e "./killp4" ]; then
	printf  "FATAL:  File killp4 missing.\n\n"
	exit 1
fi

if [ ! -e "./blankp4" ]; then
	printf  "FATAL:  File blankp4 missing.\n\n"
	exit 1
fi

if [ ! -e "./hboot_1.12.0000_signedbyaa.nb0" ]; then
	printf  "FATAL:  File hboot_1.12.0000_signedbyaa.nb0 missing.\n\n"
	exit 1
fi

if [ ! -e "./emmc_recover" ]; then
	printf  "FATAL:  File \'emmc_recover\' missing.\n\n"
	exit 1
fi

if [ ! -e "./adb" ]; then
	printf  "FATAL:  File \'adb\' missing.\n\n"
	exit 1
fi

if [ ! -e "./fastboot" ]; then
	printf  "FATAL:  File \'fastboot\' missing.\n\n"
	exit 1
fi

chmod +x ./adb 
chmod +x ./fastboot 
chmod +x ./emmc_recover

clear

printf  "Script for HTC EVO 4G LTE bootloader downgrade to v1.12.\n\n"
printf  "This script will put backup critical partition data and then put your phone\n"
printf  "into Qualcomm download mode (AKA Brick).\n\n"
printf  "Before running this script, you should have TWRP loaded onto your phone.\n"
printf  "Plug your phone in via USB and ensure both USB debugging and\n"
printf  "fastboot are enabled.\n\n"

read -p "Press Enter to continue..." p

printf  "\nPreparing...\n"

sleep 2
./adb kill-server > /dev/null
./adb start-server > /dev/null

printf  "Phase 1\n\n"
printf  "This phase backs up /dev/block/mmcblk0p4 from your phone to this machine.  In\n" 
printf  "addition, we will fetch your IMEI from the phone and use it to create an\n"
printf  "additional partition 4 replacement to use as a failsafe.  From our\n"
printf  "experience, as long as you have a valid partition 4 file (your backup\n" 
printf  "or the failsafe) it is not possible to irrevocably brick your device.\n\n"
printf  "Please stand by...\n\n"

printf  "Rebooting to bootloader...\n\n"

./adb reboot bootloader

printf  "Getting IMEI value...\n\n"

sleep 2
./fastboot getvar imei 2>&1 | grep "imei:" | sed s/"imei: "// > imei.txt	# Get IMEI from phone and store

printf  "Building failsafe P4 file...\n\n"

dd if=blankp4 bs=540 count=1 > ./fsp4 2> /dev/null		# First part of our failsafe P4 file
dd if=imei.txt bs=15 count=1 >> ./fsp4 2> /dev/null		# Add IMEI
dd if=blankp4 bs=555 skip=1 >> ./fsp4 2> /dev/null		# Last part

rm imei.txt												# Cleanup

s=$(stat -c %s "./fsp4")								# Get size of fsp4  (Should be exactly 1024 bytes)
if [ $s != 1024 ]; then									# Stop if size isn't right
	printf  "FATAL:  Failsafe P4 size mismatch.\n"
	exit 1
fi

printf  "Success.  Rebooting phone.\n\n"

./fastboot reboot 2> /dev/null
./adb kill-server > /dev/null
./adb wait-for-device > /dev/null

printf  "Rebooting to recovery...\n\n"

./adb reboot recovery
sleep 30
./adb kill-server > /dev/null
./adb start-server > /dev/null

printf  "Pulling /dev/block/mmcblk0p4 backup from phone...\n\n"

./adb shell dd if=/dev/block/mmcblk0p4 of=/sdcard/bakp4  				#  Copy P4 data to internal storage

internalbak=$("./adb shell if [ -e /sdcard/bakp4 ] ; then echo 1 ; fi")	#  Check for successful file creation on internal storage
if [ $internalbak != 1 ]; then
	printf  "FATAL:  Failure to create mmcblk0p4 backup on internal storage (/sdcard).\n\n"
	exit 1
fi

./adb shell dd if=/dev/block/mmcblk0p4 of=/sdcard2/bakp4  				#  Copy P4 data to external storage

sdcardbak=$("./adb shell if [ -e /sdcard2/bakp4 ] ; then echo 1 ; fi")	#  Check that SD Card Backup was made
if [ $sdcardbak != 1 ]; then
	printf  "WARNING: A backup of your Partition 4 was not made on the SD Card.\n"
	printf  "Is an SD Card in your phone? Is it full?\n"
	printf  "It's recommended that a backup is made on an SD Card.\n\n"
	printf  "You can continue without making a backup, but it's a good idea.\n"
	
	SDBackup(){
	printf  "Continue without SD Card backup? [Y]es or [N]o?"
		read BACKUP
		case $BACKUP in
		y | Y | yes | Yes) continue;;
		n | N | no | No) exit;;
		*) SDBackup;;
		esac
	}
./adb pull /sdcard/bakp4 ./bakp4							#  Pull file from internal storage to local machine

if [ -e ./bakp4 ]; then	
	continue												#  Did the bakp4 get created?
else
	printf  "FATAL:  Backup mmcblk0p4 creation failed.\n\n"
	exit 1
fi

s=0
s=$(stat -c %s ./bakp4)									#  Get size of bakp4  (Should be exactly 1024 bytes)
if [ $s != 1024 ]; then									#  Stop if size isn't right
	printf  "FATAL:  Backup mmcblk0p4, size mismatch on local disk.\n\n"
	exit 1
fi

printf  "/nSuccess./n/n/n"

printf  "Phase 2\n\n"
printf  "Now that we have backups, we're going to intentionally corrupt the\n" 
printf  "data on /dev/block/mmcblk0p4.  This will cause the phone to enter\n"
printf  "Qualcomm download mode (or brick if you prefer).\n\n"
printf  "It is strongly advised that you verify the presence of the files fsp4\n"
printf  "and bakp4 in your working directory before continuing.  These are\n"
printf  "critical in restoring your phone to operational status.  Do this in\n"
printf  "another terminal window or in file manager.\n\n"

FinalQ() {
printf  "Are you sure you would like to continue? Once started, this cannot\n"
printf  "be cancelled. [Y]es or [N]o?"
	read FINAL
	case $FINAL in
	y | Y | yes | Yes) continue;;
	n | N | no | No) exit;;
	*) FinalQ;;
	esac
}

printf  "\n\nDo NOT interrupt this process or reboot your computer.\n\n"
printf  "Corrupting /dev/block/mmcblk0p4...\n\n"

./adb push ./killp4 /sdcard										# Load corrupt p4 file onto internal storage

loadedkill = $(./adb shell "if [ -e /sdcard/killp4 ]; then echo 1; fi")
if [ $loadedkill != 1 ]; then
	printf  "FATAL:  Unable to load corrupt mmcblk0p4 file onto internal storage.\n\n"
	exit 1
fi

./adb shell "dd if=/sdcard/killp4 of=/dev/block/mmcblk0p4"		# Flash corrupt p4 file
./adb shell "rm /sdcard/killp4"									# Clean up

printf  "Rebooting...\n\n"

sleep 2
./adb reboot													# Complete force QDL

printf  "Success.\n\n\n"
printf  "Your phone should now appear to be off, with no charging light on.\n\n"

read -p "Press Enter to continue..."


# QDL device detection
lastdrive=$(ls -r /dev/sd? | sed 's\/dev/sd\\' | dd bs=1 count=1 2> /dev/null)	# Get all current /dev/sd* and filter to single letter of last drive
ldascii=$(printf '%d\n' "'$lastdrive")											# Convert letter to ASCII value
bdascii=$((ldascii+1))															# Increment ASCII Value, store in new variable
brickdrive=$(printf \\$(printf '%03o' $bdascii))								# Convert brick drive ASCII value to character, store for later use

CheckBrick() {
	printf  "\nDetecting bricked device...  "

	sleep 3
	qcserialstate=$(dmesg | grep "qcserial" | tail -1 | awk {print $NF;})
	if [ $qcserialstate != "detected" ]; then
		printf  "\n\nCannot detect bricked phone.  Please check your USB connection.\n\n"
		read -p "Press Enter to retry detection..." p
		modprobe -r qcserial
		CheckBrick
	fi
}

printf  "Found it!\n\n"

printf  "\nFrom here forward, DO NOT UNPLUG THE PHONE FROM THE USB CABLE!\n\n"

printf  "Now flashing the 1.12 bootloader.\n\n"
printf  "If this process hangs at \"Waiting for /dev/sd"$brickdrive"12...\"  Press and\n"
printf  "hold the power button on your phone for no less than 30 seconds and\n"
printf  "then release it.  The process should wake back up a few seconds afterwards.\n"
printf  "Note that this process can take as long as 10 minutes to complete and you\n"
printf  "will see a lot of repetitive output from the recovery tool.\n\n"
printf  "If this process fails to complete, you will need to complete the manual steps\n"
printf  "using the post on XDA.  In that case, your bricked phone should be\n"
printf  "accessible at /dev/sd$brickdrive\n\n"

modprobe -r qcserial																	# Reset qcserial kernel module and clear old blocks
mknod /dev/ttyUSB0 c 188 0																# Create block device for emmc_recover
./emmc_recover -r
./emmc_recover -q -f hboot_1.12.0000_signedbyaa.nb0 -d /dev/sd"$brickdrive"12 -c 24576		# Flash Signed 1.12 HBoot

printf  "/nSuccessfully loaded HBOOT 1.12.0000!/n/n/n"
printf  "The final step is restoring your backup /dev/block/mmcblk0p4./n/n"
printf  "Once again, if this process hangs at \"Waiting for /dev/sd"$brickdrive"4...\"\n"
printf  "Press and hold the power button on your phone for no less than 30 seconds and\n"
printf  "then release it.  The process should wake back up a few seconds afterwards.\n\n"
printf  "If this process fails to complete you will need to complete the manual steps\n"
printf  "using the post on XDA.  In that case, your bricked phone should be\n"
printf  "accessible at /dev/sd$brickdrive\n\n"

modprobe -r qcserial																	# Reset qcserial kernel module and clear old blocks
mknod /dev/ttyUSB0 c 188 0																# Create block device for emmc_recover
./emmc_recover -r
./emmc_recover -q -f ./bakp4 -d /dev/sd"$brickdrive"4										# Flash backup p4 file

printf  "/nSuccess!/n/n"
printf  "Your phone should now at least have a charging light on.  Some phones will/n"
printf  "immediately boot after restoration.  If yours doesn't, simply unplug the USB/n"
printf  "cable and hold your power button for a few seconds./n/n"
printf  "Enjoy HBOOT 1.12!  You can now S-OFF with LazyPanda./n"
