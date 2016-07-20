cd ../untether
./make.sh
cd ../dyldmagic
./make.sh;../../bin/afcclient put magic.dylib PhotoData/KimJongCracks/Library/PrivateFrameworks/GPUToolsCore.framework/GPUToolsCore
../../bin/afcclient put ../untether/amfistop64 amfistop64
../../bin/afcclient put ../untether/untether64 untether64
