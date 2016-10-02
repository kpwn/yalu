ADD_DROPBEAR=""

if [ "$1" == "DROPBEAR" ]
  then
    ADD_DROPBEAR="-D$1"
fi

# clean up
rm amfistop64
rm untether64

# build 32bit amfistop for 64bit devices
gcc -std=c++14 untether64.mm -o amfistop64 -w -arch armv7 -isysroot "$(xcrun --show-sdk-path --sdk iphoneos)" -framework IOKit -framework Foundation -lz
ldid -Se.xml amfistop64

# build 64bit untether for 64bit devices
gcc $ADD_DROPBEAR -std=c++14 untether64.mm -o untether64 -w -arch arm64 -isysroot "$(xcrun --show-sdk-path --sdk iphoneos)" -framework IOKit -framework Foundation -lz
ldid -Se.xml untether64
