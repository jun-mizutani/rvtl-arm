@-------------------------------------------------------------------------
@ Return of the Very Tiny Language for ARM
@ file : vtllib.s
@ 2003/11/07
@ 2009/03/15 arm eabi
@ 2012/10/24 Editor supports UTF-8.
@ 2015/09/16 Added SET_TERMIOS2
@ Copyright (C) 2003-2015 Jun Mizutani <mizutani.jun@nifty.ne.jp>
@ vtllib.s may be copied under the terms of the GNU General Public License.
@-------------------------------------------------------------------------

.ifndef __VTLLIB
__VTLLIB = 1

.include "syscalls.s"
.include "signal.s"
.include "stdio.s"
.include "syserror.s"

@==============================================================
.text

MAXLINE      = 128         @ Maximum Line Length
MAX_FILE     = 256         @ Maximum Filename
MAXHISTORY   =  16         @ No. of history buffer

TIOCGWINSZ   = 0x5413

NCCS  = 19

@  c_cc characters
VTIME     = 5
VMIN      = 6

@  c_lflag bits
ISIG      = 0000001
ICANON    = 0000002
XCASE     = 0000004
ECHO      = 0000010
ECHOE     = 0000020
ECHOK     = 0000040
ECHONL    = 0000100
NOFLSH    = 0000200
TOSTOP    = 0000400
ECHOCTL   = 0001000
ECHOPRT   = 0002000
ECHOKE    = 0004000
FLUSHO    = 0010000
PENDIN    = 0040000
IEXTEN    = 0100000

TCGETS    = 0x5401
TCSETS    = 0x5402

SEEK_SET  = 0               @ Seek from beginning of file.
SEEK_CUR  = 1               @ Seek from current position.
SEEK_END  = 2               @ Seek from end of file.

@ from include/linux/wait.h
WNOHANG   = 0x00000001
WUNTRACED = 0x00000002

@ from include/asm-i386/fcntl.h
O_RDONLY =    00
O_WRONLY =    01
O_RDWR   =    02
O_CREAT  =  0100
O_EXCL   =  0200
O_NOCTTY =  0400
O_TRUNC  = 01000

S_IFMT   = 0170000
S_IFSOCK = 0140000
S_IFLNK  = 0120000
S_IFREG  = 0100000
S_IFBLK  = 0060000
S_IFDIR  = 0040000
S_IFCHR  = 0020000
S_IFIFO  = 0010000
S_ISUID  = 0004000
S_ISGID  = 0002000
S_ISVTX  = 0001000

S_IRWXU  = 00700
S_IRUSR  = 00400
S_IWUSR  = 00200
S_IXUSR  = 00100

S_IRWXG  = 00070
S_IRGRP  = 00040
S_IWGRP  = 00020
S_IXGRP  = 00010

S_IRWXO  = 00007
S_IROTH  = 00004
S_IWOTH  = 00002
S_IXOTH  = 00001

@ from include/linux/fs.h
MS_RDONLY       =  1        @ Mount read-only
MS_NOSUID       =  2        @ Ignore suid and sgid bits
MS_NODEV        =  4        @ Disallow access to device special files
MS_NOEXEC       =  8        @ Disallow program execution
MS_SYNCHRONOUS  = 16        @ Writes are synced at once
MS_REMOUNT      = 32        @ Alter flags of a mounted FS

/*------------------------------------------------------------------------
  v1-v8 は保存されるが内部的には次のように使用する
    v1   @ Input Buffer, 作業用レジスタ
    v2   @ BufferSize, FileNameBuffer(FileCompletion)
    v3   @ history string ptr, FNBPointer
    v4   @ 行末位置         (0..v2-1)
    v5   @ current position (0..v2-1)  memory address[v1+v5]
    v6   @ DirName
    v7   @ FNArray ファイル名へのポインタ配列(FileCompletion)
    v8   @ PartialName 入力バッファ内へのポインタ
------------------------------------------------------------------------*/

@-------------------------------------------------------------------------
@ 編集付き行入力(初期文字列付き)
@   r0:バッファサイズ, r1:バッファ先頭
@   r0 に入力文字数を返す
@-------------------------------------------------------------------------
        .align  2
READ_LINE2:
        ldr     r2, LINE_TOP
        ldr     r3, [r2]
        str     r3, [r2, #4]        @ FLOATING_TOP=LINE_TOP
        stmfd   sp!, {r1-r2, v1-v5, lr}
        mov     ip, r0              @ バッファサイズ退避
        mov     r2, r1              @ 入力バッファ先頭退避
        mov     r0, r1              @ 入力バッファ表示
        bl      OutAsciiZ
        bl      StrLen              @ <r0:アドレス, >r1:文字数
        mov     v4, r1              @ 行末位置
        mov     r1, r2              @ バッファ先頭復帰
        mov     r0, ip              @ バッファサイズ復帰
        b       RL_0

@-------------------------------------------------------------------------
@ 編集付き行入力
@   r0:バッファサイズ, r1:バッファ先頭
@   r0 に入力文字数を返す
@   カーソル位置を取得して行頭を保存, 複数行にわたるペースト不可
@-------------------------------------------------------------------------
READ_LINE3:
        stmfd   sp!, {lr}
        bl      get_cursor_position
        ldmfd   sp!, {lr}
        b       RL

@-------------------------------------------------------------------------
@ 編集付き行入力
@   r0:バッファサイズ, r1:バッファ先頭
@   r0 に入力文字数を返す
@-------------------------------------------------------------------------
READ_LINE:
        ldr     r2, LINE_TOP
        ldr     r3, [r2]
        str     r3, [r2, #4]        @ FLOATING_TOP=LINE=TOP
RL:     stmfd   sp!, {r1-r2, v1-v5, lr}
        mov     v4, #0              @ 行末位置
RL_0:
        ldr     v3, HistLine        @ history string ptr
        mov     v1, r1              @ Input Buffer
        mov     r2, #0
        strb    r2, [v1, v4]        @ mark EOL
        mov     v2, r0              @ BufferSize
        mov     v5, v4              @ current position
RL_next_char:
        bl      InChar
        cmp     r0, #0x1B           @ ESC ?
        bne     1f
        bl      translate_key_seq
    1:  cmp     r0, #0x09           @ TAB ?
        beq     RL_tab
        cmp     r0, #127            @ BS (linux console) ?
        beq     RL_bs
        cmp     r0, #0x08           @ BS ?
        beq     RL_bs
        cmp     r0, #0x04           @ ^D ?
        beq     RL_delete
        cmp     r0, #0x02           @ ^B
        beq     RL_cursor_left
        cmp     r0, #0x06           @ ^F
        beq     RL_cursor_right
        cmp     r0, #0x0E           @ ^N
        beq     RL_forward
        cmp     r0, #0x10           @ ^P
        beq     RL_backward
        cmp     r0, #0x0A           @ enter ?
        beq     RL_in_exit
        cmp     r0, #0x20
        blo     RL_next_char        @ illegal chars
RL_in_printable:
        add     v4, v4, #1          @ eol
        add     v5, v5, #1          @ current position
        cmp     v4, v2              @ buffer size
        bhs     RL_in_toolong
        cmp     v5, v4              @ at eol?
        blo     RL_insert           @  No. Insert Char
        bl      OutChar             @  Yes. Display Char
        sub     ip, v5, #1          @ before cursor
        strb    r0, [v1, +ip]
        b       RL_next_char
RL_insert:
        cmp     r0, #0x80
        bllo    OutChar
        sub     ip, v4, #1          @ p = eol-1
    1:
        cmp     v5, ip              @ while(p=>cp){buf[p]=buf[p-1]; p--}
        bhi     2f                  @   if(v5>ip) goto2
        sub     r1, ip, #1          @   r1=ip-1
        ldrb    r2, [v1, +r1]
        strb    r2, [v1, +ip]
        mov     ip, r1              @ ip--
        b       1b
    2:
        sub     ip, v5, #1
        strb    r0, [v1, +ip]       @ before cursor

        cmp     r0, #0x80
        bhs     3f
        bl      print_line_after_cp
        b       RL_next_char
    3:
        bl      print_line
        b       RL_next_char
RL_in_toolong:
        sub     v4, v4, #1
        sub     v5, v5, #1
        b       RL_next_char
RL_in_exit:
        bl      regist_history
        bl      NewLine
        mov     r0, v4              @ eax に文字数を返す
        ldmfd   sp!, {r1-r2, v1-v5, pc}    @ return

@-------------------------------------------------------------------------
@ BackSpace or Delete Character
@-------------------------------------------------------------------------
RL_bs:
        tst     v5, v5              @ if cp=0 then next_char
        beq     RL_next_char
        bl      cursor_left

  RL_delete:
        cmp     v5, v4              @ if cp < eol then del2
        beq     RL_next_char        @ 行末でDELでは何もしない
        ldrb    r0, [v1, v5]        @ 1文字目確認
        and     r0, r0, #0xC0
        cmp     r0, #0xC0
        bne     1f
        adr     r0, DEL_AT_CURSOR   @ 漢字なら2回1文字消去
        bl      OutPString
    1:  bl      RL_del1_char        @ 1文字削除
        cmp     v5, v4              @ if cp < eol then del2
        beq     2f                  @ 行末なら終了
        ldrb    r0, [v1, v5]        @ 2文字目文字取得
        and     r0, r0, #0xC0
        cmp     r0, #0x80
        beq     1b                  @ UTF-8 後続文字 (ip==0x80)
    2:  adr     r0, DEL_AT_CURSOR   @ 1文字消去
        bl      OutPString
        b       RL_next_char

 RL_del1_char:                      @ while(p<eol){*p++=*q++;}
        stmfd   sp!, {r1-r3, lr}
        add     r2, v5, v1          @ p
        add     r1, v4, v1          @ eol
        add     r3, r2, #1          @ q=p+1
    1:  ldrb    r0, [r3], #1        @ *p++ = *q++;
        strb    r0, [r2], #1
        cmp     r3, r1
        bls     1b
        sub     v4, v4, #1
        ldmfd   sp!, {r1-r3, pc}    @ return

@-------------------------------------------------------------------------
@ Filename Completion
@-------------------------------------------------------------------------
RL_tab:
        bl      FilenameCompletion  @ ファイル名補完
        bl      DispLine
        b       RL_next_char

@-------------------------------------------------------------------------
RL_cursor_left:
        bl      cursor_left
        b       RL_next_char

cursor_left:
        stmfd   sp!, {lr}
        tst     v5, v5              @ if cp = 0 then next_char
        beq     2f                  @ 先頭なら何もしない
        adr     r0, CURSOR_LEFT     @ カーソル左移動、
        bl      OutPString
    1:
        sub     v5, v5, #1          @ 文字ポインタ-=1
        ldrb    r0, [v1, v5]        @ 文字取得
        and     r0, r0, #0xC0
        cmp     r0, #0x80
        beq     1b                  @ 第2バイト以降のUTF-8文字
        blo     2f                  @ ASCII
        adr     r0, CURSOR_LEFT     @ 第1バイト発見、日本語は2回左
        bl      OutPString
    2:
        ldmfd   sp!, {pc}           @ return

@-------------------------------------------------------------------------
RL_cursor_right:
        bl      cursor_right
        b       RL_next_char

cursor_right:
        stmfd   sp!, {lr}
        cmp     v4, v5              @ if cp=eol then next_char
        beq     3f                  @ 行末なら何もしない
        adr     r0, CURSOR_RIGHT
        bl      OutPString

        ldrb    r0, [v1, v5]        @ 文字取得
        mov     ip, r0, LSL #24
        ands    ip, ip, #0xF0000000
        bmi     1f                  @ UTF-8多バイト文字の場合
        add     v5, v5, #1          @ ASCIIなら1バイトだけ
        b       3f
    1:
        add     v5, v5, #1          @ 最大4byteまで文字位置を更新
        movs    ip, ip, LSL #1
        bmi     1b
    2:
        adr     r0, CURSOR_RIGHT
        bl      OutPString
    3:
        ldmfd   sp!, {pc}           @ return

@-------------------------------------------------------------------------
RL_forward:
        bl      regist_history      @ 入力中の行をヒストリへ
        mov     r0, #1
        bl      next_history
        b       RL_disp
RL_backward:
        bl      regist_history      @ 入力中の行をヒストリへ
        mov     r0, #-1
        bl      next_history
RL_disp:
        and     r0, r0, #0x0F       @ ヒストリは 0-15
        str     r0, [v3]            @ HistLine
        bl      history2input       @ ヒストリから入力バッファ
        bl      DispLine
        b       RL_next_char

@-------------------------------------------------------------------------

                .align      2
CURSOR_REPORT:  .byte       4, 0x1B
                .ascii      "[6n"               @ ^[[6n
                .align      2
SAVE_CURSOR:    .byte       2, 0x1B, '7         @ ^[7
                .align      2
RESTORE_CURSOR: .byte       2, 0x1B, '8         @ ^[8
                .align      2
DEL_AT_CURSOR:  .byte       4, 0x1B
                .ascii      "[1P"               @ ^[[1P
                .align      2
CURSOR_RIGHT:   .byte       4, 0x1B
                .ascii      "[1C"               @ ^[[1C
                .align      2
CURSOR_LEFT:    .byte       4, 0x1B
                .ascii      "[1D"               @ ^[[1D
                .align      2
CURSOR_TOP:     .byte       1, 0x0D
                .align      2
CLEAR_EOL:      .byte       4, 0x1B
                .ascii      "[0K"               @ ^[[0K
                .align      2
CSI:            .byte       2, 0x1B, '[         @ ^[[
                .align      2

@ Variable
HistLine:       .long       HistLine0    @ 表示位置
HistUpdate:     .long       HistUpdate0  @ 更新位置
HistTop:        .long       history0
LINE_TOP:       .long       LINE_TOP0    @ No. of prompt characters
FLOATING_TOP:   .long       FLOATING_TOP0

.data
LINE_TOP0:      .long       7            @ No. of prompt characters
FLOATING_TOP0:  .long       7            @ Save cursor position

.text
@-------------------------------------------------------------------------
@ 行頭マージン設定
@   r0 : 行頭マージン設定
@-------------------------------------------------------------------------
set_linetop:
        stmfd   sp!, {r1, lr}
        ldr     r1, LINE_TOP
        str     r0, [r1]
        ldmfd   sp!, {r1, pc}

@--------------------------------------------------------------
@ 入力バッファをヒストリへ登録
@   v1 : input buffer address
@   v3 : history string ptr
@   v4 : eol (length of input string)
@   r0,r1,r2,r3 : destroy
@--------------------------------------------------------------
regist_history:
        stmfd   sp!, {lr}
        mov     r0, #0
        strb    r0, [v1, v4]        @ write 0 at eol
        bl      check_history
        tst     r1, r1
        beq     1f                  @ 同一行登録済み

        ldr     r0, [v3, #+4]       @ HistUpdate
        bl      input2history
        ldr     r0, [v3, #+4]       @ HistUpdate
        add     r0, r0, #1
        and     r0, r0, #0x0F       @ 16entry
        str     r0, [v3, #+4]       @ HistUpdate
        str     r0, [v3]            @ HistLine
    1:  ldmfd   sp!, {pc}           @ return

@--------------------------------------------------------------
@ ヒストリを r0 (1または-1) だけ進める
@    return : r0 = next entry
@--------------------------------------------------------------
next_history:
        stmfd   sp!, {r1-r3, v1, lr}
        ldr     v1, [v3]           @ HistLine
        mov     r2, #MAXHISTORY
        mov     r3, r0
    1:  subs    r2, r2, #1         @
        blt     2f                 @ すべて空なら終了
        add     v1, v1, r3         @ +/-1
        and     v1, v1, #0x0F      @ wrap around
        mov     r0, v1             @ 次のエントリー
        bl      GetHistory         @ r0 = 先頭アドレス
        bl      StrLen             @ <r0:アドレス, >r1:文字数
        tst     r1, r1
        beq     1b                 @ 空行なら次
    2:
        mov     r0, v1             @ エントリーを返す
        ldmfd   sp!, {r1-r3, v1, pc}   @ return

@--------------------------------------------------------------
@ すべてのヒストリ内容を表示
@--------------------------------------------------------------
disp_history:
        stmfd   sp!, {r0-r3, lr}
        ldr     r2, HistTop
        mov     r3, #0             @ no. of history lines
    1:
        ldr     r1, HistLine
        ldr     r0, [r1]
        cmp     r3, r0
        moveq   r0, #'*'
        movne   r0, #' '
        bl      OutChar

        mov     r0, r3             @ ヒストリ番号
        mov     r1, #2             @ 2桁
        bl      PrintRight0
        mov     r0, #' '
        bl      OutChar
        mov     r0, r2
        bl      OutAsciiZ
        bl      NewLine
        add     r2, r2, #MAXLINE   @ next history string
        add     r3, r3, #1
        cmp     r3, #MAXHISTORY
        bne     1b                 @ check next
        ldmfd   sp!, {r0-r3, pc}   @ return

@--------------------------------------------------------------
@ すべてのヒストリ内容を消去
@--------------------------------------------------------------
erase_history:
        stmfd   sp!, {r0-r2, lr}
        ldr     r2, HistTop
        mov     r1, #0             @ no. of history lines
        mov     r0, #0
    1:  str     r0, [r2]
        add     r2, r2, #MAXLINE   @ next history
        add     r1, r1, #1
        cmp     r1, #MAXHISTORY
        bne     1b                 @ check next
        ldmfd   sp!, {r0-r2, pc}   @ return

@--------------------------------------------------------------
@ 入力バッファと同じ内容のヒストリバッファがあるかチェック
@   v1 : input buffer address
@   v4 : eol (length of input string)
@   r1 : if found then return 0
@   r0,r2,r3 : destroy
@--------------------------------------------------------------
check_history:
        stmfd   sp!, {v1-v3, lr}
        mov     v3, v1             @ save input buffer top
        ldr     v2, HistTop
        mov     r3, #MAXHISTORY    @ no. of history lines
    1:
        mov     v1, v3             @ restore input buffer top
        mov     r2, #0             @ string top

    2:  ldrb    r0, [v1], #1       @ compare char, v1++
        ldrb    r1, [v2, +r2]
        cmp     r0, r1
        bne     3f                 @ different char
        tst     r0, r0             @ eol ?
        beq     4f                 @ found
        add     r2, r2, #1         @ next char
        b       2b

    3:  add     v2, v2, #MAXLINE   @ next history string
        subs    r3, r3, #1
        bne     1b                 @ check next

        mov     r1, #1             @ compare all, not found
        ldmfd   sp!, {v1-v3, pc}   @ return

    4:  mov     r1, #0             @ found
        ldmfd   sp!, {v1-v3, pc}   @ return

@--------------------------------------------------------------
@ 入力バッファのインデックスをアドレスに変換
@   enter  r0 : ヒストリバッファのインデックス (0..15)
@   exit   r0 : historyinput buffer top address
@--------------------------------------------------------------
GetHistory:
        stmfd   sp!, {r1, r2, lr}
        mov     r1, #MAXLINE
        ldr     r2, HistTop
        mla     r0, r1, r0, r2     @ r0=r1*r0+r2
        ldmfd   sp!, {r1, r2, pc}  @ return

@--------------------------------------------------------------
@ 入力バッファからヒストリバッファへコピー
@   r0 : ヒストリバッファのインデックス (0..15)
@   v1 : input buffer
@--------------------------------------------------------------
input2history:
        stmfd   sp!, {r0-r1, v1, lr}
        mov     r1, v1
        bl      GetHistory
        mov     v1, r0
        b       1f

@--------------------------------------------------------------
@ ヒストリバッファから入力バッファへコピー
@   r0 : ヒストリバッファのインデックス (0..15)
@   v1 : input buffer
@--------------------------------------------------------------
history2input:
        stmfd   sp!, {r0-r1, v1, lr}
        bl      GetHistory
        mov     r1, r0
    1:  ldrb    r0, [r1], #1
        strb    r0, [v1], #1
        cmp     r0, #0
        bne     1b
        ldmfd   sp!, {r0-r1, v1, pc}        @ return

@--------------------------------------------------------------
@  入力バッファをプロンプト直後の位置から表示してカーソルは最終
@  entry  v1 : 入力バッファの先頭アドレス
@--------------------------------------------------------------
DispLine:
        stmfd   sp!, {lr}
        bl      LineTop                 @ カーソルを行先頭に
        mov     r0, v1
        bl      OutAsciiZ               @ 入力バッファを表示
        adr     r0, CLEAR_EOL
        bl      OutPString
        mov     r0, v1
        bl      StrLen                  @ <r0:アドレス, >r1:文字数
        mov     v4, r1                  @ 入力文字数更新
        mov     v5, v4                  @ 入力位置更新
        ldmfd   sp!, {pc}               @ return

@--------------------------------------------------------------
@ カーソル位置を取得
get_cursor_position:
        stmfd   sp!, {r0-r3, lr}
        adr     r0, CURSOR_REPORT
        bl      OutPString
        bl      InChar                  @ 返り文字列
        cmp     r0, #0x1B               @ ^[[y@xR
        bne     1f
        bl      InChar
        cmp     r0, #'['
        bne     1f
        bl      get_decimal             @ Y
        mov     r3, r1
        bl      get_decimal             @ X
        sub     r1, r1, #1
        ldr     r0, FLOATING_TOP
        str     r1, [r0]                @ 左マージン
    1:  ldmfd   sp!, {r0-r3, pc}        @ return

get_decimal:
        stmfd   sp!, {r3, lr}
        mov     r1, #0
        mov     r3, #10
        bl      InChar
        sub     r0, r0, #'0
    1:  mul     r2, r1, r3              @
        add     r1, r0, r2
        bl      InChar
        sub     r0, r0, #'0
        cmp     r0, #9
        ble     1b
        ldmfd   sp!, {r3, pc}           @ return

@--------------------------------------------------------------
@ v5 = cursor position
print_line_after_cp:
        stmfd   sp!, {lr}
        adr     r0, SAVE_CURSOR
        bl      OutPString
        adr     r0, CLEAR_EOL
        bl      OutPString
        add     r0, v5, v1              @ address
        sub     r1, v4, v5              @ length
        bl      OutString
        adr     r0, RESTORE_CURSOR
        bl      OutPString
        ldmfd   sp!, {pc}               @ return

@--------------------------------------------------------------
@
print_line:
        stmfd   sp!, {lr}
        bl      LineTop
        mov     r0, v1                  @ address
        mov     r1, v4                  @ length
        bl      OutString
        bl      setup_cursor
        ldmfd   sp!, {pc}               @ return

setup_cursor:
        stmfd   sp!, {lr}
        bl      LineTop
        mov     r1, #0
        cmp     r1, v5
        beq     4f
    1:  ldrb    r0, [v1, r1]
        and     r0, r0, #0xC0
        cmp     r0, #0x80               @ 第2バイト以降のUTF-8文字
        beq     3f
        blo     2f
        adr     r0, CURSOR_RIGHT
        bl      OutPString
    2:  adr     r0, CURSOR_RIGHT
        bl      OutPString
    3:  add     r1, r1, #1
        cmp     r1, v5
        bne     1b
    4:  ldmfd   sp!, {pc}     @ return

@--------------------------------------------------------------
@ Translate Function Key into ctrl-sequence
translate_key_seq:
        stmfd   sp!, {lr}
        bl      InChar
        cmp     r0, #'[
        movne   r0, #0
        ldmnefd sp!, {pc}           @ return
        bl      InChar
        cmp     r0, #'A
        moveq   r0, #'P - 0x40      @ ^P
        ldmeqfd sp!, {pc}           @ return
        cmp     r0, #'B
        moveq   r0, #'N - 0x40      @ ^N
        ldmeqfd sp!, {pc}           @ return
        cmp     r0, #'C
        moveq   r0, #'F - 0x40      @ ^F
        ldmeqfd sp!, {pc}           @ return
        cmp     r0, #'D
        moveq   r0, #'B - 0x40      @ ^B
        ldmeqfd sp!, {pc}           @ return
        cmp     r0, #'3             @ ^[[3~ (Del)
        cmpne   r0, #'4             @ ^[[4~ (End)
        ldmnefd sp!, {pc}           @ return
        bl      InChar
        cmp     r0, #'~
        moveq   r0, #4              @ ^D
        ldmfd   sp!, {pc}           @ return

@--------------------------------------------------------------
@ 行先頭にカーソルを移動(左マージン付)
LineTop:
        stmfd   sp!, {r0-r2, lr}
        adr     r0, CURSOR_TOP
        bl      OutPString
        adr     r0, CURSOR_RIGHT
        ldr     r2, FLOATING_TOP        @ 左マージン
        ldr     r2, [r2]
        tst     r2, r2                  @ if 0 return
        beq     2f
    1:  bl      OutPString
        subs    r2, r2, #1
        bne     1b
    2:  ldmfd   sp!, {r0-r2, pc}        @ return

@--------------------------------------------------------------
@  ファイル名補完機能
@  entry  v5 : 次に文字が入力される入力バッファ中の位置
@         v1 : 入力バッファの先頭アドレス
@--------------------------------------------------------------
FilenameCompletion:
        stmfd   sp!, {r0-r2, v1-v8, lr}
        ldr     v2, FileNameBuffer      @ FileNameBuffer初期化
        ldr     v6, DirName
        ldr     v7, FNArray             @ ファイル名へのポインタ配列
        ldr     v8, PartialName         @ 入力バッファ内のポインタ
        bl      ExtractFilename         @ 入力バッファからパス名を取得
        ldrb    r0, [v1]                @ 行頭の文字
        cmp     r0, #0                  @ 行の長さ0？
        beq     1f
        bl      GetDirectoryEntry       @ ファイル名をコピー
        bl      InsertFileName          @ 補完して入力バッファに挿入
    1:
        ldmfd   sp!, {r0-r2, v1-v8, pc}

@==============================================================
                .align  2
NoCompletion:   .asciz  "<none>"
                .align  2
current_dir:    .asciz  "./"
                .align  2
DirName:        .long   DirName0
PathName:       .long   PathName0
PartialName:    .long   PartialName0
FileNameBuffer: .long   FileNameBuffer0
FNArray:        .long   FNArray0
FNBPointer:     .long   FNBPointer0
FNCount:        .long   FNCount0
dir_ent:        .long   dir_ent0        @ 256 bytes
file_stat:      .long   file_stat0      @ 64 bytes
                .align  2

@--------------------------------------------------------------
@ 一致したファイル名が複数なら表示し、なるべく長く補完する。
@
@ 一致するファイル名なしなら、<none>を入力バッファに挿入
@ 完全に一致したらファイル名をコピー
@ 入力バッファ末に0を追加、次に入力される入力バッファ中の位置
@ を更新. 入力バッファ中の文字数(v5)を返す。
@--------------------------------------------------------------
InsertFileName:
        stmfd   sp!, {r0-r3, v8, lr}
        tst     v4, v4                  @ FNCount ファイル数
        adreq   r3, NoCompletion        @ <none>を入力バッファに挿入
        beq     6f                      @ 一致するファイル名なし
        ldr     r0, [v8]                @ 部分ファイル名
        bl      StrLen                  @ r1 = 部分ファイル名長
        cmp     v4, #1                  @ ひとつだけ一致?
        ldreq   r0, [v7]
        addeq   r3, r0, r1              @ r3 = FNArray[0] + r1
        beq     6f                      @ 入力バッファにコピー
        bl      ListFile                @ ファイルが複数なら表示

        @ 複数が一致している場合なるべく長く補完
        @ 最初のエントリーと次々に比較、すべてのエントリーが一致していたら
        @ 比較する文字を1つ進める。一致しない文字が見つかったら終わり
        mov     r2, #0                  @ 追加して補完できる文字数
    1:
        sub     v8, v4, #1              @ ファイル数-1
        ldr     r0, [v7]                @ 最初のファイル名と比較
        add     r3, r0, r1              @ r3 = FNArray[0] + 部分ファイル名長
        ldrb    r0, [r3, +r2]           @ r0 = (FNArray[0] + 一致長 + r2)
    2:
        ldr     ip, [v7, v8,LSL #2]     @ ip = &FNArray[v8]
        add     ip, ip, r1              @ ip = FNArray[v8] + 一致長
        ldrb    ip, [ip, +r2]           @ ip = FNArray[v8] + 一致長 + r2
        cmp     r0, ip
        bne     3f                      @ 異なる文字発見
        subs    v8, v8, #1              @ 次のファイル名
        bne     2b                      @ すべてのファイル名で繰り返し

        add     r2, r2, #1              @ 追加して補完できる文字数を+1
        b       1b                      @ 次の文字を比較
    3:
        cmp     r2, #0                  @ 追加文字なし
        beq     9f                      @ 複数あるが追加補完不可

    4:
        ldrb    r0, [r3]                @ 補完分をコピー
        strb    r0, [v1, +v5]           @ 入力バッファに追加
        subs    r2, r2, #1
        bmi     8f                      @ 補完部分コピー終了
        add     r3, r3, #1              @ 次の文字
        add     v5, v5, #1
        b       4b                      @

    6:
        ldrb    r0, [r3]                @ ファイル名をコピー
        strb    r0, [v1, v5]            @ 入力バッファに追加
        add     r3, r3, #1              @ 次の文字
        add     v5, v5, #1
        tst     r0, r0                  @ 文字列末の0で終了
        bne     6b

    9:  ldmfd   sp!, {r0-r3, v8, pc}    @ return

    8:
        mov     r0, #0                  @ 補完終了
        strb    r0, [v1, v5]            @ 入力バッファ末を0
        ldmfd   sp!, {r0-r3, v8, pc}    @ return

@--------------------------------------------------------------
@ 入力中の文字列からディレクトリ名と部分ファイル名を抽出して
@ バッファ DirName(v6), PartialName(v8,ポインタ)に格納
@ TABキーが押されたら入力バッファの最後の文字から逆順に
@ スキャンして、行頭またはスペースまたは " を探す。
@ 行頭またはスペースの後ろから入力バッファの最後までの
@ 文字列を解析してパス名(v6)とファイル名(v8)バッファに保存
@  entry  v5 : 次に文字が入力される入力バッファ中の位置
@         v1 : 入力バッファの先頭アドレス
@--------------------------------------------------------------
ExtractFilename:
        stmfd   sp!, {lr}
        add     r3, v5, v1              @ (入力済み位置+1)をコピー
        mov     r1, r3
        mov     r0, #0
        strb    r0, [r1]                @ 入力済み文字列末をマーク
        mov     v3, v2                  @ FNBPointer=FileNameBuffer
        mov     v4, #0                  @ FNCount=0
    1:
                                        @ 部分パス名の先頭を捜す
        ldrb    r0, [r1]                @ カーソル位置から前へ
        cmp     r0, #0x20               @ 空白はパス名の区切り
        beq     2f                      @ 空白なら次の処理
        cmp     r0, #'"                 @ 二重引用符もパス名の区切り
        beq     2f                      @ 二重引用符でも次の処理
        cmp     r1, v1                  @ 行頭をチェック
        beq     3f                      @ 行頭なら次の処理
        sub     r1, r1, #1              @ 後ろから前に検索
        b       1b                      @ もう一つ前を調べる

    2:  add     r1, r1, #1              @ 発見したので先頭に設定
    3:
        ldrb    r0, [r1]
        cmp     r0, #0                  @ 文末？
        bne     4f
        ldmfd   sp!, {pc}               @ 何もない(長さ0)なら終了

    4:  sub     r3, r3, #1              @ 入力済み文字列最終アドレス
        ldrb    r0, [r3]
        cmp     r0, #'/                 @ ディレクトリ部分を抽出
        addeq   r3, r3, #1              @ ファイル名から/を除く
        beq     5f                      @ 区切り発見
        cmp     r1, r3                  @ ディレクトリ部分がない?
        bne     4b
    5:                                  @ ディレクトリ名をコピー
        mov     r0, #0
        strb    r0, [v6]                @ ディレクトリ名バッファを空に
        str     r3, [v8]                @ 部分ファイル名先頭
        subs    r2, r3, r1              @ r2=ディレクトリ名文字数
        beq     8f                      @ ディレクトリ部分がない

        mov     ip, v6                  @ DirName
    7:
        ldrb    r0, [r1],#1             @ コピー
        strb    r0, [ip],#1             @ ディレクトリ名バッファ
        subs    r2, r2, #1
        bne     7b
        mov     r0, #0
        strb    r0, [ip]                @ 文字列末をマーク
    8:  ldmfd   sp!, {pc}               @ リターン

@-------------------------------------------------------------------------
@ ディレクトリ中のエントリをgetdentsで取得(1つとは限らないのか?)して、
@ 1つづつファイル/ディレクトリ名をlstatで判断し、
@ ディレクトリ中で一致したファイル名をファイル名バッファに書き込む。
@-------------------------------------------------------------------------
GetDirectoryEntry:
        stmfd   sp!, {r0-r3, v1, lr}
        ldrb    r0, [v6]                @ ディレクトリ部分の最初の文字
        tst     r0, r0                  @ 長さ 0 か?
        adreq   r0, current_dir         @ ディレクトリ部分がない時
        movne   r0, v6                  @ ディレクトリ名バッファ
        bl      fropen                  @ ディレクトリオープン
        bmi     4f
        mov     r3, r0                  @ fd 退避
    1:                                  @ ディレクトリエントリを取得
        mov     r0, r3                  @ fd 復帰
        ldr     r1, dir_ent             @ dir_ent格納先頭アドレス
        mov     v1, r1                  @ v1 : dir_entへのポインタ
        ldr     r2, size_dir_ent        @ dir_ent格納領域サイズ
        stmfd   sp!, {r7}               @ save v4
        mov     r7, #sys_getdents       @ dir_entを複数返す
        swi     0
        tst     r0, r0                  @ valid buffer length
        ldmfd   sp!, {r7}               @ restore v4
        blmi    SysCallError            @ システムコールエラー
        beq     4f                      @ 終了
        mov     r2, r0                  @ r2 : buffer size
    2:
        mov     r1, v1                  @ v1 : dir_entへのポインタ
        bl      GetFileStat             @ ファイル情報を取得
        ldr     r1, file_stat
        ldrh    r0, [r1, #+8]           @ file_stat.st_mode
        and     r0, r0, #S_IFDIR        @ ディレクトリ?
        add     r1, v1, #10             @ ファイル名先頭アドレス
        bl      CopyFilename            @ 一致するファイル名を収集

        @ sys_getdentsが返したエントリが複数の場合には次のファイル
        @ 1つなら次のディレクトリエントリを得る。
        add     r1, v1, #8              @ レコード長アドレス
        ldrh    r0, [r1]                @ rec_len レコード長
        subs    r2, r2, r0              @ buffer_size - rec_len
        beq     1b                      @ 次のディレクトリエントリ取得
        add     v1, v1, r0              @ 次のファイル名の格納領域に設定
        mov     r1, v1
        b       2b                      @ 次のファイル情報を取得

    4:
        mov     r0, r3                  @ fd
        bl      fclose                  @ ディレクトリクローズ
        ldmfd   sp!, {r0-r3, v1, pc}    @ return

size_dir_ent:  .long size_dir_ent0

@--------------------------------------------------------------
@ DirNameとdir_ent.dnameからPathNameを作成
@ PathNameのファイルの状態をfile_stat構造体に取得
@ entry
@   r1 : dir_entアドレス
@   v6 : DirName
@   DirName にディレクトリ名
@--------------------------------------------------------------
GetFileStat:
        stmfd   sp!, {r0-r3,v1,r7,lr}
        add     r2, r1, #10             @ dir_ent.d_name + x
        ldr     r3, PathName            @ PathName保存エリア
        mov     ip, r3
        mov     r0, v6                  @ DirNameディレクトリ名保存アドレス
        bl      StrLen                  @ ディレクトリ名の長さ取得>r1
        tst     r1, r1
        beq     2f
    1:
        ldrb    v1, [r0], #1            @ ディレクトリ名のコピー
        strb    v1, [ip], #1            @ PathNameに書き込み
        subs    r1, r1, #1              @ -1になるため, bne不可
        bne     1b
    2:  mov     r0, r2                  @ ファイル名の長さ取得
        bl      StrLen                  @ <r0:アドレス, >r1:文字数
    3:
        ldrb    v1, [r2], #1            @ ファイル名のコピー
        strb    v1, [ip], #1            @ PathNameに書き込み
        subs    r1, r1, #1
        bne     3b
        strb    r1, [ip]                @ 文字列末(0)をマーク
        mov     r0, r3                  @ パス名先頭アドレス
        ldr     r1, file_stat           @ file_stat0のアドレス
        mov     r7, #sys_lstat          @ ファイル情報の取得
        swi     0
        tst     r0, r0                  @ valid buffer length
        blmi    SysCallError            @ システムコールエラー
        ldmfd   sp!, {r0-r3,v1,r7,pc}   @ return

@--------------------------------------------------------------
@ ディレクトリ中で一致したファイル名をファイル名バッファ
@ (FileNameBuffer)に書き込む
@ ファイル名がディレクトリ名なら"/"を付加する
@ entry r0 : ディレクトリフラグ
@       r1 : ファイル名先頭アドレス
@       v8 : 部分ファイル名先頭アドレス格納領域へのポインタ
@--------------------------------------------------------------
CopyFilename:
        stmfd   sp!, {r0-r3, v1, lr}
        cmp     v4, #MAX_FILE           @ v4:FNCount 登録ファイル数
        bhs     5f
        mov     r3, r1                  @ ファイル名先頭アドレス
        mov     v1, r0                  @ ディレクトリフラグ
        ldr     r2, [v8]                @ v8:PartialName
    1:
        ldrb    r0, [r2], #1            @ 部分ファイル名
        tst     r0, r0                  @ 文字列末?
        beq     2f                      @ 部分ファイル名は一致
        ldrb    ip, [r1], #1            @ ファイル名
        cmp     r0, ip                  @ 1文字比較
        bne     5f                      @ 異なれば終了
        b       1b                      @ 次の文字を比較

    2:  @ 一致したファイル名が格納できるかチェック
        mov     r0, r3                  @ ファイル名先頭アドレス
        bl      StrLen                  @ ファイル名の長さを求める
        mov     r2, r1                  @ ファイル名の長さを退避
        add     ip, r1, #2              @ 文字列末の '/#0'
        add     ip, ip, v3              @ 追加時の最終位置 v3:FNBPointer
        cmp     ip, v7                  @ FileNameBufferの直後(FNArray0)
        bhs     5f                      @ バッファより大きくなる:終了
        @ ファイル名バッファ中のファイル名先頭アドレスを記録
        str     v3, [v7, v4,LSL #2]     @ FNArray[FNCount]=ip
        add     v4, v4, #1              @ ファイル名数の更新
    3:
        ldrb    ip, [r3], #1            @ ファイル名のコピー
        strb    ip, [v3], #1
        subs    r2, r2, #1              @ ファイル名の長さを繰り返す
        bne     3b

        tst     v1, v1                  @ ディレクトリフラグ
        movne   r0, #'/'                @ ディレクトリ名なら"/"付加
        strneb  r0, [v3], #1
        mov     r0, #0
        strb    r0, [v3], #1            @ セパレータ(0)を書く
    5:
        ldmfd   sp!, {r0-r3, v1, pc}    @ return

@--------------------------------------------------------------
@ ファイル名バッファの内容表示
@--------------------------------------------------------------
ListFile:
        stmfd   sp!, {r0-r3, lr}
        bl      NewLine
        mov     r3, #0                  @ 個数
    1:
        ldr     r2, [v7, r3,LSL #2]     @ FNArray + FNCount * 4
        mov     r0, r3
        mov     r1, #4                  @ 4桁
        bl      PrintRight              @ 番号表示
        mov     r0, #0x20
        bl      OutChar
        mov     r0, r2
        bl      OutAsciiZ               @ ファイル名表示
        bl      NewLine
        add     r3, r3, #1
        cmp     r3, v4
        blt     1b
    2:
        ldmfd   sp!, {r0-r3, pc}        @ return

@--------------------------------------------------------------
@ 現在の termios を保存
@--------------------------------------------------------------
GET_TERMIOS:
        stmfd   sp!, {r0-r3, lr}
        ldr     r1, old_termios
        mov     r3, r1                  @ old_termios
        bl      tcgetattr
        ldr     r2, new_termios
        mov     r1, r3                  @ old_termios
        sub     r3, r2, r1
        mov     r3, r3, LSR #2
    1:
        ldr     r0, [r1], #4
        str     r0, [r2], #4
        subs    r3, r3, #1
        bne     1b
        ldmfd   sp!, {r0-r3, pc}        @ return

@--------------------------------------------------------------
@ 新しい termios を設定
@ Rawモード, ECHO 無し, ECHONL 無し
@ VTIME=0, VMIN=1 : 1バイト読み取られるまで待機
@--------------------------------------------------------------
SET_TERMIOS:
        stmfd   sp!, {r0-r2, lr}
        ldr     r2, new_termios
        ldr     r0, [r2, #+12]          @ c_lflag
        ldr     r1, termios_mode
        and     r0, r0, r1
        orr     r0, r0, #ISIG
        str     r0, [r2, #+12]
        mov     r0, #0
        ldr     r1, new_term_c_cc
        mov     r0, #1
        strb    r0, [r1, #VMIN]
        mov     r0, #0
        strb    r0, [r1, #VTIME]
        ldr     r1, new_termios
        bl      tcsetattr
        ldmfd   sp!, {r0-r2, pc}        @ return

@--------------------------------------------------------------
@ 現在の termios を Cooked モードに設定
@ Cookedモード, ECHO あり, ECHONL あり
@ VTIME=1, VMIN=0
@--------------------------------------------------------------
SET_TERMIOS2:
        stmfd   sp!, {r0-r2, lr}
        ldr     r2, new_termios
        ldr     r0, [r2, #+12]          @ c_lflag
        ldr     r1, termios_mode2
        and     r0, r0, r1
        orr     r0, r0, #ISIG
        str     r0, [r2, #+12]
        mov     r0, #0
        ldr     r1, new_term_c_cc
        mov     r0, #0
        strb    r0, [r1, #VMIN]
        mov     r0, #1
        strb    r0, [r1, #VTIME]
        ldr     r1, new_termios
        bl      tcsetattr
        ldmfd   sp!, {r0-r2, pc}        @ return

new_termios:    .long   new_termios0
old_termios:    .long   old_termios0
termios_mode:   .long   ~ICANON & ~ECHO & ~ECHONL
termios_mode2:  .long   ICANON | ECHO | ECHONL
new_term_c_cc:  .long   nt_c_cc

@--------------------------------------------------------------
@ 保存されていた termios を復帰
@--------------------------------------------------------------
RESTORE_TERMIOS:
        stmfd   sp!, {r0-r2, lr}
        ldr     r1, old_termios
        bl      tcsetattr
        ldmfd   sp!, {r0-r2, pc}        @ return

@--------------------------------------------------------------
@ 標準入力の termios の取得と設定
@ tcgetattr(&termios)
@ tcsetattr(&termios)
@ r0 : destroyed
@ r1 : termios buffer adress
@--------------------------------------------------------------
tcgetattr:
        ldr     r0, TC_GETS
        b       IOCTL

tcsetattr:
        ldr     r0, TC_SETS

@--------------------------------------------------------------
@ 標準入力の ioctl の実行
@ sys_ioctl(unsigned int fd, unsigned int cmd,
@           unsigned long arg)
@ r0 : cmd
@ r1 : buffer adress
@--------------------------------------------------------------
IOCTL:
        stmfd   sp!, {r1, r2, r7, lr}
        mov     r2, r1                  @ set arg
        mov     r1, r0                  @ set cmd
        mov     r0, #0                  @ 0 : to stdin
        mov     r7, #sys_ioctl
        swi     0
        ldmfd   sp!, {r1, r2, r7, pc}   @ return

TC_GETS:    .long   TCGETS
TC_SETS:    .long   TCSETS

@--------------------------------------------------------------
@ input 1 character from stdin
@ eax : get char (0:not pressed)
@--------------------------------------------------------------
RealKey:
        stmfd   sp!, {r1-r4, r7, lr}
        ldr     r3, new_term_c_cc
        mov     r0, #0
        strb    r0, [r3, #VMIN]
        ldr     r1, new_termios
        bl      tcsetattr
        mov     r0, #0                  @ r0  stdin
        stmfd   sp!, {r0}
        mov     r1, sp                  @ r1  address
        mov     r2, #1                  @ r2  length
        mov     r7, #sys_read
        swi     0
        ldmfd   sp!, {r1}               @ pop char
        tst     r0, r0                  @ if 0 then empty
        moveq   r4, r0
        movne   r4, r1                  @ char code
        mov     r1, #1
        strb    r1, [r3, #VMIN]
        ldr     r1, new_termios
        bl      tcsetattr
        mov     r0, r4
        ldmfd   sp!, {r1-r4, r7, pc}    @ return

@-------------------------------------------------------------------------
@ get window size
@ r0 : column(upper 16bit), raw(lower 16bit)
@-------------------------------------------------------------------------
WinSize:
        stmfd   sp!, {r1-r2, r7, lr}
        mov     r0, #0                  @ to stdout
        ldr     r1, TIOCG_WINSZ         @ get wondow size
        ldr     r2, wsize
        mov     r7, #sys_ioctl
        swi     0
        ldr     r0, [r2]                @ winsize.ws_row
        ldmfd   sp!, {r1-r2, r7, pc}    @ return

wsize:          .long   winsize
TIOCG_WINSZ:    .long   TIOCGWINSZ

@-------------------------------------------------------------------------
@ ファイルをオープン
@ enter   r0: 第１引数 filename
@ return  r0: fd, if error then r0 will be negative.
@ destroyed r1
@-------------------------------------------------------------------------
fropen:
        stmfd   sp!, {r1, r2, r7, lr}
        mov     r1, #O_RDONLY           @ 第２引数 flag
        b       1f
fwopen:
        stmfd   sp!, {r1, r2, r7, lr}
        ldr     r1, fo_mode
    1:
        mov     r2, #0644               @ 第３引数 mode
        mov     r7, #sys_open           @ システムコール番号
        swi     0
        tst     r0, r0                  @ r0 <- fd
        ldmfd   sp!, {r1, r2, r7, pc}

fo_mode:    .long   O_CREAT | O_WRONLY | O_TRUNC

@-------------------------------------------------------------------------
@ ファイルをクローズ
@ enter   r0 : 第１引数 ファイルディスクリプタ
@-------------------------------------------------------------------------
fclose:
        stmfd   sp!, {r7, lr}
        mov     r7, #sys_close
        swi     0
        ldmfd   sp!, {r7, pc}

@==============================================================
.bss
                    .align  2
HistLine0:          .long   0
HistUpdate0:        .long   0
input0:             .skip   MAXLINE

                    .align 2
history0:           .skip   MAXLINE * MAXHISTORY

                    .align  2
DirName0:           .skip   MAXLINE
PathName0:          .skip   MAXLINE

                    .align  2
PartialName0:       .long   1           @ 部分ファイル名先頭アドレス格納
FileNameBuffer0:    .skip   2048, 0     @ 2kbyte for filename completion
FNArray0:           .skip   MAX_FILE*4  @ long* Filename[0..255]
FNBPointer0:        .long   1           @ FileNameBufferの格納済みアドレス+1
FNCount0:           .long   1           @ No. of Filenames

                    .align 2
old_termios0:
ot_c_iflag:         .long   1           @ input mode flags
ot_c_oflag:         .long   1           @ output mode flags
ot_c_cflag:         .long   1           @ control mode flags
ot_c_lflag:         .long   1           @ local mode flags
ot_c_line:          .byte   1           @ line discipline
ot_c_cc:            .skip   NCCS        @ control characters

                    .align 2
new_termios0:
nt_c_iflag:         .long   1           @ input mode flags
nt_c_oflag:         .long   1           @ output mode flags
nt_c_cflag:         .long   1           @ control mode flags
nt_c_lflag:         .long   1           @ local mode flags
nt_c_line:          .byte   1           @ line discipline
nt_c_cc:            .skip   NCCS        @ control characters

                    .align 2
new_sig:
nsa_sighandler:     .long   0           @  0
nsa_mask:           .long   0           @  4
nsa_flags:          .long   0           @  8
nsa_restorer:       .long   0           @ 12
old_sig:
osa_sighandler:     .long   0           @ 16
osa_mask:           .long   0           @ 20
osa_flags:          .long   0           @ 24
osa_restorer:       .long   0           @ 28

TV:
tv_sec:             .long   1
tv_usec:            .long   1
TZ:
tz_minuteswest:     .long   1
tz_dsttime:         .long   1

winsize:
ws_row:             .hword  1
ws_col:             .hword  1
ws_xpixel:          .hword  1
ws_ypixel:          .hword  1

ru0:                                @ 18 words
ru_utime_tv_sec:    .long   1       @ user time used
ru_utime_tv_usec:   .long   1       @
ru_stime_tv_sec:    .long   1       @ system time used
ru_stime_tv_usec:   .long   1       @
ru_maxrss:          .long   1       @ maximum resident set size
ru_ixrss:           .long   1       @ integral shared memory size
ru_idrss:           .long   1       @ integral unshared data size
ru_isrss:           .long   1       @ integral unshared stack size
ru_minflt:          .long   1       @ page reclaims
ru_majflt:          .long   1       @ page faults
ru_nswap:           .long   1       @ swaps
ru_inblock:         .long   1       @ block input operations
ru_oublock:         .long   1       @ block output operations
ru_msgsnd:          .long   1       @ messages sent
ru_msgrcv:          .long   1       @ messages received
ru_nsignals:        .long   1       @ signals received
ru_nvcsw:           .long   1       @ voluntary context switches
ru_nivcsw:          .long   1       @ involuntary

                    .align 2
dir_ent0:                           @ 256 bytesのdir_ent格納領域
@ de_d_ino:         .long   1       @ 0
@ de_d_off:         .long   1       @ 4
@ de_d_reclen:      .hword  1       @ 8
@ de_d_name:                        @ 10    ディレクトリエントリの名前
                    .skip   256

                    .align  2
size_dir_ent0 = . - dir_ent0

                    .align 2
file_stat0:                         @ 64 bytes
fs_st_dev:          .hword  1       @ 0  ファイルのデバイス番号
fs___pad1:          .hword  1       @ 2
fs_st_ino:          .long   1       @ 4  ファイルのinode番号
fs_st_mode:         .hword  1       @ 8  ファイルのアクセス権とタイプ
fs_st_nlink:        .hword  1       @ 10
fs_st_uid:          .hword  1       @ 12
fs_st_gid:          .hword  1       @ 14
fs_st_rdev:         .hword  1       @ 16
fs___pad2:          .hword  1       @ 18
fs_st_size:         .long   1       @ 20 ファイルサイズ(byte)
fs_st_blksize:      .long   1       @ 24 ブロックサイズ
fs_st_blocks:       .long   1
fs_st_atime:        .long   1       @ 32 ファイルの最終アクセス日時
fs___unused1:       .long   1
fs_st_mtime:        .long   1       @ 40 ファイルの最終更新日時
fs___unused2:       .long   1
fs_st_ctime:        .long   1       @ 48 ファイルのまたはinodeの最終更新日時
fs___unused3:       .long   1
fs___unused4:       .long   1
fs___unused5:       .long   1       @ 60

.endif
