@ ------------------------------------------------------------------------
@ Standard I/O Subroutine for ARM
@   2003/09/22
@   2009/03/13 arm eabi system call
@ Copyright (C) 2003-2009  Jun Mizutani <mizutani.jun@nifty.ne.jp>
@ stdio.s may be copied under the terms of the GNU General Public License.
@ ------------------------------------------------------------------------

.ifndef __STDIO
__STDIO = 1

.ifndef __SYSCALL
  .equ sys_exit,  0x000001
  .equ sys_read,  0x000003
  .equ sys_write, 0x000004
.endif

.text

@------------------------------------
@ exit with 0
Exit:
        mov     r0, #0
        mov     r7, #sys_exit
        swi     0
        mov     pc, lr

@------------------------------------
@ exit with r0
ExitN:
        mov     r7, #sys_exit
        swi     0
        mov     pc, lr


@------------------------------------
@ print string to stdout
@ r0 : address, r1 : length
OutString:
        stmfd   sp!, {r0-r2, r7, lr}
        mov     r2, r1                  @ a2  length
        mov     r1, r0                  @ a1  string address
        mov     r0, #1                  @ a0  stdout
        mov     r7, #sys_write
        swi     0
        ldmfd   sp!, {r0-r2, r7, pc}    @ return

@------------------------------------
@ input  r0 : address
@ output r1 : return length of strings
StrLen:
        stmfd   sp!, {r0, r2, lr}
        mov     r1, #0                  @ r1 : counter
1:      ldrb    r2, [r0], #1            @ r2 = *pointer++ (1byte)
        cmp     r2, #0
        addne   r1, r1, #1              @ counter++
        bne     1b
        ldmfd   sp!, {r0, r2, pc}       @ return

@------------------------------------
@ print asciiz string
@ r0 : pointer to string
OutAsciiZ:
        stmfd   sp!, {r1, lr}
        bl      StrLen
        bl      OutString
        ldmfd   sp!, {r1, pc}           @ return

@------------------------------------
@ print pascal string to stdout
@ r0 : top address
OutPString:
        stmfd   sp!, {r0-r1, lr}
        ldrb    r1, [r0]
        add     r0, r0, #1
        bl      OutString
        ldmfd   sp!, {r0-r1, pc}        @ return

@------------------------------------
@ print 1 character to stdout
@ r0 : put char
OutChar:
        stmfd   sp!, {r0-r2, r7, lr}
        mov     r1, sp                  @ r1  address
        mov     r0, #1                  @ r0  stdout
        mov     r2, r0                  @ r2  length
        mov     r7, #sys_write
        swi     0
        ldmfd   sp!, {r0-r2, r7, pc}    @ pop & return

@------------------------------------
@ print 4 characters in r0 to stdout
OutChar4:
        stmfd   sp!, {r0-r2, lr}
        mov     r1, r0
        mov     r2, #4
1:
        and     r0, r1, #0x7F
        cmp     r0, #0x20
        movlt   r0, #'.'
        bl      OutChar
        mov     r1, r1, LSR #8
        subs    r2, r2, #1
        bne     1b
        ldmfd   sp!, {r0-r2, pc}        @ return

@------------------------------------
@ new line
NewLine:
        stmfd   sp!, {r0, lr}
        mov     r0, #10
        bl      OutChar
        ldmfd   sp!, {r0, pc}           @ return


@------------------------------------
@ Backspace
BackSpace:
        stmfd   sp!, {r0, lr}
        mov     r0, #8
        bl      OutChar
        mov     r0, #' '
        bl      OutChar
        mov     r0, #8
        bl      OutChar
        ldmfd   sp!, {r0, pc}           @ return

@------------------------------------
@ print binary number
@   r0 : number
@   r1 : bit
PrintBinary:
        stmfd   sp!, {r0-r3, lr}
        teq     r1, #0                  @ r1 > 0 ?
        beq     2f                      @ if r1=0 exit
        mov     r2, r0
        mov     r3, #32
        cmp     r1, r3
        movhi   r1, r3                  @ if r1>32 then r1=32
        subs    r3, r3, r1
        mov     r2, r2, LSL r3
    1:  mov     r0, #'0'
        movs    r2, r2, LSL #1
        addcs   r0, r0, #1
        bl      OutChar
        subs    r1, r1, #1
        bne     1b
    2:  ldmfd   sp!, {r0-r3, pc}        @ return

@------------------------------------
@ print ecx digit octal number
@   r0 : number
@   r1 : columns
PrintOctal:
        stmfd   sp!, {r0-r3, lr}
        teq     r1, #0                  @ r1 > 0 ?
        beq     3f                      @ if r1=0 exit
        mov     r3, r1                  @ column
    1:  and     r2, r0, #7
        mov     r0, r0, LSR #3
        stmfd   sp!, {r2}               @ 剰余(下位桁)をPUSH
        subs    r3, r3, #1
        bne     1b
    2:  ldmfd   sp!, {r0}               @ 上位桁から POP
        add     r0, r0, #'0'            @ 文字コードに変更
        bl      OutChar                 @ 出力
        subs    r1, r1, #1              @ column--
        bne     2b
    3:  ldmfd   sp!, {r0-r3, pc}        @ return

@------------------------------------
@ print 2 digit hex number (lower 8 bit of r0)
@   r0 : number
PrintHex2:
        mov     r1, #2
        b       PrintHex

@------------------------------------
@ print 4 digit hex number (lower 16 bit of r0)
@   r0 : number
PrintHex4:
        mov     r1, #4
        b       PrintHex

@------------------------------------
@ print 8 digit hex number (r0)
@   r0 : number
PrintHex8:
        mov     r1, #8

@------------------------------------
@ print hex number
@   r0 : number     r1 : digit
PrintHex:

        stmfd   sp!, {r0-r3,lr}         @ push
        mov     r3, r1                  @ column
1:      and     r2, r0, #0x0F           @
        mov     r0, r0, LSR #4          @
        orr     r2, r2, #0x30
        cmp     r2, #0x39
        addgt   r2, r2, #0x41-0x3A      @ if (r2>'9') r2+='A'-'9'
        stmfd   sp!, {r2}               @ push digit
        subs    r3, r3, #1              @ column--
        bne     1b
        mov     r3, r1                  @ column
2:      ldmfd   sp!, {r0}               @ pop digit
        bl      OutChar
        subs    r3, r3, #1              @ column--
        bne     2b
        ldmfd   sp!, {r0-r3,pc}         @ restore & return

@------------------------------------
@ Unsigned Number Division
@ in : r0 : divident / r1:divisor
@ out: r0 : quotient...r1:remainder
@      carry=1 : divided by 0
udiv:                                   @ r0  / r1  = r0 ... r1
        stmfd   sp!, {v1-v6, lr}
        rsbs    v2, r1, #0              @ Trap div by zero
        bcs     4f                      @ if carry=1 Error
        mov     v1, #0                  @ Init result (v1)
        mov     v2, #1
        clz     v4, r1
    1:  cmp    r0, r1                  @ A-b
        bcc     3f                      @ if A<b exit
        clz     v3, r0                  @
        sub     v6, v4, v3
        mov     v5, r1, LSL v6          @ b << v6
        cmp    r0, v5                  @ A-b
        movcc   v5, v5, LSR #1          @ if A<b b >> 1
        subcc   v6, v6, #1              @ if A<b v6=v6-1
        sub     r0, r0, v5              @ A=A-b
        add     v1, v1, v2, LSL v6      @ v1=v1-(1<<v6)
        b       1b                      @ goto 1
    3:  mov     r1, r0
        mov     r0, v1
    4:  ldmfd   sp!, {v1-v6, pc}        @ return

@------------------------------------
@ Output Unsigned Number to stdout
@ r0 : number
PrintLeftU:
        stmfd   sp!, {r0-r3, lr}        @ push
        mov     r2, #0                  @ counter
        mov     r3, #0                  @ positive flag
        b       1f

@------------------------------------
@ Output Number to stdout
@ r0 : number
PrintLeft:
        stmfd   sp!, {r0-r3, lr}        @ push
        mov     r2, #0                  @ counter
        mov     r3, #0                  @ positive flag
        cmp     r0, #0
        movmi   r3, #1                  @ set negative
        submi   r0, r2, r0              @ r0 = 0-r0
    1:  mov     r1, #10                 @ r3 = 10
        bl      udiv                    @ division by 10
        add     r2, r2, #1              @ counter++
        stmfd   sp!, {r1}               @ least digit (reminder)
        cmp     r0, #0
        bne     1b                      @ done ?
        cmp     r3, #0
        movne   r0, #'-'                @ if (r0<0) putchar("-")
        blne    OutChar                 @ output '-'
    2:  ldmfd   sp!, {r0}               @ most digit
        add     r0, r0, #'0'            @ ASCII
        bl      OutChar                 @ output a digit
        subs    r2, r2, #1              @ counter--
        bne     2b
        ldmfd   sp!, {r0-r3, pc}        @ pop & return

@------------------------------------
@ Output Number to stdout
@ r1:column
@ r0:number
PrintRight0:
        stmfd   sp!, {r0-r3, v1-v2, lr} @ push
        mov     v1, #'0'
        b       0f

@------------------------------------
@ Output Unsigned Number to stdout
@ r1:column
@ r0:number
PrintRightU:
        stmfd   sp!, {r0-r3, v1-v2, lr} @ push
        mov     v1, #' '
    0:  mov     v2, r1
        mov     r2, #0                  @ counter
        mov     r3, #0                  @ positive flag
        b       1f                      @ PrintRight.1

@------------------------------------
@ Output Number to stdout
@ r1:column
@ r0:number
PrintRight:
        stmfd   sp!, {r0-r3, v1-v2, lr} @ push
        mov     v1, #' '
        mov     v2, r1
        mov     r2, #0                  @ counter
        mov     r3, #0                  @ positive flag
        cmp     r0, #0
        movlt   r3, #1                  @ set negative
        sublt   r0, r2, r0              @ r0 = 0-r0
    1:  mov     r1, #10                 @ r3 = 10
        bl      udiv                    @ division by 10
        add     r2, r2, #1              @ counter++
        stmfd   sp!, {r1}               @ least digit
        cmp     r0, #0
        bne     1b                      @ done ?

        subs    v2, v2, r2              @ v2 = no. of space
        ble     3f                      @ dont write space
        cmp     r3, #0
        subne   v2, v2, #1              @ reserve spase for -
    2:  mov     r0, v1                  @ output space or '0'
        bl      OutChar
        subs    v2, v2, #1              @ nspace--
        bgt     2b

    3:  cmp     r3, #0
        movne   r0, #'-'                @ if (r0<0) putchar("-")
        blne    OutChar                 @ output '-'
    4:  ldmfd   sp!, {r0}               @ most digit
        add     r0, r0, #'0'            @ ASCII
        bl      OutChar                 @ output a digit
        subs    r2, r2, #1              @ counter--
        bne     4b
        ldmfd   sp!, {r0-r3, v1-v2, pc} @ pop & return

@------------------------------------
@ input 1 character from stdin
@ r0 : get char
InChar:
        mov     r0, #0        @ clear upper bits
        stmfd   sp!, {r0-r2, r7, lr}
        mov     r1, sp                  @ r1  address
        mov     r0, #0                  @ r0  stdin
        mov     r2, #1                  @ r2  length
        mov     r7, #sys_read
        swi     0
        ldmfd   sp!, {r0-r2, r7, pc}    @ pop & return

@------------------------------------
@ Input Line
@ r0 : BufferSize
@ r1 : Buffer Address
@ return       r0 : no. of char
InputLine0:
        stmfd   sp!, {r1-r3, v1-v2, lr}
        mov     v1, r0                  @ BufferSize
        mov     v2, r1                  @ Input Buffer
        mov     r3, #0                  @ counter
    1:
        bl      InChar
        cmp     r0, #0x08               @ BS ?
        bne     2f
        cmp     r3, #0
        beq     2f
        bl      BackSpace               @ backspace
        sub     r3, r3, #1
        b       1b
    2:
        cmp     r0, #0x0A               @ enter ?
        beq     4f                      @ exit

        bl      OutChar                 @ printable:
        strb    r0, [v2, r3]            @ store a char into buffer
        add     r3, r3, #1
        cmp     r3, v1
        bge     3f
        b       1b
    3:
        sub     r3, r3, #1
        bl      BackSpace
        b       1b

    4:  mov     r0, #0
        strb    r0, [v2, r3]
        add     r3, r3, #1
        bl      NewLine
        mov     r0, r3
        ldmfd   sp!, {r1-r3, v1-v2, pc} @ pop & return

.endif
