#!/bin/bash


# Record

timeout=20
count=1
OUTDIR="output"
BASEDIR="$PWD/$OUTDIR"

if [ ! -e $BASEDIR ] ; then
    mkdir $BASEDIR
fi

while (($count <= $timeout)) ; do
    printf "dmesg:\n" > "$BASEDIR/debug_output.$count"
    dmesg | tail -15 >> "$BASEDIR/debug_output.$count"
    printf "\n\nlsusb:\n" >> "$BASEDIR/debug_output.$count"
    lsusb >> "$BASEDIR/debug_output.$count"
    printf "\b\b\b$count"
    ((count++))
    sleep 1
done

tar -cJf dbugout.txz $BASEDIR


# Display

for file_itor in $( ls -v $BASEDIR ) ; do
    clear
    printf "$BASEDIR/$file_itor\n\n"
    cat "$BASEDIR/$file_itor"
    sleep 1;
done
