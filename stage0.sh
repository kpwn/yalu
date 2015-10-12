#!/bin/sh
SCRIPTPATH=`dirname $0`
cd $SCRIPTPATH

function abort() {
echo "Error. Exiting..." >&2
exit 254;
}
echo "Error: Please disable Find My iPhone before continuing."
./wait_for_device.sh
rm -rf tmp
mkdir tmp
(
./bin/afcclient mkdir PhotoData/KimJongCracks
./bin/afcclient mkdir PhotoData/KimJongCracks/a
./bin/afcclient mkdir PhotoData/KimJongCracks/a/a
./bin/afcclient mkdir PhotoData/KimJongCracks/Library
./bin/afcclient mkdir PhotoData/KimJongCracks/Library/PrivateFrameworks
./bin/afcclient mkdir PhotoData/KimJongCracks/Library/PrivateFrameworks/GPUToolsCore.framework

./stage1.sh || exit

echo "Backing up, could take several minutes..." >&2
./bin/idevicebackup2 backup tmp || abort
udid="$(ls tmp | head -1)"

mkdir tmp_ddi
ddi="$(find /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport/ 2>/dev/null | grep 8.4|grep .dmg'$'||echo './data/DeveloperDiskImage.dmg' |head -1 )"
hdiutil attach -nobrowse -mountpoint tmp_ddi "$ddi"
cp tmp_ddi/Applications/MobileReplayer.app/MobileReplayer tmp/MobileReplayer
cp tmp_ddi/Applications/MobileReplayer.app/Info.plist tmp/MobileReplayerInfo.plist
hdiutil detach tmp_ddi
rm -rf tmp_ddi

lipo tmp/MobileReplayer -thin armv7s -output ./tmp/MobileReplayer
./bin/mbdbtool tmp $udid CameraRollDomain rm Media/PhotoData/KimJongCracks/a/a/MobileReplayer
./bin/mbdbtool tmp $udid CameraRollDomain put ./tmp/MobileReplayer Media/PhotoData/KimJongCracks/a/a/MobileReplayer || abort
)

echo "Restoring backup..."
(
./bin/idevicebackup2 restore tmp --system --reboot || abort
)>/dev/null
sleep 20
./wait_for_device.sh
read -p "Press [Enter] when your device finishes restoring."
echo
./mount_ddi.sh
./bin/fetchsymbols -f "$(./bin/fetchsymbols -l 2>&1 | (grep armv7 || abort ) | tr ':' '\n'|tr -d ' '|head -1)" tmp/cache
./bin/fetchsymbols -f "$(./bin/fetchsymbols -l 2>&1 | (grep dyld$ || abort ) | tr ':' '\n'|tr -d ' '|head -1)" tmp/dyld.fat
cd tmp
lipo -info dyld.fat | grep Non-fat >/dev/null || (lipo dyld.fat -thin "$(lipo -info dyld.fat | tr ' ' '\n' | grep v7)" -output dyld; mv dyld dyld.fat) && mv dyld.fat dyld
../bin/jtool -e IOKit cache
../bin/jtool -e libsystem_kernel.dylib cache
cd ..
cd data/dyldmagic
./make.sh
cd ../..
./bin/afcclient put ./data/dyldmagic/magic.dylib PhotoData/KimJongCracks/Library/PrivateFrameworks/GPUToolsCore.framework/GPUToolsCore
./bin/afcclient put ./data/untether/untether drugs
zcat ./data/bootstrap.tgz > ./tmp/bootstrap.tar
./bin/afcclient put ./tmp/bootstrap.tar PhotoData/KimJongCracks/bootstrap.tar
./bin/afcclient put ./data/tar PhotoData/KimJongCracks/tar
echo "Tap on the jailbreak icon to crash the kernel."
