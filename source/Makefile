# Makefile for rvtl
#     2003/11/03  Jun Mizutani


INSTALLDIR = /usr/bin/

SOURCE = debug.s ext.s mt19937.s signal.s syscalls.s vtlfb.s vtlsys.s \
         errno.s fblib.s rvtl.s stdio.s syserror.s vtllib.s

# self assemble
ARCH=

# cross assemble
#ARCH=arm-linux-

AS=${ARCH}as
LD=${ARCH}ld
STRIP=${ARCH}strip

all : rvtl

rvtls : ${SOURCE}
	${AS} -o rvtl.o rvtl.s --defsym SMALL_VTL=1
	${LD} -o rvtl rvtl.o
	${STRIP} rvtl

rvtl : ${SOURCE}
	${AS} -o rvtl.o rvtl.s
	${LD} -o rvtl rvtl.o
	${STRIP} rvtl

debug : ${SOURCE}
	${AS} -o rvtl.o rvtl.s --defsym DEBUG=1
	${LD} -o rvtl rvtl.o

install :
	cp rvtl ${INSTALLDIR}

uninstall :
	rm ${INSTALLDIR}rvtl

dist :
	rm *.o
	mv rvtl ..

clean :
	rm *.o rvtl
