@-------------------------------------------------------------------------
@  file : vtlsys.s
@  2003/10/19
@  2009/03/13 arm eabi
@  2015/08/30 6th arg
@  2015/11/12 Change the mnemonic of SWI instruction to SVC
@  Copyright (C) 2003-2015 Jun Mizutani <mizutani.jun@nifty.ne.jp>
@-------------------------------------------------------------------------

.text

SYSCALLMAX  =   256

SystemCall:                         @ fp=v8=r11
        stmfd   sp!, {r1-r5, r7, v6, lr}
        mov     v6, #'a             @ a にシステムコール番号
        ldr     r7, [fp, v6,LSL #2] @ r7=システムコール番号
        cmp     v7, #SYSCALLMAX
        bgt     1f
        mov     v6, #'b             @ b にシステムコール引数1
        ldr     r0, [fp, v6,LSL #2] @ r0=システムコール引数1
        mov     v6, #'c             @ c にシステムコール引数2
        ldr     r1, [fp, v6,LSL #2] @ r1=システムコール引数2
        mov     v6, #'d             @ d にシステムコール引数3
        ldr     r2, [fp, v6,LSL #2] @ r2=システムコール引数3
        mov     v6, #'e             @ e にシステムコール引数4
        ldr     r3, [fp, v6,LSL #2] @ r3=システムコール引数4
        mov     v6, #'f             @ f にシステムコール引数5
        ldr     r4, [fp, v6,LSL #2] @ r4=システムコール引数5
        mov     v6, #'g             @ g にシステムコール引数6
        ldr     r5, [fp, v6,LSL #2] @ r4=システムコール引数6
        svc     0
    1:  ldmfd   sp!, {r1-r5, r7, v6, pc}

