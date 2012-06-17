#!/bin/sh

VENDOR=samsung
DEVICE=aries-common

BASE=../../../vendor/$VENDOR/$DEVICE/proprietary

echo "Pulling common files..."
for FILE in `cat proprietary-files.txt | grep -v ^# | grep -v ^$`; do
    DIR=`dirname $FILE`
    if [ ! -d $BASE/$DIR ]; then
        mkdir -p $BASE/$DIR
    fi
    adb pull /system/$FILE $BASE/$FILE
done

# Special case for modem.bin
echo "Pulling modem..."
adb pull /radio/modem.bin $BASE/modem.bin

./setup-makefiles.sh
