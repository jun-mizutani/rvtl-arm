@-------------------------------------------------------------------------
@  Return of the Very Tiny Language (ARM)
@  Copyright (C) 2003 - 2015 Jun Mizutani <mizutani.jun@nifty.ne.jp>
@  file : vtlfb.s  frame buffer extention
@  2015/09/25
@-------------------------------------------------------------------------

        stmfd   sp!, {lr}
        bl      GetChar             @
        cmp     v1, #'b
        beq     1f
        b       pop2_and_Error
    1:  bl      GetChar             @
        cmp     v1, #'o
        beq     func_fbo            @ fb open
        cmp     v1, #'c
        beq     func_fbc            @ fb close
        cmp     v1, #'d
        beq     func_fbd            @ fb dot
        cmp     v1, #'f
        beq     func_fbf            @ fb fill
        cmp     v1, #'l
        beq     func_fbl            @ fb line
        cmp     v1, #'m
        beq     func_fbm            @ fb mem_copy
        cmp     v1, #'p
        beq     func_fbp            @ fb put
        cmp     v1, #'q
        beq     func_fbq            @ fb put with mask
        cmp     v1, #'r
        beq     func_fbr            @ fb fill pattern
        cmp     v1, #'s
        beq     func_fbs            @ fb set_screen
        cmp     v1, #'t
        beq     func_fbt            @ fb put2
        b       pop2_and_Error

func_fbo:
        bl      fbdev_open
fb_error:
        bmi     pop_and_SYS_Error
        bl      fb_get_fscreen
        bmi     fb_error
        bl      fb_get_screen
        bmi     fb_error
        bl      fb_copy_scinfo
        bl      fb_map_screen
        bmi     pop_and_SYS_Error
        mov     r3, #'f
        str     r0, [fp, r3,LSL #2]
        mov     r3, #'g
        ldr     r0, scinfo_data0
        str     r0, [fp, r3,LSL #2]
        ldmfd   sp!, {pc}

scinfo_data0:
        .long   scinfo_data         @ fblib.s

func_fbf:
        bl      FrameBufferFill
        ldmfd   sp!, {pc}

func_fbd:
        bl      Dot
        ldmfd   sp!, {pc}

func_fbc:
        bl      fb_restore_sc       @ 保存済みの設定を復帰
        bl      fb_unmap_screen
        bl      fbdev_close
        bmi     pop_and_SYS_Error
        ldmfd   sp!, {pc}
func_fbl:
        bl      LineDraw
        ldmfd   sp!, {pc}
func_fbm:
        bl      MemCopy
        ldmfd   sp!, {pc}
func_fbp:
        bl      PatternTransfer
        ldmfd   sp!, {pc}

func_fbq:
        bl      MPatternTransfer
        ldmfd   sp!, {pc}

func_fbr:
        bl      PatternFill
        ldmfd   sp!, {pc}

func_fbs:
        bl      fb_set_screen
        ldmfd   sp!, {pc}

func_fbt:
        bl      PatternTransfer2
        ldmfd   sp!, {pc}

@---------------------------------------------------------------------------
@ 点の描画 16bit
@   d[0] = addr   [v7,  #0] 転送先アドレス
@   d[1] = x      [v7,  #4] 転送先のX座標
@   d[2] = y      [v7,  #8] 転送先のY座標
@   d[3] = Color  [v7, #12] 色
@   d[4] = ScrX   [v7, #16] 転送先X方向のバイト数
@   d[5] = Depth  [v7, #20] 1ピクセルのビット数
Dot:
        stmfd   sp!, {v7, lr}
        mov     r3, #'d'            @ 引数は d[0] - d[5]
        ldr     v7, [fp, r3,LSL #2] @ v7 : argument top
        ldr     r3, [v7, #16]       @ ScrX
        ldr     r2, [v7]            @ buffer address (mem or fb)
        ldr     r1, [v7, #8]        @ Y
        mul     r0, r1, r3          @ Y * ScrX
        ldr     r3, [v7, #4]        @ X
        add     r1, r0, r3,LSL #1   @ X * 2 + Y * ScrX
        ldr     r0, [v7, #12]       @ color
        strh    r0, [r1, r2]        @ 16bit/pixel
        ldmfd   sp!, {v7, pc}

@---------------------------------------------------------------------------
@ r0 : Y  color
@ r1 : width(bytes/line)
@ v6 : addr
StartPoint:
        stmfd   sp!, {r2, lr}
        mul     r2, r1, r0          @ Y * width
        ldr     r0, [v7, #+ 4]      @ X
        add     r0, r2, r0,LSL #1   @ Y * width + X*2
        add     v6, v6, r0          @ v6=addr+Y * width + X
        ldr     r0, [v7, #+20]      @ color
        ldmfd   sp!, {r2, pc}

@---------------------------------------------------------------------------
@ ライン描画
@ l[0] = addr   [v7, #+ 0]
@ l[1] = x1     [v7, #+ 4]      @ l[2] = y1     [v7, #+ 8]
@ l[3] = x2     [v7, #+12]      @ l[4] = y2     [v7, #+16]
@ l[5] = color  [v7, #+20]
@ l[6] = ScrX   [v7, #+24]
@ l[7] = Depth  [v7, #+28]      @ 1ピクセルのビット数
@ l[8] = incr1  [v7, #+32]
@ l[9] = incr2  [v7, #+36]
@ v6 : framebuffer
@ r1 (ebx) ScrX
@ r2
LineDraw:
        stmfd   sp!, {v4-v7, lr}
        mov     r3, #'l'            @ 引数は l[0] - l[9]
        ldr     v7, [fp, r3,LSL #2] @ v7 : argument top
        ldr     v6, [v7]            @ buffer address (mem or fb)
        ldr     r1, [v7, #+24]      @ ScrX
        ldr     r2, [v7, #+12]      @ r2 = delta X (X2 - X1)
        ldr     r0, [v7, #+ 4]
        subs    r2, r2, r0          @ r2 = X2 - X1
        beq     VertLine            @ if (delta X=0) Vertical
        bpl     1f                  @ JUMP IF X2 > X1

        rsb     r2, r2, #0          @ deltaX = - deltaX
        ldr     r0, [v7, #+12]      @ swap X1  X2
        add     ip, v7, #4          @ X1
        swp     r0, r0, [ip]
        str     r0, [v7, #+12]      @ X2

        ldr     r0, [v7, #+16]      @ Y2
        add     ip, v7, #8          @ Y1
        swp     r0, r0, [ip]        @ Y2 --> Y1
        str     r0, [v7, #+16]      @ Y1 --> Y2

    1:  ldr     r0, [v7, #+16]      @ r0 = Y2-Y1
        ldr     r3, [v7, #+ 8]
        subs    r0, r0, r3
        bne     SlopeLine

HolizLine:
        add     r2, r2, #1          @ DELTA X + 1 : # OF POINTS
        ldr     r0, [v7, #+ 8]      @ Y1
        bl      StartPoint          @ v6=addr + X + Y * width
    2:
        mov     ip, r2, LSL #1
        strh    r0, [v6, ip]        @
        subs    r2, r2, #1
        bne     2b
        b       5f                  @ finished

VertLine:
        ldr     r0, [v7, #+ 8]      @ Y1
        ldr     r3, [v7, #+16]      @ Y2
        mov     r2, r3
        subs    r2, r2, r0          @ Y2 - Y1
        bge     3f
        rsb     r2, r2, #0          @ neg r2
        mov     r0, r3
    3:  add     r2, r2, #1          @ DELTA Y + 1 : # OF POINTS
        bl      StartPoint          @ v6=addr + X + Y * width
    4:
        strh    r0, [v6]
        add     v6, v6, r1          @ r1:width
        subs    r2, r2, #1
        bne     4b
    5:
        ldmfd   sp!, {v4-v7, pc}

    @-------------------------------------------------
    @ ENTRY : r0 = DY    r1 = width (bytes/line)
    @         r2 = DX
    @         v4 = incr1, v5 = incr2

SlopeLine:
        bpl     1f                  @ JUMP IF (Y2 > Y1)
        rsb     r0, r0, #0          @ - DELTA Y
        rsb     r1, r1, #0          @ - BYTES/LINE
    1:
        stmfd   sp!, {r0, r2}
        cmp     r0, r2              @ DELTA Y - DELTA X
        ble     2f                  @ JUMP IF DY <= dx ( SLOPE <= 1)
        mov     ip, r0              @ swap r0, r2
        mov     r0, r2
        mov     r2, ip

    2:
        mov     r0, r0, LSL #1      @ eax = 2 * DY
        mov     v4, r0              @ incr1 = 2 * DY
        sub     r0, r0, r2
        mov     r3, r0              @ r3 = D = 2 * DY - dx
        sub     r0, r0, r2
        mov     v5, r0              @ incr2 = D = 2 * (DY - dx)

        ldr     r0, [v7, #+ 8]      @ Y1
        adds    ip, r1, #0
        bpl     3f
        rsb     r1, r1, #0
    3:  bl      StartPoint          @ v6=addr + X + Y * width
        mov     r1, ip
        ldmfd   sp!, {r0, r2}       @ restore r0:DY, r2:DX

        cmp     r0, r2              @ DELTA Y - DELTA X
        bgt     HiSlopeLine         @ JUMP IF DY > dx ( SLOPE > 1)

LoSlopeLine:
        add     r2, r2, #1
        ldr     r0, [v7, #+20]      @ color

    1:  strh    r0, [v6], #2
        tst     r3, r3
        bpl     2f
        add     r3, r3, v4          @ incr1
        subs    r2, r2, #1
        bne     1b
        b       9f

    2:
        add     r3, r3, v5          @ incr2
        add     v6, v6, r1          @ ebx=(+/-)width
        subs    r2, r2, #1
        bne     1b
        b       9f

HiSlopeLine:
        add     r2, r0, #1          @ r2=DELTA Y + 1
        ldr     r0, [v7, #+20]      @ color

    1:  strh    r0, [v6], #2
        add     v6, v6, r1          @ v6=(+/-)width
        tst     r3, r3
        bpl     2f
        add     r3, r3, v4          @ incr1
        sub     v6, v6, #2
        subs    r2, r2, #1
        bne     1b
        b       9f

    2:  add     r3, r3, v5          @ incr2
        subs    r2, r2, #1
        bne     1b

9:      ldmfd   sp!, {v4-v7, pc}

@---------------------------------------------------------------------------
@ 引数関連共通処理
@ entry  : r3=配列変数名, v7=配列変数アドレス
@ return : v6=バッファ先頭, v5=パターン先頭, r1=スクリーン幅(byte)
@          r0=バイト/ドット
PatternSize:
        ldr     v7, [fp, r3,LSL #2] @ v7 : argument top
        ldr     v6, [v7]            @ buffer address (mem or fb)
        ldr     v5, [v7, #+20]      @ pattern
        ldr     r2, [v7, #+24]      @ ScrX
        ldr     r0, [v7, #+ 8]      @ Y
        mul     r0, r2, r0          @ Y * ScrX
        ldr     r1, [v7, #+ 4]      @ X
        add     r0, r0, r1, LSL #1  @ X * 2 + Y * ScrX
        add     v6, v6, r0          @ v6 = addr + r0
        mov     r1, r2              @ r1 = Screen Width(bytes)
        ldr     r2, [v7, #+16]      @ PatH
        ldr     r0, [v7, #+28]      @ Depth
        mov     pc, lr

@---------------------------------------------------------------------------
@ パターン転送 16bit
@   p[0] = addr   [v7, #+ 0] 転送先アドレス
@   p[1] = x      [v7, #+ 4] 転送先のX座標
@   p[2] = y      [v7, #+ 8] 転送先のY座標
@   p[3] = PatW   [v7, #+12] パターンの幅
@   p[4] = PatH   [v7, #+16] パターンの高さ
@   p[5] = mem    [v7, #+20] パターンの格納アドレス
@   p[6] = ScrX   [v7, #+24] 転送先X方向のバイト数
@   p[7] = Depth  [v7, #+28] 1ピクセルのビット数

PatternTransfer:
        stmfd   sp!, {v5-v7, lr}
        mov     r3, #'p'            @ 引数
        bl      PatternSize
    1:  ldr     r3, [v7, #+12]      @ PatW
        mov     ip, v6
    2:  ldrh    r0, [v5], #2        @ パターンから
        strh    r0, [v6], #2        @ フレームバッファへ
        subs    r3, r3, #1
        bne     2b                  @ next X
        add     v6, ip, r1          @ next Y
        subs    r2, r2, #1          @ PatH
        bne     1b
        ldmfd   sp!, {v5-v7, pc}

@---------------------------------------------------------------------------
@ パターン転送2 16bit
@   t[0] = addr   [v7, #+ 0] 転送先アドレス
@   t[1] = x      [v7, #+ 4] 転送先のX座標
@   t[2] = y      [v7, #+ 8] 転送先のY座標
@   t[3] = PatW   [v7, #+12] パターンの幅
@   t[4] = PatH   [v7, #+16] パターンの高さ
@   t[5] = mem    [v7, #+20] パターンの格納アドレス先頭
@   t[6] = ScrX   [v7, #+24] 転送先のX方向のバイト数
@   t[7] = Depth  [v7, #+28] 1ピクセルのビット数
@   t[8] = x2     [v7, #+32] 転送元のX座標
@   t[9] = y2     [v7, #+36] 転送元のY座標
@   t[10]= ScrX2  [v7, #+40] 転送元のX方向のバイト数

PatternTransfer2:
        stmfd   sp!, {v3-v7, lr}
        mov     r3, #'t             @ 引数
        bl      PatternSize
        ldr     v3, [v7, #+40]      @ ScrX2
        ldr     v4, [v7, #+36]      @ Y2
        mul     v4, v3, v4          @ Y2 * ScrX2
        ldr     v3, [v7, #+32]      @ X2
        add     v3, v4, v3,LSL #1   @ X2 * 2 + Y2 * ScrX2
        add     v4, v5, v3          @ v4 = mem + v1
        ldr     r0, [v7, #+40]      @ ScrX2
        ldr     v5, [v7, #+12]      @ PatW
    1:  mov     r3, v5              @ PatW
        stmfd   sp!, {v4, v6}
    2:  ldrh    ip, [v4], #2
        strh    ip, [v6], #2
        subs    r3, r3, #1          @ PatW
        bne     2b                  @ next X
        ldmfd   sp!, {v4, v6}
        add     v6, v6, r1          @ y++
        add     v4, v4, r0          @ y2++
        subs    r2, r2, #1          @ PatH
        bne     1b
        ldmfd   sp!, {v3-v7, pc}

@---------------------------------------------------------------------------
@ マスク付きパターン転送 16&32bit
@   q[0] = addr   [v7, #+ 0] 転送先アドレス
@   q[1] = x      [v7, #+ 4] 転送先のX座標
@   q[2] = y      [v7, #+ 8] 転送先のY座標
@   q[3] = PatW   [v7, #+12] パターンの幅
@   q[4] = PatH   [v7, #+16] パターンの高さ
@   q[5] = mem    [v7, #+20] パターンの格納アドレス
@   q[6] = ScrX   [v7, #+24] X方向のバイト数
@   q[7] = Depth  [v7, #+28] 1ピクセルのビット数
@   q[8] = Mask   [v7, #+32] マスク色
MPatternTransfer:
        stmfd   sp!, {v4-v7, lr}
        mov     r3, #'q             @ 引数
        bl      PatternSize
        ldr     v4, [v7, #+32]      @ マスク色なら書込まない
    1:  ldr     r3, [v7, #+12]      @ PatW
        mov     ip, v6
    2:  ldrh    r0, [v5], #2
        cmp     r0, v4              @ マスク色なら書込まない
        strneh  r0, [v6]
        add     v6, v6, #2          @ 常に転送先を更新
        subs    r3, r3, #1          @ PatW
        bne     2b                  @ next X
        add     v6, ip, r1
        subs    r2, r2, #1          @ PatH
        bne     1b                  @ next Y
        ldmfd   sp!, {v4-v7, pc}

@---------------------------------------------------------------------------
@ パターンフィル 16&32bit
@   r[0] = addr   [v7, #+ 0] 転送先アドレス
@   r[1] = x      [v7, #+ 4] 転送先のX座標
@   r[2] = y      [v7, #+ 8] 転送先のY座標
@   r[3] = PatW   [v7, #+12] パターンの幅
@   r[4] = PatH   [v7, #+16] パターンの高さ
@   r[5] = Color  [v7, #+20] パターンの色
@   r[6] = ScrX   [v7, #+24] X方向のバイト数
@   r[7] = Depth  [v7, #+28] 1ピクセルのビット数

PatternFill:
        stmfd   sp!, {v5-v7, lr}
        mov     r3, #'r             @ 引数
        bl      PatternSize
    1:  ldr     r3, [v7, #+12]      @ PatW
        mov     ip, v6              @ save v6
    2:  strh    v5, [v6], #2        @ フレームバッファへ
        subs    r3, r3, #1
        bne     2b                  @ next X
        add     v6, ip, r1          @ next Y
        subs    r2, r2, #1          @ PatH
        bne     1b
        ldmfd   sp!, {v5-v7, pc}

@---------------------------------------------------------------------------
@ メモリフィル 8&16&32bit
@  m[0] = addr   [v7, #+ 0] メモリフィル先頭アドレス
@  m[1] = offset [v7, #+ 4] オフセット
@  m[2] = length [v7, #+ 8] 長さ(ピクセル単位)
@  m[3] = color  [v7, #+12] 色
@  m[4] = Depth  [v7, #+16] bits/pixel

FrameBufferFill:
        stmfd   sp!, {v6, v7, lr}
        mov     r3, #'m             @ 引数は a[0] - a[4]
        ldr     v7, [fp, r3,LSL #2]
        ldr     v6, [v7]
        ldr     r0, [v7, #+ 4]      @ offset
        add     v6, v6, r0
        ldr     r2, [v7, #+ 8]      @ length (pixel)
        ldr     r0, [v7, #+12]      @ color
        ldr     r1, [v7, #+16]      @ bits/pixel
        movs    r1, r1, LSR #4
        bne     2f
    1:  strb    r0, [v6], #1        @ フレームバッファへ byte
        subs    r2, r2, #1
        bne     1b
        b       5f                  @ exit
    2:  movs    r1, r1, LSR #1
        bne     4f                  @ dword
    3:  strh    r0, [v6], #2        @ フレームバッファへ hword
        subs    r2, r2, #1
        bne     1b
        b       5f
    4:  str     r0, [v6], #4        @ フレームバッファへ word
        subs    r2, r2, #1
        bne     4b                  @ exit
    5:  ldmfd   sp!, {v6, v7, pc}

@---------------------------------------------------------------------------
@ メモリコピー
@  c[0] = source [v7, #+ 0] 転送元先頭アドレス
@  c[1] = dest   [v7, #+ 4] 転送先先頭アドレス
@  c[2] = length [v7, #+ 8] 転送バイト数
MemCopy:
        stmfd   sp!, {v6, v7, lr}
        mov     r3, #'c             @ 引数は c[0] - c[2]
        ldr     v7, [fp, r3,LSL #2]
        ldr     r3, [v7]            @ 転送元アドレス
        ldr     r2, [v7, #+ 4]      @ 転送先アドレス
        ldr     r1, [v7, #+ 8]      @ 転送バイト数
        sub     r0, r2, r3          @ r0 = 転送先 - 転送元
        bgt     2f                  @ 転送先 >= 転送元
        sub     ip, r1, #1
        add     r3, r3, ip
        add     r2, r2, ip
    1:  ldrb    r0, [r3], #-1
        strb    r0, [r2], #-1
        subs    r1, r1, #1
        bne     1b                  @
        ldmfd   sp!, {v6, v7, pc}

    2:  ldrb    r0, [r3], #1
        strb    r0, [r2], #1
        subs    r1, r1, #1
        bne     2b                  @
        ldmfd   sp!, {v6, v7, pc}
