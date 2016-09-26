#!/bin/sh
cd "$(dirname "$0")"
rm -f symbols.h
touch symbols.h
symbol=0x"$(nm IOKit | grep _io_connect_add_client$ | tr ' ' '\n' | head -1)"
echo "#define IOKIT_io_connect_add_client $symbol" >> symbols.h
symbol=0x"$(nm IOKit | grep _IOServiceOpen$ | tr ' ' '\n' | head -1)"
echo "#define IOKIT_IOServiceOpen $symbol" >> symbols.h
symbol=0x"$(nm IOKit | grep _io_service_get_matching_service$ | tr ' ' '\n' | head -1)"
echo "#define IOKIT_io_service_get_matching_service $symbol" >> symbols.h
symbol=0x"$(nm IOKit | grep io_connect_method_scalarI_structureI$ | tr ' ' '\n' | head -1)"
echo "#define IOKIT_io_connect_method_scalarI_structureI $symbol" >> symbols.h
symbol=0x"$(nm IOKit | grep IOServiceClose$ | tr ' ' '\n' | head -1)"
echo "#define IOKIT_IOServiceClose $symbol" >> symbols.h
symbol=0x"$(nm IOKit | grep _IOServiceWaitQuiet$ | tr ' ' '\n' | head -1)"
echo "#define IOKIT_IOServiceWaitQuiet $symbol" >> symbols.h
symbol=0x"$(nm libsystem_kernel.dylib | grep host_get_io_master$ | tr ' ' '\n' | head -1)"
echo "#define LS_K_host_get_io_master $symbol" >> symbols.h
symbol=0x"$(nm libsystem_kernel.dylib | grep _pipe$ | tr ' ' '\n' | head -1)"
echo "#define LS_K_pipe $symbol" >> symbols.h
symbol=0x"$(nm libsystem_kernel.dylib | grep _write$ | tr ' ' '\n' | head -1)"
echo "#define LS_K_write $symbol" >> symbols.h
symbol=0x"$(../../bin/jtool -v cache  |grep mapping | sed 's/  //g'|tr ' ' '\n'|grep - --before 1 | head -1)"
echo "#define _DYCACHE_BASE $symbol" >> symbols.h
echo "" >> symbols.h
