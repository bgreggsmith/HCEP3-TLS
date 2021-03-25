#! /bin/sh

mkdir -p build

rm -rf out/*.vtk.*

if [ "$3" == "noclean" ]; then
	doclean=0;
else
	doclean=1;
fi

if (( $doclean == 1 )); then
	./clean.sh
fi

if [ "$1" != "release" ]; then
	fpc -fPIC -gl -gv -Fu`pwd`/src/lib/*/ `find . -print | grep $1` -Fu`pwd`/build/ -FE`pwd` -CfAVX2 -CfSSE42 -CfAVX -CfSSE41 -CfSSSE3 -CfSSE3
else
        if (( $doclean == 0 )); then
                ./clean.sh 
        fi
       
	fpc -fPIC -CX -XX -O4 -Xs- -OWall -Fu`pwd`/src/lib/*/ $2 -FU`pwd`/build  -FE`pwd`  -CfAVX2 -CfSSE42 -CfAVX -CfSSE41 -CfSSSE3 -CfSSE3
fi 

if (( $doclean == 1 )); then
	./clean.sh
fi

exit
