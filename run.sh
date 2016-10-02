#!/bin/sh

### Initial vars ###

untether_h="./data/dyldmagic/untether.h"
if [ $# -gt 0 ] ; then
	UNTETHER="$1"
	CUSTOM_NAME="$1"
	echo "#define CUSTOM_NAME \"$UNTETHER\"" > "$untether_h"
	echo "#define CUSTOM_TEST" >> "$untether_h"
	echo "\033[35mNote: untether switched to $1\033[0m"
else
	UNTETHER="untether"
	#CUSTON_NAME=""
	echo "" > "$untether_h"
fi

trap "exit 254" TERM
export TOP_PID=$$

SCRIPTPATH=`pwd -P`
ddi="$(find /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport 2>/dev/null | grep "8.4/.*.dmg$" || echo './data/DeveloperDiskImage.dmg' | head -1)"

cd $SCRIPTPATH

### Functions ###

function abort() {
echo "\033[31mError. Exiting... ☹  \033[0m" >&2
kill -s TERM $TOP_PID;
}

function abort_backup() {
echo "\033[31mDid you forget to turn off Find My iPhone? ☕  \033[0m" >&2
kill -s TERM $TOP_PID
}

### Ddi mount function ###

function mount_ddi(){
echo "\033[33m* Mounting DDI...\033[0m"
./bin/ideviceimagemounter "$ddi" >/dev/null || echo "\033[31mCouldn't mount DDI. Not an issue if Xcode's running, an issue if it isn't.\033[0m"
}

### Device detection function ###

function wait_for_device() {
echo "\033[33m* Waiting for device...\033[0m"
while ! (./bin/afcclient deviceinfo | grep -q FSTotalBytes); do sleep 5; done 2>/dev/null
}

### Jailbreak Functions ###
# Stage 1:
# set-up environment, install app and swap binaries

function stage1(){
echo "\033[33m* Setting up environment...\033[0m"

./bin/afcclient put ./data/WWDC_Info_TOC.plist /yalu.plist | grep Uploaded || abort

echo "
\033[33m* Installing app & swapping binaries...\033[m"

./bin/mobiledevice install_app ./data/WWDC-TOCTOU.ipa || abort

echo "
\033[33mPlease wait...\033[0m"

sleep 5
./bin/afcclient put ./data/WWDC_Info_TOU.plist /yalu.plist | grep Uploaded || abort

echo
}

# Stage 0:
# Important stuff

stage0() {
echo "\033[31m DISABLE FIND MY PHONE\033[0m"
# Waiting for device
wait_for_device

echo "\033[33m* Recreating temp directory...\033[0m"
rm -rf tmp
mkdir tmp

(
echo "\033[33m* Creating dirs on device\033[0m">&2
./bin/afcclient mkdir PhotoData/KimJongCracks
./bin/afcclient mkdir PhotoData/KimJongCracks/a
./bin/afcclient mkdir PhotoData/KimJongCracks/a/a
./bin/afcclient mkdir PhotoData/KimJongCracks/Library
./bin/afcclient mkdir PhotoData/KimJongCracks/Library/PrivateFrameworks
./bin/afcclient mkdir PhotoData/KimJongCracks/Library/PrivateFrameworks/GPUToolsCore.framework

# Stage 1
stage1 || abort

# Backup device data

echo "\033[33m* Backing up, could take several minutes...\033[0m" >&2
./bin/idevicebackup2 backup tmp || abort
udid="$(ls tmp | head -1)"

echo "\033[33m* Mounting ddi and copying files to backup directory\033[0m">&2

mkdir tmp_ddi
hdiutil attach -nobrowse -mountpoint tmp_ddi "$ddi"
cp tmp_ddi/Applications/MobileReplayer.app/MobileReplayer tmp/MobileReplayer
#cp tmp_ddi/Applications/MobileReplayer.app/Info.plist tmp/MobileReplayerInfo.plist
hdiutil detach tmp_ddi
rm -rf tmp_ddi

echo "\033[33m* Compiling and copying binary file to device...\033[0m">&2

lipo tmp/MobileReplayer -thin armv7 -output ./tmp/MobileReplayer32
lipo -info tmp/MobileReplayer | grep arm64 > /dev/null && (
	lipo tmp/MobileReplayer -thin arm64 -output ./tmp/MobileReplayer64
)
./bin/mbdbtool tmp $udid CameraRollDomain rm Media/PhotoData/KimJongCracks/a/a/MobileReplayer
./bin/mbdbtool tmp $udid CameraRollDomain put ./tmp/MobileReplayer32 Media/PhotoData/KimJongCracks/a/a/MobileReplayer || abort
)

# Restore modified backup
echo "\033[33m* Restoring modified backup...\033[0m"
(
./bin/idevicebackup2 restore tmp --system --reboot || abort_backup
)>/dev/null

# ZZZZZZ....
echo "\033[33m* Sleeping until device reboot...\033[0m"
sleep 20

# Wait for device
wait_for_device
echo "\033[96m"
read -p "> Press [Enter] key when your device finishes restoring."
echo "\033[0m"
echo

# Mount ddi
mount_ddi

echo "\033[33m* Fetching symbols...\033[0m"
./bin/fetchsymbols -f "$(./bin/fetchsymbols -l 2>&1 | (grep dyld$ || abort ) | tr ':' '\n'|tr -d ' '|head -1)" ./tmp/dyld.fat
lipo -info ./tmp/dyld.fat | grep arm64 >/dev/null && ./bin/fetchsymbols -f "$(./bin/fetchsymbols -l 2>&1 | (grep arm64 || abort ) | tr ':' '\n'|tr -d ' '|head -1)" ./tmp/cache64

if [ ! -f orig_cache32 ]; then
	./bin/fetchsymbols -f "$(./bin/fetchsymbols -l 2>&1 | (grep armv7 || abort ) | tr ':' '\n'|tr -d ' '|head -1)" ./tmp/cache
else
	cp orig_cache32 ./tmp/cache
fi

# extract modules
cd tmp
lipo -info dyld.fat | grep arm64 >/dev/null && lipo dyld.fat -thin arm64 -output ../tmp/dyld64
lipo -info dyld.fat | grep Non-fat >/dev/null || (lipo dyld.fat -thin "$(lipo -info dyld.fat | tr ' ' '\n' | grep v7)" -output dyld; mv dyld dyld.fat) && mv dyld.fat dyld
$SCRIPTPATH/bin/jtool -e IOKit cache
$SCRIPTPATH/bin/jtool -e libsystem_kernel.dylib cache
$SCRIPTPATH/bin/jtool -e libobjc.A.dylib cache
$SCRIPTPATH/bin/jtool -e Foundation cache

if [ -f cache64 ]; then
	$SCRIPTPATH/bin/jtool -e libdyld.dylib cache64
fi

echo "\033[33m* Compiling jailbreak files...\033[0m"
#cd $SCRIPTPATH/data/that_guy
#make
cd $SCRIPTPATH/data/$UNTETHER
echo "\033[96m"
read -r -p "Install dropbear (lightweight SSH)? [y/n]" response
echo "\033[0m"
if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
then
	./make.sh DROPBEAR
	../../bin/afcclient put ../dropbear PhotoData/KimJongCracks/dropbear
	../../bin/afcclient put ../dropbearkey PhotoData/KimJongCracks/dropbearkey
else
	./make.sh
fi
cd $SCRIPTPATH/data/dyldmagic
./make.sh
#cd $SCRIPTPATH/data/dyldmagic64
#./make.sh

echo "\033[33m* Copying files to device...\033[0m"
cd $SCRIPTPATH
./bin/afcclient put ./data/dyldmagic/magic.dylib PhotoData/KimJongCracks/Library/PrivateFrameworks/GPUToolsCore.framework/GPUToolsCore
#./bin/afcclient put ./data/dyldmagic64/magic64_amfid.dylib PhotoData/KimJongCracks/Library/PrivateFrameworks/GPUToolsCore.framework/GPUToolsCore
if [ ! -z $CUSTOM_NAME ] ; then
	echo "using a custom untether"
	./bin/afcclient put ./data/$CUSTOM_NAME/$CUSTOM_NAME $CUSTOM_NAME
else
	echo "using state untether"
	./bin/afcclient put ./data/$UNTETHER/amfistop64 amfistop64
	./bin/afcclient put ./data/$UNTETHER/untether64 untether64
fi
gzcat ./data/bootstrap.tgz > ./tmp/bootstrap.tar
./bin/afcclient put ./tmp/bootstrap.tar PhotoData/KimJongCracks/bootstrap.tar
./bin/afcclient put ./data/tar PhotoData/KimJongCracks/tar

echo ""
echo "\033[33m== FAQ\033[0m"
echo ""
echo "\033[33mQ: Blue screen and reboot\033[0m"
echo "\033[33mA: Tap jailbreak icon again when device is back\033[0m"
echo ""
echo "\033[33mQ: After tapping, jailbreak icon disappeared and Cydia icon didn't appear\033[0m"
echo "\033[33mA: Reboot device and tap jailbreak icon again\033[0m"
echo ""
echo "\033[33mQ: Jailbreak is gone after reboot\033[0m"
echo "\033[33mA: Persistence is currently disabled, you have to tap jailbreak icon after every reboot\033[0m"
echo ""
echo "\033[33mQ: Jailbreak icon disappeared after reboot\033[0m"
echo "\033[33mA: do run.sh again\033[0m"
echo ""
echo "\033[91mNOTE: This is tethered jailbreak, use Cydia wisely and don't brick your device!\033[0m"
echo ""
echo "\033[96m>> Now tap on the jailbreak icon to crash the kernel (or 0wn it if you're in luck!) <<\033[0m"

}

# Let's do this!
stage0 || abort

exit 0
