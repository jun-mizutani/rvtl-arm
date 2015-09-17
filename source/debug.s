@-------------------------------------------------------------------------
@  Debugging Macros for ARM assembly
@  file : debug.s
@  2003/10/27
@  Copyright (C) 2003 Jun Mizutani <mizutani.jun@nifty.ne.jp>
@  This file may be copied under the terms of the GNU General Public License.
@-------------------------------------------------------------------------

.ifndef __STDIO
.include "stdio.s"
.endif

@ �쥸�������ͤ�ɽ������ޥ���
@ ���٤ƤΥ쥸���������˲���ɽ����ǽ
@ �ե饰�쥸�������Ѳ�
@ ��٥�Ȥ���998:��999:��ȤäƤ��뤳�Ȥ���ա�
@   ex. PRINTREG r1
.macro  PRINTREG   reg
        stmfd   sp!, {r0-r3, lr}
        stmfd   sp!, {r0}
        adr     r0, 998f
        bl      OutAsciiZ
        ldmfd   sp!, {r0}
        stmfd   sp!, {r0,r1}
        mov     r0, \reg
        mov     r1, #12
        bl      PrintRight
        bl      PrintRightU
        mov     r0, #':'
        bl      OutChar
        ldmfd   sp!, {r0,r1}
        mov     r0, \reg
        bl      PrintHex8
        mov     r2, r0
        mov     r0, #' '
        bl      OutChar
        mov     r0, r2
        bl      OutChar4
        bl      NewLine
        ldmfd   sp!, {r0-r3, lr}
        b       999f
        .align  2
998:    .asciz "\reg"
        .align  2
999:
.endm

@ �쥸�������ͤ���Ƭ���ɥ쥹�Ȥ���ʸ�����ɽ������ޥ���
@ ʸ������Ƭ���ɥ쥹��ľ�ܻ���
@   ex. PRINTSTR v11
.macro  PRINTSTR   reg
        stmfd   sp!, {r0, lr}
        mov     r0, \reg
        bl      OutAsciiZ
        bl      NewLine
        ldmfd   sp!, {r0, lr}
.endm

@ �쥸�������������ɥ쥹�˳�Ǽ���줿�ͤ���Ƭ���ɥ쥹�Ȥ���
@ ʸ�����ɽ������ޥ���
@ ʸ������Ƭ���ɥ쥹�δ��ܻ���
@   ex. PRINTSTRI v11
.macro  PRINTSTRI  reg
        stmfd   sp!, {r0, lr}
        ldr     r0, [\reg]
        bl      OutAsciiZ
        bl      NewLine
        ldmfd   sp!, {r0, lr}
.endm

@ ���ꤷ���ͤ�ɽ������ޥ���
@ ���٤ƤΥ쥸���������˲���ɽ����ǽ
@   ex. CHECK 99
.macro  CHECK   val
        stmfd   sp!, {r0, lr}
        mov     r0, #\val
        bl      PrintLeft
        bl      NewLine
        ldmfd   sp!, {r0, lr}
.endm

@ ���������Ԥ�
.macro  PAUSE
        stmfd   sp!, {r0, lr}
        bl      InChar
        ldmfd   sp!, {r0, lr}
.endm

