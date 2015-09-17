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

@ レジスタの値を表示するマクロ
@ すべてのレジスタを非破壊で表示可能
@ フラグレジスタは変化
@ ラベルとして998:と999:を使っていることに注意】
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

@ レジスタの値を先頭アドレスとする文字列を表示するマクロ
@ 文字列先頭アドレスの直接指定
@   ex. PRINTSTR v11
.macro  PRINTSTR   reg
        stmfd   sp!, {r0, lr}
        mov     r0, \reg
        bl      OutAsciiZ
        bl      NewLine
        ldmfd   sp!, {r0, lr}
.endm

@ レジスタが示すアドレスに格納された値を先頭アドレスとする
@ 文字列を表示するマクロ
@ 文字列先頭アドレスの間接指定
@   ex. PRINTSTRI v11
.macro  PRINTSTRI  reg
        stmfd   sp!, {r0, lr}
        ldr     r0, [\reg]
        bl      OutAsciiZ
        bl      NewLine
        ldmfd   sp!, {r0, lr}
.endm

@ 指定した値を表示するマクロ
@ すべてのレジスタを非破壊で表示可能
@   ex. CHECK 99
.macro  CHECK   val
        stmfd   sp!, {r0, lr}
        mov     r0, #\val
        bl      PrintLeft
        bl      NewLine
        ldmfd   sp!, {r0, lr}
.endm

@ キー入力待ち
.macro  PAUSE
        stmfd   sp!, {r0, lr}
        bl      InChar
        ldmfd   sp!, {r0, lr}
.endm

