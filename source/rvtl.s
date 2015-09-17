@-------------------------------------------------------------------------
@ Return of the Very Tiny Language for ARM
@ file : rvtl.s ver. 3.05 arm eabi
@ 2005/06/26
@ 2009/03/15 arm eabi
@ 2012/10/25 fix |fbo, UTF-8, ASLR
@ 2013/04/25 fix |fbo for linux 3.6
@ 2015/09/16 fix Environment variables (\\e), added |rt, |vc
@ Copyright (C) 2003-2015 Jun Mizutani <mizutani.jun@nifty.ne.jp>
@ rvtl.s may be copied under the terms of the GNU General Public License.
@-------------------------------------------------------------------------


ARGMAX      =   15
VSTACKMAX   =   1024
MEMINIT     =   256*1024
LSTACKMAX   =   127
FNAMEMAX    =   256
LABELMAX    =   1024
VERSION     =   30500
CPU         =   2

.ifndef SMALL_VTL
  VTL_LABEL    = 1
  DETAILED_MSG = 1
  FRAME_BUFFER = 1
.endif

.ifdef  DETAILED_MSG
  .include      "syserror.s"
.endif

.ifdef  FRAME_BUFFER
  .include      "fblib.s"
.endif

.ifdef  DEBUG
  .include      "debug.s"
.endif

.include "vtllib.s"
.include "vtlsys.s"
.include "mt19937.s"

@==============================================================
        .text
        .global _start

_start:
                .align   2
@-------------------------------------------------------------------------
@ システムの初期化
@-------------------------------------------------------------------------
        @ コマンドラインの引数の数をスタックから取得して [argc] に保存する
        ldr     r2, argc
        ldmfd   sp!, {r0}           @ r0 = argc
        str     r0, [r2]            @ argc 引数の数を保存
        str     sp, [r2, #+4]       @ argvp 引数配列先頭を保存

        @ 環境変数格納アドレスをスタックから取得し、[envp] に保存する
        add     r0, sp, r0,LSL #2
        add     r0, r0, #8          @ 環境変数アドレス取得
        str     r0, [r2, #+8]       @ envp 環境変数領域の保存

        @ コマンドラインの引数を走査 2003/10/13
        ldr     r0, [r2]            @ argc
        ldr     r1, [r2, #+4]       @ argvp
        mov     r3, #1
        cmp     r0, r3
        beq     4f                  @ 引数なしならスキップ
    1:  ldr     ip, [r1, r3,LSL #2] @ ip = argvp[r3]
        ldrb    ip, [ip]
        add     r3, r3, #1
        cmp     ip, #'-             @ 「-」か？
        beq     2f                  @ 「-」発見
        cmp     r3, r0
        bne     1b
        b       3f                  @ 「-」なし
    2:
        sub     ip, r3, #1          @ ver. 3.05
        str     r3, [r2]            @ argc 引数の数を更新
    3:  add     ip, r1, r3,LSL #2
        str     ip, [r2, #+16]      @ vtl用の引数文字列数への配列先頭
        sub     r3, r0, r3
        str     r3, [r2, #+12]      @ vtl用の引数の個数 (argc_vtl0)

    4:  @ argv[0]="xxx/rvtlw" ならば cgiモード
        mov     v1, #0
        adr     r3, cginame         @ 文字列 'wltvr',0
        ldr     r0, [r1]            @ argv[0]
    5:  ldrb    ip, [r0], #1
        cmp     ip, #0
        bne     5b
        sub     r0, r0, #2          @ 文字列の最終文字位置(w)
    6:  ldrb    r1, [r0], #-1
        ldrb    ip, [r3], #+1
        cmp     ip, #0
        beq     7f                  @ found
        cmp     r1, ip
        bne     8f                  @ no
        b       6b
    7:  mov     v1, #1
    8:  ldr     r3, cgiflag
        str     v1, [r3]

        @ 現在の端末設定(termios) を保存し、端末をローカルエコーOFFに再設定

        bl      GET_TERMIOS         @ termios の保存
        bl      SET_TERMIOS         @ 端末のローカルエコーOFF

        @ fpに変数領域の先頭アドレスを設定、変数のアクセスはfpを使って行う

        ldr     fp, VarArea         @ サイズ縮小のための準備

        @ システム変数の初期値を設定

        mov     r0, #0              @ 0 を渡して現在値を得る
        mov     r7, #sys_brk        @ brk取得
        swi     0
        mov     r2, r0
        mov     r1, #',             @ プログラム先頭 (,)
        str     r0, [fp, r1,LSL #2]
        mov     r1, #'=             @ プログラム先頭 (=)
        str     r0, [fp, r1,LSL #2]
        add     r3, r0, #4          @ ヒープ先頭 (&)
        mov     r1, #'&
        str     r3, [fp, r1,LSL #2]
        ldr     r1, mem_init        @ MEMINIT=256*1024
        add     r0, r0, r1          @ 初期ヒープ最終
        mov     r1, #'*             @ RAM末設定 (*)
        str     r0, [fp, r1,LSL #2]
        swi     0                   @ brk設定
        mvn     r3, #0              @ -1
        str     r3, [r2]            @ コード末マーク

        ldr     r0, n672274774      @ 初期シード値
        mov     r3, #'`             @ 乱数シード設定
        str     r0, [fp, r3,LSL #2]
        bl      sgenrand

        @ ctrl-C, ctrl-Z用のシグナルハンドラを登録する
        mov     r1, #0              @ シグナルハンドラ設定
        ldr     r3, sig_action      @ r3=new_sig
        adr     r0, SigIntHandler
        str     r0, [r3]            @ nsa_sighandler
        str     r1, [r3, #+4]       @ nsa_mask
        mov     r0, #SA_NOCLDSTOP   @ 子プロセス停止を無視
        str     r0, [r3, #+8]       @ nsa_flags
        str     r1, [r3, #+12]      @ nsa_restorer

        mov     r0, #SIGINT         @ ^C
        mov     r1, r3              @ new_sig
        add     r2, r1, #16         @ old_sig
        mov     r7, #sys_sigaction
        swi     0

        mov     r0, #SIG_IGN        @ シグナルの無視
        str     r0, [r3]            @ nsa_sighandler
        mov     r0, #SIGTSTP        @ ^Z
        mov     r7, #sys_sigaction
        swi     0

        @ PIDを取得して保存(initの識別)、pid=1 なら環境変数設定
        mov     r7, #sys_getpid
        swi     0
        str     r0, [fp, #-24]      @ pid の保存
        cmp     r0, #1
        bne     go

        ldr     r1, envp            @ pid=1 なら環境変数設定
        ldr     r0, env             @ envp 環境変数
        str     r0, [r1]

        @ /etc/init.vtlが存在すれば読み込む
        adr     r0, initvtl         @ /etc/init.vtl
        bl      fropen              @ open
        ble     go                  @ 無ければ継続
        str     r0, [fp, #-8]       @ FileDesc
        bl      WarmInit2
        mov     r0, #1
        strb    r0, [fp, #-4]       @ Read from file
        strb    r0, [fp, #-2]       @ EOL=yes [fp, #-2]は未使用
        mov     v5, r0              @ EOLフラグ
        b       Launch
    go:
        bl      WarmInit2
        mov     r0, #0
        ldr     r1, counter
        str     r0, [r1]            @ コマンド実行カウント初期化
        add     r1, r1, #8          @ current_arg
        str     r0, [r1]            @ 処理済引数カウント初期化
        bl      LoadCode            @ あればプログラムロード
        bgt     Launch

.ifndef SMALL_VTL
        adr     r0, start_msg       @ 起動メッセージ
        bl      OutAsciiZ
.endif

Launch:         @ 初期化終了
        ldr     r1, save_stack
        str     sp, [r1]            @ スタックを保存

@-------------------------------------------------------------------------
@ メインループ
@-------------------------------------------------------------------------
MainLoop:

        @ SIGINTを受信(ctrl-Cの押下)を検出したら初期状態に戻す
        ldrb    ip, [fp, #-17]
        cmp     ip, #1              @ SIGINT 受信?
        bne     1f
        bl      WarmInit            @ 実行停止
        b       3f

        @ 0除算エラーが発生したらメッセージを表示して停止
    1:  ldrb    ip, [fp, #-18]      @ エラー
        cmp     ip, #1
        bne     2f
        adr     r0, err_div0        @ 0除算メッセージ
        bl      OutAsciiZ
        bl      WarmInit            @ 実行停止

        @ 式中でエラーを検出したらメッセージを表示して停止
    2:  ldrb    ip, [fp, #-19]      @ 式中にエラー?
        cmp     ip, #0
        beq     3f
        b       Exp_Error           @ 式中でエラー発生

        @ 行末をチェック (初期化直後は EOL=1)
    3:
        cmp     v5, #0              @ EOL
        beq     4f

        @ 次行取得 (コンソール入力またはメモリ上のプログラム)
        ldrb    ip, [fp, #-3]
        cmp     ip, #1              @ ExecMode=Memory ?
        bne     ReadLine            @ 行取得
        b       ReadMem             @ メモリから行取得

        @ 空白なら読み飛ばし
    4:  bl      GetChar
    5:  cmp     v1, #' '            @ 空白読み飛ばし
        bne     6f
        bl      GetChar
        b       5b

        @ 行番号付なら編集モード
    6:
        bl      IsNum               @ 行番号付なら編集モード
        bcs     7f
        bl      EditMode            @ 編集モード
        b       MainLoop

        @ 英文字なら変数代入、異なればコマンド
    7:  ldr     ip, counter
        ldr     r0, [ip]            @ counter0
                                add     r0, r0, #1
        str     r0, [ip]            @ inc [counter0]
                                bl      IsAlpha
        bcs     Command             @ コマンド実行
    8:  bl      SetVar              @ 変数代入
        b       MainLoop

LongJump:
        ldr     ip, save_stack
        ldr     sp, [ip]            @ スタックを復帰
        adr     r0, err_exp         @ 式中に空白
        b       Error
Exp_Error:
        cmp     ip, #2
        adreq   r0, err_vstack      @ 変数スタックアンダーフロー
        adrne   r0, err_label       @ ラベル未定義メッセージ
        b       Error

@-------------------------------------------------------------------------
@ シグナルハンドラ
@-------------------------------------------------------------------------
SigIntHandler:
        stmfd   sp!, {r0, lr}
        mov     r0, #1              @ SIGINT シグナル受信
        strb    r0, [fp, #-17]      @ fpは常に同じ値
        ldmfd   sp!, {r0, pc}

@-------------------------------------------------------------------------
@ コマンドラインで指定されたVTLコードファイルをロード
@ 実行後、bgt 真 ならロード
@-------------------------------------------------------------------------
LoadCode:
        stmfd   sp!, {r1, ip, lr}
        ldr     r3, current_arg     @ 処理済みの引数
        ldr     r2, [r3]
        add     r2, r2, #1          @ カウントアップ
        ldr     ip, [r3, #4]        @ argc0 引数の個数
        cmp     r2, ip
        beq     3f                  @ すべて処理済み
        str     r2, [r3]            @ 処理済みの引数更新
        ldr     ip, [r3, #+8]       @ argvp 引数配列先頭
        ldr     ip, [ip, r2,LSL #2] @ 引数取得
        ldr     r1, FileName
        mov     r2, #FNAMEMAX

    1:  ldrb    r0, [ip], #1
        strb    r0, [r1], #1
        tst     r0, r0
        beq     2f                  @ file open
        subs    r2, r2, #1
        bne     1b

    2:  ldr     r0, FileName        @ ファイルオープン
        bl      fropen              @ open
        ble     3f
        str     r0, [fp, #-8]       @ FileDesc
        mov     r0, #1
        strb    r0, [fp, #-4]       @ Read from file(0)
        mov     v5, #1              @ EOL=yes
    3:
        ldmfd   sp!, {r1, ip, pc}

@-------------------------------------------------------------------------
@ 文字列取得 " または EOL まで
@-------------------------------------------------------------------------
GetString:
        stmfd   sp!, {lr}
        mov     r2, #0
        ldr     r3, FileName
    1: @ next:
        bl      GetChar
        cmp     v1, #'"'
        beq     2f
        tst     v1, v1
        beq     2f
        strb    v1, [r3, r2]
        add     r2, r2, #1
        cmp     r2, #FNAMEMAX
        blo     1b
    2: @ exit:
        mov     v1, #0
        strb    v1, [r3, r2]
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------

n672274774:     .long   672274774
save_stack:     .long   save_stack0
mem_init:       .long   MEMINIT

current_arg:    .long   current_arg0
counter:        .long   counter0
argc:           .long   argc0       @ [ 0]
argvp:          .long   argvp0      @ [ 4]
envp:           .long   envp0       @ [ 8]
argc_vtl:       .long   argc_vtl0   @ [12]
argp_vtl:       .long   argp_vtl0   @ [16]
exarg:          .long   exarg0
VarArea:        .long   VarArea0
sig_action:     .long   new_sig
cgiflag:        .long   cgiflag0

.ifndef SMALL_VTL
                .align   2
start_msg:      .ascii   "RVTL v.3.05arm 2015/09/16, (C)2003-2015 Jun Mizutani\n"
                .ascii   "RVTL may be copied under the terms of the GNU "
                .asciz   "General Public License.\n"
                .align   2
.endif

initvtl:        .asciz   "/etc/init.vtl"
                .align   2
cginame:        .asciz   "wltvr"
                .align   2
err_div0:       .asciz   "\nDivided by 0!\n"
                .align   2
err_label:      .asciz   "\nLabel not found!\n"
                .align   2
err_vstack:     .asciz   "\nEmpty stack!\n"
                .align   2
err_exp:        .asciz   "\nError in Expression at line "
                .align   2

@-------------------------------------------------------------------------
@ r0 のアドレスからFileNameにコピー
@-------------------------------------------------------------------------
  GetString2:
        stmfd   sp!, {lr}
        mov     r2, #0
        ldr     r3, FileName
    1:  ldrb    r1, [r0, r2]
        strb    r1, [r3, r2]
        tst     r1, r1
        beq     2f
        add     r2, r2, #1
        cmp     r2, #FNAMEMAX
        blo     1b
    2:  ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ ファイル名をバッファに取得
@ バッファ先頭アドレスを r0 に返す
@-------------------------------------------------------------------------
GetFileName:
        stmfd   sp!, {lr}
        bl      GetChar             @ skip =
        cmp     v1, #'='
        bne     2f                  @ エラー
        bl      GetChar             @ skip "
        cmp     v1, #'"'
        beq     1f
        b       2f                  @ エラー
    1: @ file
        bl      GetString
        ldr     r0, FileName        @ ファイル名表示
        ldmfd   sp!, {pc}
    2: @ error
        add     sp, sp, #4          @ スタック修正
        b       pop_and_Error

FileName:       .long   FileName0

@-------------------------------------------------------------------------
@ キー入力またはファイル入力されたコードを実行
@-------------------------------------------------------------------------
ReadLine:
        @ 1行入力 : キー入力とファイル入力に対応
        ldrb    r0, [fp, #-4]       @ Read from console
        cmp     r0, #0
        beq     1f                  @ コンソールから入力
        bl      READ_FILE           @ ファイルから入力
        b       MainLoop

    1:  @ プロンプトを表示してコンソールからキー入力
        bl      DispPrompt
        ldr     r1, input
        mov     r0, #MAXLINE        @ 1 行入力
        bl      READ_LINE           @ 編集機能付キー入力
        mov     v3, r1              @ 入力バッファ先頭
        mov     v2, v3
        mov     v5, #0              @ not EOL
        b       MainLoop

input:  .long   input0              @ vtllib.sのbss上のバッファ

@-------------------------------------------------------------------------
@ メモリに格納されたコードの次行をv3に設定
@ v2 : 行先頭アドレス
@-------------------------------------------------------------------------
ReadMem:
        ldr     r0, [v2]            @ JUMP先かもしれない
        adds    r0, r0, #1          @ 次行オフセットが -1 か?
        beq     1f                  @ コード末なら実行終了
        ldr     r0, [v2]
        add     v2, v2, r0          @ Next Line

        @次行へのオフセットが0ならばコード末
        ldr     r0, [v2]            @ 次行オフセット
        tst     r0, r0              @ コード末？
        bpl     2f

        @コード末ならばコンソール入力(ダイレクトモード)に設定し、
        @EOLを1とすることで、次行取得を促す
    1:
        bl      CheckCGI            @ CGIモードなら終了
        mov     r0, #0
        mov     v5, #1              @ EOL=yes
        strb    r0, [fp, #-3]       @ ExecMode=Direct
        b       MainLoop

        @現在の行番号を # に設定して、行のコード部分先頭アドレスを v3 に設定
    2:
        bl      SetLineNo           @ 行番号を # に設定
        add     v3, v2, #+8         @ 行のコード先頭
        mov     v5, #0              @ EOL=no
        b       MainLoop

@-------------------------------------------------------------------------
@ 文の実行
@   文を実行するサブルーチンをコール
@-------------------------------------------------------------------------
Command:
        @v1レジスタの値によって各処理ルーチンを呼び出す
        subs    r1, v1, #'!
        blo     1f
        cmp     r1, #('/- '!)
        bhi     1f
        adr     r2, TblComm1            @ ジャンプテーブル1 !-/
        ldr     r1, [r2, r1,LSL #2]     @ ジャンプ先アドレス設定
        blx     r1                      @ 対応ルーチンをコール
        b       MainLoop
    1:  subs    r1, v1, #':'
        blo     2f
        cmp     r1, #('@ - ':)
        bhi     2f
        adr     r2, TblComm2            @ ジャンプテーブル2 :-@
        ldr     r1, [r2, r1,LSL #2]     @ ジャンプ先アドレス設定
        blx     r1                      @ 対応ルーチンをコール
        b       MainLoop
    2:  subs    r1, v1, #'['
        blo     3f
        cmp     r1, #('` - '[)
        bhi     3f
        adr     r2, TblComm3            @ ジャンプテーブル3 [-`
        ldr     r1, [r2, r1,LSL #2]     @ ジャンプ先アドレス設定
        blx     r1                      @ 対応ルーチンをコール
        b       MainLoop
    3:  subs    r1, v1, #'{'
        blo     4f
        cmp     r1, #('~ - '{)
        bhi     4f
        adr     r2, TblComm4            @ ジャンプテーブル4 {-~
        ldr     r1, [r2, r1,LSL #2]     @ ジャンプ先アドレス設定
        blx     r1                      @ 対応ルーチンをコール
        b       MainLoop
    4:  cmp     v1, #' '
        beq     MainLoop
        cmp     v1, #0
        beq     MainLoop
        cmp     v1, #8
        beq     MainLoop
        b       SyntaxError

@-------------------------------------------------------------------------
@ コマンド用ジャンプテーブル
@-------------------------------------------------------------------------
        .align   2
TblComm1:
        .long Com_GOSUB    @   21  !  GOSUB
        .long Com_String   @   22  "  文字列出力
        .long Com_GO       @   23  #  GOTO 実行中の行番号を保持
        .long Com_OutChar  @   24  $  文字コード出力
        .long Com_Error    @   25  %  直前の除算の剰余または usec を保持
        .long Com_NEW      @   26  &  NEW, VTLコードの最終使用アドレスを保持
        .long Com_Error    @   27  '  文字定数
        .long Com_FileWrite@   28  (  File 書き出し
        .long Com_FileRead @   29  )  File 読み込み, 読み込みサイズ保持
        .long Com_BRK      @   2A  *  メモリ最終(brk)を設定, 保持
        .long Com_VarPush  @   2B  +  ローカル変数PUSH, 加算演算子, 絶対値
        .long Com_Exec     @   2C  ,  fork & exec
        .long Com_VarPop   @   2D  -  ローカル変数POP, 減算演算子, 負の十進数
        .long Com_Space    @   2E  .  空白出力
        .long Com_NewLine  @   2F  /  改行出力, 除算演算子
TblComm2:
        .long Com_Comment  @   3A  :  行末まで注釈
        .long Com_IF       @   3B  @  IF
        .long Com_CdWrite  @   3C  <  rvtlコードのファイル出力
        .long Com_Top      @   3D  =  コード先頭アドレス
        .long Com_CdRead   @   3E  >  rvtlコードのファイル入力
        .long Com_OutNum   @   3F  ?  数値出力  数値入力
        .long Com_DO       @   40  @  DO UNTIL NEXT
TblComm3:
        .long Com_RCheck   @   5B  [  Array index 範囲チェック
        .long Com_Ext      @   5C  \  拡張用  除算演算子(unsigned)
        .long Com_Return   @   5D  ]  RETURN
        .long Com_Comment  @   5E  ^  ラベル宣言, 排他OR演算子, ラベル参照
        .long Com_USleep   @   5F  _  usleep, gettimeofday
        .long Com_RANDOM   @   60  `  擬似乱数を保持 (乱数シード設定)
TblComm4:
        .long Com_FileTop  @   7B  {  ファイル先頭(ヒープ領域)
        .long Com_Function @   7C  |  組み込みコマンド, エラーコード保持
        .long Com_FileEnd  @   7D  }  ファイル末(ヒープ領域)
        .long Com_Exit     @   7E  ~  VTL終了

@-------------------------------------------------------------------------
@ ソースコードを1文字読み込む
@ v3 の示す文字を v1 に読み込み, v3 を次の位置に更新
@ レジスタ保存
@-------------------------------------------------------------------------
GetChar:
        cmp     v5, #1              @ EOL=yes
        beq     2f
        ldrb    v1, [v3]
        tst     v1, v1
        moveq   v5, #1              @ EOL=yes
        add     v3, v3, #1
    2:
        mov     pc, lr              @ return

@-------------------------------------------------------------------------
@ 行番号をシステム変数 # に設定
@-------------------------------------------------------------------------
SetLineNo:
        stmfd   sp!, {lr}
        ldr     r0, [v2, #+4]       @ Line No.
        mov     r3, #'#
        str     r0, [fp, r3,LSL #2] @ 行番号を # に設定
        ldmfd   sp!, {pc}

SetLineNo2:
        stmfd   sp!, {lr}
        mov     r3, #'#
        ldr     r0, [fp, r3,LSL #2] @ 行番号を取得
        sub     r3, r3, #2
        str     r0, [fp, r3,LSL #2] @ 行番号を ! に設定
        ldr     r0, [v2, #+4]       @ Line No.
        add     r3, r3, #2
        str     r0, [fp, r3,LSL #2] @ 行番号を # に設定
        ldmfd   sp!, {pc}


@-------------------------------------------------------------------------
@ CGI モードなら rvtl 終了
@-------------------------------------------------------------------------
CheckCGI:
        ldr     r3, cgiflag
        ldr     r3, [r3]
        cmp     r3, #1              @ CGI mode ?
        beq     Com_Exit
        mov     pc, lr              @ return

@-------------------------------------------------------------------------
@ 文法エラー
@-------------------------------------------------------------------------
SyntaxError:
        adr     r0, syntaxerr
Error:  bl      OutAsciiZ
        ldrb    r0, [fp, #-3]
        tst     r0, r0              @ ExecMode=Direct ?
        beq     3f
        ldr     r0, [v2, #+4]       @ エラー行行番号
        bl      PrintLeft
        bl      NewLine
        add     r0, v2, #8          @ 行先頭アドレス
    5:  bl      OutAsciiZ           @ エラー行表示
        bl      NewLine
        sub     r3, v3, v2
        subs    r3, r3, #9
        beq     2f
        cmp     r3, #MAXLINE
        bhs     3f
        mov     r0, #' '            @ エラー位置設定
    1:  bl      OutChar
        subs    r3, r3, #1
        bne     1b
    2:  adr     r0, err_str
        bl      OutAsciiZ
        mov     r0, v1
        bl      PrintHex2           @ エラー文字コード表示
        mov     r0, #']'
        bl      OutChar
        bl      NewLine

    3:  bl      WarmInit            @ システムを初期状態に
        b       MainLoop

err_str:
        .asciz  "^  ["
        .align  2

@==============================================================

envstr:         .asciz   "PATH=/bin:/usr/bin"
                .align   2
env:            .long    envstr, 0

                .align   2
prompt1:        .asciz   "\n<"
                .align   2
prompt2:        .asciz   "> "
                .align   2
syntaxerr:      .asciz   "\nSyntax error! at line "
                .align   2
stkunder:       .asciz   "\nStack Underflow!\n"
                .align   2
stkover:        .asciz   "\nStack Overflow!\n"
                .align   2
vstkunder:      .asciz   "\nVariable Stack Underflow!\n"
                .align   2
vstkover:       .asciz   "\nVariable Stack Overflow!\n"
                .align   2
Range_msg:      .asciz   "\nOut of range!\n"
                .align   2

@-------------------------------------------------------------------------
@ 変数スタック範囲エラー
@-------------------------------------------------------------------------
VarStackError_over:
        adr     r0, vstkover
        b       1f
VarStackError_under:
        adr     r0, vstkunder
    1:  bl      OutAsciiZ
        bl      WarmInit
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ スタックへアドレスをプッシュ (行と文末位置を退避)
@-------------------------------------------------------------------------
PushLine:
        stmfd   sp!, {r1-r2, lr}
        ldrb    r1, [fp, #-1]           @ LSTACK
        cmp     r1, #LSTACKMAX
        bge     StackError_over         @ overflow
        add     r2, fp, #512            @ (fp + 512) + LSTACK*4
        str     v2, [r2, r1,LSL #2]     @ push v2

        add     r1, r1, #1              @ LSTACK--
        ldrb    ip, [v3, #-1]
        cmp     ip, #0
        beq     1f                      @ 行末処理
        str     v3, [r2,r1,LSL #2]      @ push v3,(fp+512)+LSTACK*4
        b       2f
    1:
        sub     v3, v3, #1              @ 1文字戻す
        str     v3, [r2, r1,LSL #2]     @ push v3,(fp+512)+LSTACK*4
        add     v3, v3, #1              @ 1文字進める
    2:
        add     r1, r1, #1              @ LSTACK--
        strb    r1, [fp, #-1]           @ LSTACK
        ldmfd   sp!, {r1-r2, pc}

@-------------------------------------------------------------------------
@ スタックからアドレスをポップ (行と文末位置を復帰)
@ v2, v3 更新
@-------------------------------------------------------------------------
PopLine:
        stmfd   sp!, {r1-r2, lr}
        ldrb    r1, [fp, #-1]           @ LSTACK
        cmp     r1, #2
        blo     StackError_under        @ underflow
        sub     r1, r1, #1              @ LSTACK--
        add     r2, fp, #512            @ (fp + 512) + LSTACK*4
        add     r2, r2, r1,LSL #2
        ldr     v3, [r2]                @ pop v3
        ldr     v2, [r2, #-4]           @ pop v2
        sub     r1, r1, #1
        strb    r1, [fp, #-1]           @ LSTACK
        ldmfd   sp!, {r1-r2, pc}

@-------------------------------------------------------------------------
@ スタックエラー
@ r0 変更
@-------------------------------------------------------------------------
StackError_over:
        adr     r0, stkover
        b       1f
StackError_under:
        adr     r0, stkunder
        stmfd   sp!, {lr}
    1:  bl      OutAsciiZ
        bl      WarmInit
        ldmfd   sp!, {r1-r2, pc}

@-------------------------------------------------------------------------
@ スタックへ終了条件(r0)をプッシュ
@-------------------------------------------------------------------------
PushValue:
        stmfd   sp!, {r1-r2, lr}
        ldrb    r1, [fp, #-1]           @ LSTACK
        cmp     r1, #LSTACKMAX
        bge     StackError_over
        add     r2, fp, #512            @ (fp + 512) + LSTACK*4
        str     r0, [r2, r1,LSL #2]     @ push r0
        add     r1, r1, #1              @ LSTACK++
        strb    r1, [fp, #-1]           @ LSTACK
        ldmfd   sp!, {r1-r2, pc}

@-------------------------------------------------------------------------
@ スタック上の終了条件を r0 に設定
@-------------------------------------------------------------------------
PeekValue:
        stmfd   sp!, {r1-r2, lr}
        ldrb    r1, [fp, #-1]           @ LSTACK
        sub     r1, r1, #3              @ 行,文末位置の前
        add     r2, fp, #512            @ (fp + 512) + LSTACK*4
        ldr     r0, [r2, r1,LSL #2]     @ read Value
        ldmfd   sp!, {r1-r2, pc}

@-------------------------------------------------------------------------
@ スタックから終了条件(r0)をポップ
@-------------------------------------------------------------------------
PopValue:
        stmfd   sp!, {r1-r2, lr}
        ldrb    r1, [fp, #-1]           @ LSTACK
        cmp     r1, #1
        blo     StackError_under
        sub     r1, r1, #1              @ LSTACK--
        add     r2, fp, #512            @ (fp + 512) + LSTACK*4
        ldr     r0, [r2, r1,LSL #2]     @ pop r0
        strb    r1, [fp, #-1]           @ LSTACK
        ldmfd   sp!, {r1-r2, pc}

@-------------------------------------------------------------------------
@ プロンプト表示
@-------------------------------------------------------------------------
DispPrompt:
        stmfd   sp!, {lr}
        bl      WinSize
        mov     r0, r0, LSR #16     @ 桁数
        cmp     r0, #48
        blo     1f
        mov     r0, #7              @ long prompt
        bl      set_linetop         @ 行頭マージン設定
        adr     r0, prompt1         @ プロンプト表示
        bl      OutAsciiZ
        ldr     r0, [fp, #-24]      @ pid の取得
.ifdef DEBUG
        mov     r0, sp              @ sp の下位4桁
.endif
        bl      PrintHex4
        adr     r0, prompt2         @ プロンプト表示
        bl      OutAsciiZ
        ldmfd   sp!, {pc}

    1:  mov     r0, #4              @ short prompt
        bl      set_linetop         @ 行頭マージン設定
        bl      NewLine
        ldr     r0, [fp, #-24]      @ pid の取得
        bl      PrintHex2           @ pidの下1桁表示
        adr     r0, prompt2         @ プロンプト表示
        bl      OutAsciiZ
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ アクセス範囲エラー
@-------------------------------------------------------------------------
RangeError:
        stmfd   sp!, {lr}
        adr     r0, Range_msg       @ 範囲エラーメッセージ
        bl      OutAsciiZ
        mov     r1, #'#             @ 行番号
        ldr     r0, [fp, r1,LSL #2]
        bl      PrintLeft
        mov     r0, #',
        bl      OutChar
        mov     r1, #'!             // 呼び出し元の行番号
        ldr     r0, [fp, r1,LSL #2]
        bl      PrintLeft
        bl      NewLine
        bl      WarmInit
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ システム初期化２
@-------------------------------------------------------------------------
    @コマンド入力元をコンソールに設定

WarmInit:
        stmfd   sp!, {lr}
        bl      CheckCGI
        ldmfd   sp!, {lr}
WarmInit2:
        mov     r0, #0              @ 0
        strb    r0, [fp, #-4]       @ Read from console

    @システム変数及び作業用フラグの初期化
WarmInit1:
        mov     r0, #1              @ 1
        mov     r3, #'[             @ 範囲チェックON
        str     r0, [fp, r3,LSL #2]
        mov     v5, #1              @ EOL=yes
        mov     r0, #0              @ 0
        ldr     r1, exarg           @ execve 引数配列初期化
        str     r0, [r1]
        strb    r0, [fp, #-19]      @ 式のエラー無し
        strb    r0, [fp, #-18]      @ ０除算無し
        strb    r0, [fp, #-17]      @ SIGINTシグナル無し
        strb    r0, [fp, #-3]       @ ExecMode=Direct
        strb    r0, [fp, #-1]       @ LSTACK
        str     r0, [fp, #-16]      @ VSTACK

        mov     pc, lr              @ return
@        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ GOSUB !
@-------------------------------------------------------------------------
Com_GOSUB:
        stmfd   sp!, {lr}
        ldrb    r0, [fp, #-3]
        tst     r0, r0              @ ExecMode=Direct ?
        bne     1f
        adr     r0, no_direct_mode
        bl      OutAsciiZ
        add     sp, sp, #4          @ スタック修正
        bl      WarmInit
        b       MainLoop
    1:
.ifdef VTL_LABEL
        bl      ClearLabel
.endif
        bl      SkipEqualExp        @ = を読み飛ばした後 式の評価
        bl      PushLine
        bl      Com_GO_go
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ Return ]
@-------------------------------------------------------------------------
Com_Return:
        stmfd   sp!, {lr}
        bl      PopLine             @ 現在行の後ろは無視
        mov     v5, #0              @ not EOL
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ IF @ コメント :
@-------------------------------------------------------------------------
Com_IF:
        stmfd   sp!, {lr}           @ lr 保存
        bl      SkipEqualExp        @ = を読み飛ばした後 式の評価
        ldmfd   sp!, {lr}           @ lr 復帰
        tst     r0, r0
        movne   pc, lr              @ 真なら戻る、偽なら次行
Com_Comment:
        mov     v5, #1              @ EOL=yes 次の行へ
        mov     pc, lr

@-------------------------------------------------------------------------
@ 未定義コマンド処理(エラーストップ)
@-------------------------------------------------------------------------
pop2_and_Error:
        add     sp, sp, #4
pop_and_Error:
        add     sp, sp, #4
Com_Error:
        b       SyntaxError

@-------------------------------------------------------------------------
@ DO UNTIL NEXT @
@-------------------------------------------------------------------------
Com_DO:
        stmfd   sp!, {lr}
        ldr     r0, [fp, #-3]
        cmp     r0, #0              @ ExecMode=Direct ?
        bne     1f
        adr     r0, no_direct_mode
        bl      OutAsciiZ
        add     sp, sp, #4          @ スタック修正
        bl      WarmInit
        b       MainLoop
    1:
        bl      GetChar
        cmp     v1, #'='
        bne     7f                  @ DO コマンド
        ldrb    v1, [v3]            @ PeekChar
        cmp     v1, #'('            @ UNTIL?
        bne     2f                  @ ( でなければ NEXT
        bl      SkipCharExp         @ (を読み飛ばして式の評価
        mov     r2, r0              @ 式の値
        bl      GetChar             @ ) を読む(使わない)
        bl      PeekValue           @ 終了条件
        cmp     r2, r0              @ r0:終了条件
        bne     6f                  @ 等しくcontinue
        b       5f                  @ ループ終了

    2: @ next (FOR)
        bl      IsAlpha             @ al=[A-Za-z] ?
        bcs     pop_and_Error       @ スタック補正後 SyntaxError
        add     r2, fp, v1,LSL #2   @ 制御変数のアドレス
        bl      Exp                 @ 任意の式
        ldr     r3, [r2]            @ 更新前の値を r3 に
        str     r0, [r2]            @ 制御変数の更新
        mov     r2, r0              @ 更新後の式の値をr2
        bl      PeekValue           @ 終了条件を r0 に
        ldrb    r1, [fp, #-20]
        cmp     r1, #1              @ 降順 (開始値 > 終了値)
        bne     4f                  @ 昇順

    3: @ 降順
        cmp     r3, r2              @ 更新前 - 更新後
        ble     pop_and_Error       @ 更新前が小さければエラー
        cmp     r3, r0              @ r0:終了条件
        bgt     6f                  @ continue
        b       5f                  @ 終了

    4: @ 昇順
        cmp     r3, r2              @ 更新前 - 更新後
        bge     pop_and_Error       @ 更新前が大きければエラー
        cmp     r3, r0              @ r0:終了条件
        blt     6f                  @ continue

    5: @ exit ループ終了
        ldrb    r1, [fp, #-1]       @ LSTACK=LSTACK-3
        sub     r1, r1, #3
        strb    r1, [fp, #-1]       @ LSTACK
        ldmfd   sp!, {pc}

    6: @ continue UNTIL
        ldrb    r1, [fp, #-1]       @ LSTACK 戻りアドレス
        sub     r3, r1, #1
        add     r2, fp, r3,LSL #2
        add     r2, r2, #512
        ldr     v3, [r2]            @ fp+(r1-1)*4+512
        sub     r3, r3, #1
        add     r2, fp, r3,LSL #2
        add     r2, r2, #512
        ldr     v2, [r2]            @ fp+(r1-2)*4+512
        mov     v5, #0              @ not EOL
        ldmfd   sp!, {pc}

    7: @ do
        mov     r0, #1              @ DO
        bl      PushValue
        bl      PushLine
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ 変数への代入, FOR文処理
@ v1 に変数名を設定して呼び出される
@-------------------------------------------------------------------------
SetVar:         @ 変数代入
        stmfd   sp!, {lr}
        bl      SkipAlpha           @ 変数の冗長部分の読み飛ばし
        add     v4, fp, r1,LSL #2   @ 変数のアドレス
        cmp     v1, #'('
        beq     s_array1            @ 1バイト配列
        cmp     v1, #'{'
        beq     s_array2            @ 2バイト配列
        cmp     v1, #'['
        beq     s_array4            @ 4バイト配列
        cmp     v1, #'*
        beq     s_strptr            @ ポインタ指定
        cmp     v1, #'=
        bne     pop_and_Error

        @ 単純変数
    0:  bl      Exp                 @ 式の処理(先読み無しで呼ぶ)
        str     r0, [v4]            @ 代入
        mov     r1, r0
        cmp     v1, #','            @ FOR文か?
        bne     3f                  @ 終了

        ldrb    ip, [fp, #-3]       @ ExecMode=Direct ?
        cmp     ip, #0
        bne     1f                  @ 実行時ならOKなのでFOR処理
        adr     r0, no_direct_mode  @ エラー表示
        bl      OutAsciiZ
        add     sp, sp, #4          @ スタック修正(pop)
        bl      WarmInit
        b       MainLoop            @ 戻る

    1:  @ for
        mov     ip, #0
        strb    ip, [fp, #-20]      @ 昇順(0)
        bl      Exp                 @ 終了値をr0に設定
        cmp     r0, r1              @ 開始値と終了値を比較
        bge     2f
        mov     ip, #1
        strb    ip, [fp, #-20]      @ 降順 (開始値 >= 終了値)
    2:
        bl      PushValue           @ 終了値を退避(NEXT部で判定)
        bl      PushLine            @ For文の直後を退避
    3:
        ldmfd   sp!, {pc}

    s_array1:
        bl      s_array
        bcs     s_range_err         @ 範囲外をアクセス
        strb    r0, [v4, r1]        @ 代入
        ldmfd   sp!, {pc}

    s_array2:
        bl      s_array
        bcs     s_range_err         @ 範囲外をアクセス
        mov     r1, r1, LSL #1
        strh    r0, [v4, r1]        @ 代入
        ldmfd   sp!, {pc}

    s_array4:
        bl      s_array
        bcs     s_range_err         @ 範囲外をアクセス
        str     r0, [v4, r1,LSL #2] @ 代入
        ldmfd   sp!, {pc}

    s_strptr:                       @ 文字列をコピー
        bl      GetChar             @ skip =
        ldr     v4, [v4]            @ 変数にはコピー先
        bl      RangeCheck          @ コピー先を範囲チェック
        bcs     s_range_err         @ 範囲外をアクセス
        ldrb    v1, [v3]            @ PeekChar
        cmp     v1, #'"
        bne     s_sp0

        mov     r2, #0              @ 文字列定数を配列にコピー
        bl      GetChar             @ skip "
    1:                              @ next char
        bl      GetChar
        cmp     v1, #'"
        beq     2f
        tst     v1, v1
        beq     2f
        strb    v1, [v4, r2]
        add     r2, r2, #1
        cmp     r2, #FNAMEMAX
        blo     1b
    2:                              @ done
        mov     v1, #0
        strb    v1, [v4, r2]
        mov     r1, #'%             @ %
        str     r2, [fp, r1,LSL #2] @ コピーされた文字数
        ldmfd   sp!, {pc}

    s_sp0:
        bl      Exp                 @ コピー元のアドレス
        cmp     v4, r0
        beq     3f
        mov     r2, v4              @ v4退避
        mov     v4, r0              @ RangeCheckはv4を見る
        bl      RangeCheck          @ コピー先を範囲チェック
        mov     v4, r2              @ コピー先復帰
        bcs     s_range_err         @ 範囲外をアクセス
        mov     r2, #0
    1:  ldrb    r1, [r0], #1
        strb    r1, [v4], #1
        add     r2, r2, #1
        cmp     r2, #0x40000        @ 262144文字まで
        beq     2f
        tst     r1, r1
        bne     1b
    2:  sub     r2, r2, #1          @ 文字数から行末を除く
        mov     r1, #'%             @ %
        str     r2, [fp, r1,LSL #2] @ コピーされた文字数
        ldmfd   sp!, {pc}

    3:  bl      StrLen
        mov     r2, #'%             @ %
        str     r1, [fp, r2,LSL #2] @ 文字数
        ldmfd   sp!, {pc}

    s_array:
        stmfd   sp!, {lr}
        bl      Exp                 @ 配列インデックス
        mov     r1, r0
        ldr     v4, [v4]
        bl      SkipCharExp         @ 式の処理(先読み無しで呼ぶ)
        bl      RangeCheck          @ 範囲チェック
        ldmfd   sp!, {pc}

    s_range_err:
        bl      RangeError          @ アクセス可能範囲を超えた
        ldmfd   sp!, {pc}

no_direct_mode: .asciz   "\nDirect mode is not allowed!\n"
                .align   2

@-------------------------------------------------------------------------
@ 配列のアクセス可能範囲をチェック
@ , < v4 < *
@-------------------------------------------------------------------------
RangeCheck:
        stmfd   sp!, {r0-r2, lr}
        mov     r2, #'[             @ 範囲チェックフラグ
        ldr     r0, [fp, r2,LSL #2]
        tst     r0, r0
        beq     2f                  @ 0 ならチェックしない
        ldr     r0, input_2         @ インプットバッファはOK
        cmp     v4, r0
        beq     2f
        mov     r2, #','            @ プログラム先頭
        ldr     r0, [fp, r2,LSL #2]
        mov     r2, #'*'            @ RAM末
        ldr     r1, [fp, r2,LSL #2]
        cmp     r0, v4              @ if = > addr, stc
        bhi     1f
        cmp     v4, r1              @ if * <= addr, stc
        bcc     2f
    1:  msr     cpsr_f, #0x20000000 @ set carry
        ldmfd   sp!, {r0-r2, pc}
    2:  msr     cpsr_f, #0x00000000 @ clear carry
        ldmfd   sp!, {r0-r2, pc}

input_2:         .long   input20

@-------------------------------------------------------------------------
@ 変数の冗長部分の読み飛ばし
@   変数名を r1 に退避, 次の文字を v1 に返す
@   SetVar, Variable で使用
@-------------------------------------------------------------------------
SkipAlpha:
        stmfd   sp!, {lr}
        mov     r1, v1            @ 変数名を r1 に退避
    1:  bl      GetChar
        bl      IsAlpha
        bcc     1b
    2:  ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ SkipEqualExp  = に続く式の評価
@ SkipCharExp   1文字を読み飛ばした後 式の評価
@ Exp           式の評価
@ r0 に値を返す (先読み無しで呼び出し, 1文字先読みで返る)
@-------------------------------------------------------------------------
SkipEqualExp:
        stmfd   sp!, {lr}
        bl      GetChar             @ check =
        ldmfd   sp!, {lr}

SkipEqualExp2:
        cmp     v1, #'='            @ 先読みの時
        beq     Exp                 @ = を確認
        adr     r0, equal_err       @
        bl      OutAsciiZ
        b       pop_and_Error       @ 文法エラー

SkipCharExp:
        stmfd   sp!, {lr}
        bl      GetChar             @ skip a character
        ldmfd   sp!, {lr}

Exp:
        stmfd   sp!, {r1, lr}
        ldrb    v1, [v3]            @ PeekChar
        cmp     v1, #' '
        bne     e_ok
        mov     r1, #1
        strb    r1, [fp, #-19]      @ 式中の空白はエラー
        b       LongJump            @ エラー

    e_ok:
        stmfd   sp!, {r1-r3, ip}
        bl      Factor              @ r1 に項の値
        mov     r0, r1              @ 式が項のみの場合に備える
    e_next:
        mov     r1, r0              @ これまでの結果をr1に格納
        cmp     v1,  #'+'           @ ADD
        bne     e_sub
        mov     r3, r1              @ 項の値を退避
        bl      Factor              @ 右項を取得
        add     r0, r3, r1          @ 2項を加算
        b       e_next
    e_sub:
        cmp     v1,  #'-'           @ SUB
        bne     e_mul
        mov     r3, r1              @ 項の値を退避
        bl      Factor              @ 右項を取得
        sub     r0, r3, r1          @ 左項から右項を減算
        b       e_next
    e_mul:
        cmp     v1,  #'*'           @ MUL
        bne     e_div
        mov     r3, r1              @ 項の値を退避
        bl      Factor              @ 右項を取得
        mul     r0, r3, r1          @ 左項から右項を減算
        b       e_next
    e_div:
        cmp     v1,  #'/'           @ DIV
        bne     e_udiv
        mov     r3, r1              @ 項の値を退避
        tst     r3, r3
        mov     r2, #0              @ 被除数が正
        rsbmi   r3, r3, #0          @ r3 = -r3
        movmi   r2, #1              @ 被除数が負
        bl      Factor              @ 右項を取得
        tst     r1, r1
        bne     e_div1
        mov     r2, #1
        strb    r2, [fp, #-18]      @ ０除算エラー
        b       e_exit
    e_div1:
        mov     ip, #0              @ 除数が正
        rsbmi   r1, r1, #0          @ r1 = -r1
        movmi   ip, #1              @ 除数が負
        mov     r0, r3
        bl      udiv                @ r0/r1 = r0...r1
        cmp     r2, #0
        rsbne   r1, r1, #0          @ r1 = -r1
        cmp     ip, r2              @
        rsbne   r0, r0, #0          @ r0 = -r0
        mov     r2, #'%'            @ 剰余の保存
        str     r1, [fp, r2,LSL #2]
        mov     r1, r0              @ 商を r1 に
        b       e_next
    e_udiv:
        cmp     v1,  #'\\'           @ UDIV
        bne     e_and
        mov     r3, r1              @ 項の値を退避
        bl      Factor              @ 右項を取得
        tst     r1, r1
        bne     e_udiv1
        mov     r2, #1
        strb    r2, [fp, #-18]      @ ０除算エラー
        b       e_exit
    e_udiv1:
        mov     r0, r3
        bl      udiv                @ r0/r1 = r0...r1
        mov     r2, #'%'            @ 剰余の保存
        str     r1, [fp, r2,LSL #2]
        mov     r1, r0              @ 商を r1 に
        b       e_next
    e_and:
        cmp     v1, #'&'            @ AND
        bne     e_or
        mov     r3, r1              @ 項の値を退避
        bl      Factor              @ 右項を取得
        and     r0, r3, r1
        b       e_next
    e_or:
        cmp     v1,  #'|'           @ OR
        bne     e_xor
        mov     r3, r1              @ 項の値を退避
        bl      Factor              @ 右項を取得
        orr     r0, r3, r1          @ 左項と右項を OR
        b       e_next
    e_xor:
        cmp     v1, #'^'            @ XOR
        bne     e_equal
        mov     r3, r1              @ 項の値を退避
        bl      Factor              @ 右項を取得
        eor     r0, r3, r1          @ 左項と右項を XOR
        b       e_next
    e_equal:
        cmp     v1, #'='            @ =
        bne     e_exp7
        mov     r3, r1              @ 項の値を退避
        bl      Factor              @ 右項を取得
        cmp     r1, r3              @ 左項と右項を比較
        bne     e_false
    e_true:
        mov     r0, #1
        b       e_next
    e_false:
        mov     r0, #0              @ 0:偽
        b       e_next
    e_exp7:
        cmp     v1, #'<'            @ <
        bne     e_exp8
        ldrb    v1, [v3]            @ PeekChar
        cmp     v1, #'='            @ <=
        beq     e_exp71
        cmp     v1, #'>'            @ <>
        beq     e_exp72
        cmp     v1, #'<'            @ <<
        beq     e_shl
                                    @ <
        mov     r3, r1              @ 項の値を退避
        bl      Factor              @ 右項を取得
        cmp     r3, r1              @ 左項と右項を比較
        bge     e_false
        b       e_true
    e_exp71:
        bl      GetChar             @ <=
        mov     r3, r1              @ 項の値を退避
        bl      Factor              @ 右項を取得
        cmp     r3, r1              @ 左項と右項を比較
        bgt     e_false
        b       e_true
    e_exp72:
        bl      GetChar             @ <>
        mov     r3, r1              @ 項の値を退避
        bl      Factor              @ 右項を取得
        cmp     r3, r1              @ 左項と右項を比較
        beq     e_false
        b       e_true
    e_shl:
        bl      GetChar             @ <<
        cmp     v1, #'<'            @
        bne     e_exp9
        mov     r3, r1              @ 項の値を退避
        bl      Factor              @ 右項を取得
        mov     r0, r3, LSL r1      @ 左項を右項で SHL (*2)
        b       e_next
    e_exp8:
        cmp     v1, #'>'            @ >
        bne     e_exp9
        ldrb    v1, [v3]            @ PeekChar
        cmp     v1, #'='            @ >=
        beq     e_exp81
        cmp     v1,  #'>'           @ >>
        beq     e_shr
                                    @ >
        mov     r3, r1              @ 項の値を退避
        bl      Factor              @ 右項を取得
        cmp     r3, r1              @ 左項と右項を比較
        ble     e_false
        b       e_true
    e_exp81:
        bl      GetChar             @ >=
        mov     r3, r1              @ 項の値を退避
        bl      Factor              @ 右項を取得
        cmp     r3, r1              @ 左項と右項を比較
        blt     e_false
        b       e_true
    e_shr:
        bl      GetChar             @ >>
        mov     r3, r1              @ 項の値を退避
        bl      Factor              @ 右項を取得
        mov     r0, r3, LSR r1      @ 左項を右項で SHR (/2)
        b       e_next
    e_exp9:
    e_exit:
        ldmfd   sp!, {r1-r3, ip}    @
        ldmfd   sp!, {r1, pc}       @ return

equal_err:
        .asciz   "\n= reqiured."
        .align   2

@-------------------------------------------------------------------------
@ UNIX時間をマイクロ秒単位で返す
@-------------------------------------------------------------------------
GetTime:
        stmfd   sp!, {r0, r2, r3, r7, lr}
        ldr     r3, TV0
        mov     r0, r3
        add     r1, r3, #8          @ TZ
        mov     r7, #sys_gettimeofday
        swi     0
        ldr     r1, [r3]            @ sec
        ldr     r0, [r3, #4]        @ usec
        mov     r2, #'%'            @ 剰余に usec を保存
        str     r0, [fp, r2,LSL #2]
        bl      GetChar
        ldmfd   sp!, {r0, r2, r3, r7, pc}

TV0:    .long   TV

@-------------------------------------------------------------------------
@ マイクロ秒単位のスリープ _=n
@-------------------------------------------------------------------------
Com_USleep:
        stmfd   sp!, {v1-v2, r7, lr}
        bl      SkipEqualExp        @ = を読み飛ばした後 式の評価

        ldr     v1, TV0             @ 第5引数
        mov     r2, #1000           @ r2 = 1000
        mul     r1, r2, r2          @ r1 = 1000000, r0 = usec
        bl      udiv                @ r0  / r1 -> r0 ... r1

        str     r0, [v1]            @ sec
        mul     r0, r1, r2          @ usec(r1) --> nsec(r0)
        str     r0, [v1, #+4]       @ nsec
        mov     r0, #0
        mov     r2, r0
        mov     r3, r0
        mov     v2, r0              @ 第6引数 NULL
        ldr     r7, SYS_PSELECT6
        swi     0
        bl      CheckError
        ldmfd   sp!, {v1-v2, r7, pc}

SYS_PSELECT6:   .long    sys_pselect6

@-------------------------------------------------------------------------
@ 配列と変数の参照, r1 に値が返る
@ 変数参照にv4を使用(保存)
@ r0 は上位のFactorで保存
@-------------------------------------------------------------------------
Variable:
        stmfd   sp!, {v4, lr}
        bl      SkipAlpha           @ 変数名は r1
        add     v4, fp, r1,LSL #2   @ 変数のアドレス
        cmp     v1, #'('
        beq     v_array1            @ 1バイト配列
        cmp     v1, #'{'
        beq     v_array2            @ 2バイト配列
        cmp     v1, #'['
        beq     v_array4            @ 4バイト配列
        ldr     r1, [v4]            @ 単純変数
        ldmfd   sp!, {v4, pc}       @ return

    v_array1:
        bl      Exp                 @ 1バイト配列
        ldr     v4, [v4]
        bl      RangeCheck          @ 範囲チェック
        bcs     v_range_err         @ 範囲外をアクセス
        ldrb    r1, [v4, r0]
        bl      GetChar             @ skip )
        ldmfd   sp!, {v4, pc}       @ return

    v_array2:
        bl      Exp                 @ 2バイト配列
        ldr     v4, [v4]
        bl      RangeCheck          @ 範囲チェック
        bcs     v_range_err         @ 範囲外をアクセス
        mov     r0, r0, LSL #1
        ldrh    r1, [v4, r0]
        bl      GetChar             @ skip }
        ldmfd   sp!, {v4, pc}       @ return

    v_array4:
        bl      Exp                 @ 4バイト配列
        ldr     v4, [v4]
        bl      RangeCheck          @ 範囲チェック
        bcs     v_range_err         @ 範囲外をアクセス
        ldr     r1, [v4, r0,LSL #2]
        bl      GetChar             @ skip ]
        ldmfd   sp!, {v4, pc}       @ return

    v_range_err:
        bl      RangeError
        ldmfd   sp!, {v4, pc}       @ return

@-------------------------------------------------------------------------
@ 変数値
@ r1 に値を返す (先読み無しで呼び出し, 1文字先読みで返る)
@-------------------------------------------------------------------------
Factor:
        stmfd   sp!, {r0, r2, lr}   @
        bl      GetChar
        bl      IsNum
        bcs     f_bracket
        bl      Decimal             @ 正の10進整数
        mov     r1, r0
        ldmfd   sp!, {r0, r2, pc}   @

    f_bracket:
        cmp     v1, #'('
        bne     f_yen
        bl      Exp                 @ カッコ処理
        mov     r1, r0              @ 項の値は r1
        bl      GetChar             @ skip )
        ldmfd   sp!, {r0, r2, pc}   @

    f_yen:
        cmp     v1, #'\\            @ '\'
        bne     f_rand
        ldrb    v1, [v3]            @ PeekChar
        cmp     v1, #'\\            @ '\\'
        beq     f_env

        bl      Exp                 @ 引数番号を示す式
        ldr     r2, argc_vtl        @ vtl用の引数の個数
        ldr     r2, [r2]
        cmp     r0, r2              @ 引数番号と引数の数を比較
        blt     2f                  @ 引数番号 < 引数の数
        ldr     r2, argvp           @ not found
        ldr     r2, [r2]            @ argvp0
        ldr     r1, [r2]            @ argvp[0]
    1:  ldrb    r2, [r1], #1        @ 0を探す
        cmp     r2, #0
        bne     1b
        sub     r1, r1, #1          @ argv[0]のEOLに設定
        b       3f
    2:  ldr     r2, argp_vtl        @ found
        ldr     r2, [r2]
        ldr     r1, [r2, r0,LSL #2] @ 引数文字列先頭アドレス
    3:  ldmfd   sp!, {r0, r2, pc}   @

    f_env:
        bl      GetChar             @ skip '\'
        bl      Exp
        ldr     r2, envp
        ldr     r2, [r2]            @ envp0
        mov     r1, #0
    4:  ldr     ip, [r2, r1, LSL #2]
        cmp     ip, #0
        beq     5f
        add     r1, r1, #1
        b       4b
    5:
        cmp     r0, r1
        bge     6f                  @ 引数番号が過大
        ldr     r1, [r2, r0,LSL #2] @ 引数文字列先頭アドレス
        ldmfd   sp!, {r0, r2, pc}   @ return
    6:
        add     r1, r2, r1,LSL #2   @ 0へのポインタ(空文字列)
        ldmfd   sp!, {r0, r2, pc}   @ return


    f_rand:
        cmp     v1, #'`'
        bne     f_hex
        bl      genrand             @ 乱数の読み出し
        mov     r1, r0
        bl      GetChar
        ldmfd   sp!, {r0, r2, pc}   @

    f_hex:
        cmp     v1, #'$'
        bne     f_time
        bl      Hex                 @ 16進数または1文字入力
        ldmfd   sp!, {r0, r2, pc}   @

    f_time:
        cmp     v1, #'_'
        bne     f_num
        bl      GetTime             @ 時間を返す
        ldmfd   sp!, {r0, r2, pc}   @

    f_num:
        cmp     v1, #'?'
        bne     f_char
        bl      NumInput            @ 数値入力
        ldmfd   sp!, {r0, r2, pc}   @

    f_char:
        cmp     v1, #0x27
        bne     f_singnzex
        bl      CharConst           @ 文字定数
        ldmfd   sp!, {r0, r2, pc}   @

    f_singnzex:
        cmp     v1, #'<'
        bne     f_neg
        bl      Factor
        mov     r1, r1              @ ゼロ拡張(64bit互換機能)
        ldmfd   sp!, {r0, r2, pc}   @

    f_neg:
        cmp     v1, #'-'
        bne     f_abs
        bl      Factor              @ 負符号
        mov     r2, #0
        sub     r1, r2, r1
        ldmfd   sp!, {r0, r2, pc}   @

    f_abs:
        cmp     v1, #'+'
        bne     f_realkey
        bl      Factor              @ 変数，配列の絶対値
        tst     r1, r1
        bpl     f_exit
        mov     r2, #0
        sub     r1, r2, r1
        ldmfd   sp!, {r0, r2, pc}   @

    f_realkey:
        cmp     v1, #'@'
        bne     f_winsize
        bl      RealKey             @ リアルタイムキー入力
        mov     r1, r0
        bl      GetChar
        ldmfd   sp!, {r0, r2, pc}   @

    f_winsize:
        cmp     v1, #'.'
        bne     f_pop
        bl      WinSize             @ ウィンドウサイズ取得
        mov     r1, r0
        bl      GetChar
        ldmfd   sp!, {r0, r2, pc}   @

    f_pop:
        cmp     v1, #';'
        bne     f_label
        ldr     r2, [fp, #-16]      @ VSTACK
        subs    r2, r2, #1
        movlo   r2, #2
        strlob  r2, [fp, #-19]      @ 変数スタックエラー
        blo     1f
        add     r0, fp, r2,LSL #2
        add     r0, r0, #1024       @ fp+r2*4+1024
        ldr     r1, [r0]            @ 変数スタックから復帰
        str     r2, [fp, #-16]      @ スタックポインタ更新
    1:  bl      GetChar
        ldmfd   sp!, {r0, r2, pc}   @

    f_label:
.ifdef VTL_LABEL
        cmp     v1, #'^'
        bne     f_var
        bl      LabelSearch         @ ラベルのアドレスを取得
        movcs   r2, #3
        strcsb  r2, [fp, #-19]      @ ラベルエラー
    2:  ldmfd   sp!, {r0, r2, pc}   @
.endif

    f_var:
        bl      Variable            @ 変数，配列参照
    f_exit:
        ldmfd   sp!, {r0, r2, pc}   @

@-------------------------------------------------------------------------
@ コンソールから数値入力
@-------------------------------------------------------------------------
NumInput:
        stmfd   sp!, {r0, r2, lr}   @
        mov     r2, v5              @ EOL状態退避
        mov     r0, #MAXLINE        @ 1 行入力
        stmfd   sp!, {v3}
        ldr     r1, input2          @ 行ワークエリア
        bl      READ_LINE3
        mov     v3, r1
        ldrb    v1, [v3], #1        @ 1文字先読み
        bl      Decimal
        ldmfd   sp!, {v3}
        mov     r1, r0
        mov     v5, r2              @ EOL状態復帰
        bl      GetChar
        ldmfd   sp!, {r0, r2, pc}   @

@-------------------------------------------------------------------------
@ コンソールから input2 に文字列入力
@-------------------------------------------------------------------------
StringInput:
        stmfd   sp!, {r0, r2-r3, lr}    @
        mov     r2, v5              @ EOL状態退避
        mov     r0, #MAXLINE        @ 1 行入力
        ldr     r1, input2          @ 行ワークエリア
        bl      READ_LINE3
    2:  mov     r3, #'%             @ %
        str     r0, [fp, r3,LSL #2] @ 文字数を返す
        mov     v5, r2              @ EOL状態復帰
        bl      GetChar
        ldmfd   sp!, {r0, r2-r3, pc}    @

@-------------------------------------------------------------------------
@ 文字定数を数値に変換
@ r1 に数値が返る
@-------------------------------------------------------------------------
CharConst:
        stmfd   sp!, {r0, r2, lr}   @
        mov     r1, #0
        mov     r0, #4              @ 文字定数は4バイトまで
    1:
        bl      GetChar
        cmp     v1, #0x27            @ #'''
        beq     2f
        add     r1, v1, r1, LSL #8
        subs    r0, r0, #1
        bne     1b
    2:
        bl      GetChar
        ldmfd   sp!, {r0, r2, pc}   @

@-------------------------------------------------------------------------
@ 16進整数の文字列を数値に変換
@ r1 に数値が返る
@-------------------------------------------------------------------------
Hex:
        ldrb    v1, [v3]            @ check $$
        cmp     v1, #'$
        beq     StringInput
        stmfd   sp!, {r0, r2, lr}   @
        mov     r1, #0
        mov     r2, r1
    1:
        bl      GetChar             @ $ の次の文字
        bl      IsNum
        bcs     2f
        sub     v1, v1, #'0'        @ 整数に変換
        b       4f
    2:
        cmp     v1, #' '            @ 数字以外
        beq     5f
        cmp     v1, #'A'
        blo     5f                  @ 'A' より小なら
        cmp     v1, #'F'
        bhi     3f
        sub     v1, v1, #55         @ -'A'+10 = -55
        b       4f
    3:
        cmp     v1, #'a'
        blo     5f
        cmp     v1, #'f'
        bhi     5f
        sub     v1, v1, #87         @ -'a'+10 = -87
    4:
        add     r1, v1, r1, LSL #4
        add     r2, r2, #1
        b       1b
    5:
        tst     r2, r2
        beq     CharInput
        ldmfd   sp!, {r0, r2, pc}   @

@-------------------------------------------------------------------------
@ コンソールから 1 文字入力, EBXに返す
@-------------------------------------------------------------------------
CharInput:
        bl      InChar
        mov     r1, r0
        ldmfd   sp!, {r0, r2, pc}   @

@-------------------------------------------------------------------------
@ 行の編集
@   r0 行番号
@ r4  v1    次の文字(GetCharが返す)
@ r5  v2    実行時行先頭
@ r6  v3    ソースへのポインタ(getcharで更新)
@ r7  v4    変数のアドレス
@ r8  v5    EOLフラグ
@ r9  v6    変数スタックポインタ
@ r10 v7    入力行バッファ
@ r11 v8 fp 変数領域の先頭アドレス
@ r12 ip    局所的な作業レジスタ
@-------------------------------------------------------------------------
LineEdit:
        bl      LineSearch          @ 入力済み行番号を探索
        bcc     4f                  @ 見つからないので終了
        ldr     v3, input           @ 入力バッファ
        ldr     r0, [v2, #+4]
        bl      PutDecimal          @ 行番号書き込み
        mov     r0, #' '
        strb    r0, [v3]
        add     v3, v3, #1
        add     v2, v2, #8
    2:
        ldrb    r0, [v2], #1        @ 行を入力バッファにコピー
        strb    r0, [v3], #1
        cmp     r0, #0
        bne     2b                  @ 行末か?
    3:
        bl      DispPrompt
        mov     r0, #MAXLINE        @ 1 行入力
        ldr     r1, input
        bl      READ_LINE2          @ 初期化済行入力
        mov     v3, r1
    4:
        mov     v5, #0              @ EOL=no, 入力済み
        ldmfd   sp!, {pc}           @ Mainloopにreturn

@-------------------------------------------------------------------------
@ ListMore
@   eax に表示開始行番号
@-------------------------------------------------------------------------
ListMore:
        bl      LineSearch          @ 表示開始行を検索
        bl      GetChar             @ skip '+'
        bl      Decimal             @ 表示行数を取得
        movcs   r0, #20             @ 表示行数無指定は20行
        mov     r2, v2
    1:  ldr     r1, [r2]            @ 次行までのオフセット
        tst     r1, r1
        bmi     List_all            @ コード最終か?
        ldr     r3, [r2, #+4]       @ 行番号
        add     r2, r2, r1          @ 次行先頭
        subs    r0, r0, #1
        bne     1b
        b       List_loop

@-------------------------------------------------------------------------
@ List
@  r0 に表示開始行番号
@  v2 表示行先頭アドレス(破壊)
@-------------------------------------------------------------------------
List:
        tst     r0, r0
        bne     1f                  @ partial
        mov     r1, #'=             @ プログラム先頭
        ldr     v2, [fp, r1,LSL #2]
        b       List_all

    1:  bl      LineSearch          @ 表示開始行を検索
        bl      GetChar             @ 仕様では -
        bl      Decimal             @ 範囲最終を取得
        movcc   r3, r0              @ 終了行番号
        bcc     List_loop

List_all:
        mvn     r3, #0              @ 最終まで表示(最大値)
List_loop:
        ldr     r2, [v2]            @ 次行までのオフセット
        tst     r2, r2
        bmi     6f                  @ コード最終か?
@        ble     6f                  @ コード最終か?
        ldr     r0, [v2, #+4]       @ 行番号
        cmp     r3, r0
        blo     6f
        bl      PrintLeft           @ 行番号表示
        mov     r0, #' '
        bl      OutChar
        mov     r1, #8
    4:
        ldrb    r0, [v2, r1]        @ コード部分表示
        cmp     r0, #0
        beq     5f                  @ 改行
        bl      OutChar
        add     r1, r1, #1          @ 次の1文字
        b       4b
    5:  bl      NewLine
        add     v2, v2, r2
        b       List_loop           @ 次行処理

    6:
        mov     v5, #1              @ 次に行入力 EOL=yes
        ldmfd   sp!, {pc}           @ Mainloopにreturn

.ifdef DEBUG

@-------------------------------------------------------------------------
@ デバッグ用プログラム行リスト <xxxx> 1#
@-------------------------------------------------------------------------
DebugList:
        stmfd   sp!, {r0-r3, v2, lr}
        mov     r1, #'=             @ プログラム先頭
        ldr     v2, [fp, r1,LSL #2]
        mov     r0, v2
        bl      PrintHex8           @ プログラム先頭表示
        mov     r0, #' '
        bl      OutChar
        mov     r1, #'&             @ ヒープ先頭
        ldr     r0, [fp, r1,LSL #2]
        bl      PrintHex8           @ ヒープ先頭表示
        sub     r2, r0, v2          @ プログラム領域サイズ
        mov     r0, #' '
        bl      OutChar
        mov     r0, r2
        bl      PrintLeft
        bl      NewLine
        mvn     r3, #0              @ 最終まで表示(最大値)
    1:
        mov     r0, v2
        bl      PrintHex8           @ 行頭アドレス
        ldr     r2, [v2]            @ 次行までのオフセット
        mov     r0, #' '
        bl      OutChar
        mov     r0, r2
        bl      PrintHex8           @ オフセットの16進表記
        mov     r1, #4              @ 4桁右詰
        bl      PrintRight          @ オフセットの10進表記
        mov     r0, #' '
        bl      OutChar
        tst     r2, r2
        ble     4f                  @ コード最終か?

        ldr     r0, [v2, #+4]       @ 行番号
        cmp     r3, r0
        blo     4f
        bl      PrintLeft           @ 行番号表示
        mov     r0, #' '
        bl      OutChar
        mov     r1, #8
    2:
        ldrb    r0, [v2, r1]        @ コード部分表示
        cmp     r0, #0
        beq     3f                  @ 改行
        bl      OutChar
        add     r1, r1, #1          @ 次の1文字
        b       2b
    3:  bl      NewLine
        add     v2, v2, r2
        b       1b                  @ 次行処理

    4:  bl      NewLine
        ldmfd   sp!, {r0-r3, v2, pc}

call_DebugList:
        bl      DebugList
        ldmfd   sp!, {pc}           @ Mainloopにreturn

@-------------------------------------------------------------------------
@ デバッグ用変数リスト <xxxx> 1$
@-------------------------------------------------------------------------
VarList:
        stmfd   sp!, {r0-r2, lr}

        mov     r2, #0x21
    1:  mov     r0, r2
        bl      OutChar
        mov     r0, #' '
        bl      OutChar
        ldr     r0, [fp, r2,LSL #2]
        bl      PrintHex8
        mov     r1, #12
        bl      PrintRight
        bl      NewLine
        add     r2, r2, #1
        cmp     r2, #0x7F
        blo     1b
        ldmfd   sp!, {r0-r2, pc}

call_VarList:
        bl      VarList
        ldmfd   sp!, {pc}           @ Mainloopにreturn

@-------------------------------------------------------------------------
@ デバッグ用ダンプリスト <xxxx> 1%
@-------------------------------------------------------------------------
DumpList:
        stmfd   sp!, {r0-r3, v1, lr}
        mov     r1, #'=             @ プログラム先頭
        ldr     r2, [fp, r1,LSL #2]
        and     r2, r2, #0xfffffff0 @ 16byte境界から始める
        mov     v1, #8
    1:  mov     r0, r2
        bl      PrintHex8           @ 先頭アドレス表示
        mov     r0, #' '
        bl      OutChar
        mov     r0, #':'
        bl      OutChar
        mov     r3, #16
    2:
        mov     r0, #' '
        bl      OutChar
        ldrb    r0, [r2], #1        @ 1バイト表示
        bl      PrintHex2
        subs    r3, r3, #1
        bne     2b
        bl      NewLine
        subs    v1, v1, #1
        bne     1b                  @ 次行処理
        ldmfd   sp!, {r0-r3, v1, pc}

call_DumpList:
        bl      DumpList
        ldmfd   sp!, {pc}           @ Mainloopにreturn

@-------------------------------------------------------------------------
@ デバッグ用ラベルリスト <xxxx> 1&
@-------------------------------------------------------------------------
LabelList:
        stmfd   sp!, {lr}
        ldr     ip, LabelTable      @ ラベルテーブル先頭
        ldr     r2, TablePointer
        ldr     r3, [r2]            @ テーブル最終登録位置
    1:
        cmp     ip, r3
        bhs     2f
        ldr     r0, [ip, #12]
        bl      PrintHex8
        mov     r0, #' '
        bl      OutChar
        mov     r0, ip
        bl      OutAsciiZ
        bl      NewLine
        add     ip, ip, #16
        b       1b
     2: ldmfd   sp!, {pc}

call_LabelList:
        bl      LabelList
        ldmfd   sp!, {pc}           @ Mainloopにreturn
.endif

@-------------------------------------------------------------------------
@  編集モード
@  Mainloopからcallされる
@       0) 行番号 0 ならリスト
@       1) 行が行番号のみの場合は行削除
@       2) 行番号の直後が - なら行番号指定部分リスト
@       3) 行番号の直後が + なら行数指定部分リスト
@       4) 行番号の直後が ! なら指定行編集
@       5) 同じ行番号の行が存在すれば入れ替え
@       6) 同じ行番号がなければ挿入
@-------------------------------------------------------------------------
EditMode:
        stmfd   sp!, {lr}
        bl      Decimal             @ 行番号取得
        tst     r0, r0              @ 行番号
        beq     List                @ 行番号 0 ならリスト
        cmp     v1, #0              @ 行番号のみか
        bne     1f
        bl      LineDelete          @ 行削除
        ldmfd   sp!, {pc}           @ Mainloopにreturn

    1:  cmp     v1, #'-'
        beq     List                @ 部分リスト
        cmp     v1, #'+'
        beq     ListMore            @ 部分リスト 20行
.ifdef DEBUG
        cmp     v1, #'#'
        beq     call_DebugList      @ デバッグ用行リスト[#]
        cmp     v1, #'$'
        beq     call_VarList        @ デバッグ用変数リスト[$]
        cmp     v1, #'%'
        beq     call_DumpList       @ デバッグ用ダンプリスト[%]
        cmp     v1, #'&'
        beq     call_LabelList      @ デバッグ用ラベルリスト[&]
.endif
        cmp     v1, #'!'
        beq     LineEdit            @ 指定行編集
        bl      LineSearch          @ 入力済み行番号を探索
        bcc     LineInsert          @ 一致する行がなければ挿入
        bl      LineDelete          @ 行置換(行削除+挿入)

@-------------------------------------------------------------------------
@ 行挿入
@ r0 に挿入行番号
@ v2 に挿入位置
@-------------------------------------------------------------------------
LineInsert:
        mov     r1, #0              @ 挿入する行のサイズを計算
    1:  ldrb    r2, [v3, r1]        @ v3:入力バッファ先頭
        cmp     r2, #0              @ 行末?
        add     r1, r1, #1          @ 次の文字
        bne     1b

        add     r1, r1, #12         @ 12=4+4+1+3
        and     r1, r1, #0xfffffffc @ 4バイト境界に整列
        mov     ip, #'&             @ ヒープ先頭(コード末)
        ldr     r3, [fp, ip,LSL #2] @ ヒープ先頭アドレス
        mov     r2, r3              @ 元のヒープ先頭
        add     r3, r3, r1          @ 新ヒープ先頭計算
        str     r3, [fp, ip,LSL #2] @ 新ヒープ先頭設定
        sub     v1, r2, v2          @ 移動バイト数

        sub     r2, r2, #1          @ 始めは old &-1 から
        sub     r3, r3, #1          @ new &-1 へのコピー

    2:
        ldrb    ip, [r2], #-1       @ メモリ後部から移動
        strb    ip, [r3], #-1
        subs    v1, v1, #1          @ v1バイト移動
        bne     2b

        str     r1, [v2]            @ 次行へのオフセット設定
        str     r0, [v2, #4]        @ 行番号設定
        add     v2, v2, #8          @ 書き込み位置更新

    3:  ldrb    r2, [v3],#1         @ v3:入力バッファ
        strb    r2, [v2],#1         @ v2:挿入位置
        cmp     r2, #0              @ 行末?
        bne     3b
        mov     v5, #1              @ 次に行入力 EOL=yes
        ldmfd   sp!, {pc}           @ Mainloopにreturn

@-------------------------------------------------------------------------
@ 行の削除
@ r0 に検索行番号
@-------------------------------------------------------------------------
LineDelete:
        stmfd   sp!, {r0, lr}
        bl      LineSearch          @ 入力済み行番号を探索
        bcc     2f                  @ 一致する行がなければ終了
        mov     r0, v2              @ 削除行先頭位置
        ldr     r2, [v2]            @ 次行オフセット取得
        add     r2, v2, r2          @ 次行先頭位置取得
        mov     r1, #'&             @ ヒープ先頭
        ldr     r3, [fp, r1,LSL #2]
        sub     v1, r3, r2          @ v1:移動バイト数
    1:
        ldrb    ip, [r2], #1        @ v1バイト移動
        strb    ip, [r0], #1
        subs    v1, v1, #1
        bne     1b
        str     r3, [fp, r1,LSL #2]
    2:
        mov     v5, #1              @ 次に行入力 EOL=yes
        ldmfd   sp!, {r0, pc}       @ return

@-------------------------------------------------------------------------
@ 入力済み行番号を探索
@ r0 に検索行番号、r1, r2 破壊
@ 一致行先頭または不一致の場合には次に大きい行番号先頭位置にv2設定
@ 同じ行番号があればキャリーセット
@-------------------------------------------------------------------------
LineSearch:
        mov     r1, #'=             @ プログラム先頭
        ldr     v2, [fp, r1,LSL #2]
LineSearch_nextline:
    1:  ldr     r1, [v2]            @ コード末なら検索終了
        tst     r1, r1
        bmi     3f                  @ exit
        ldr     r2, [v2, #+4]       @ 行番号
        cmp     r0, r2
        beq     2f                  @ 検索行r0 = 注目行r2
        blo     3f                  @ 検索行r0 < 注目行r2
        add     v2, v2, r1          @ 次行先頭 (v2=v2+offset)
        b       1b
    2:  msr     cpsr_f, #0x20000000 @
        mov     pc, lr              @ return
    3:  msr     cpsr_f, #0x00000000 @
        mov     pc, lr              @ return

@-------------------------------------------------------------------------
@ 10進文字列を整数に変換
@ r0 に数値が返る、非数値ならキャリーセット
@ 1 文字先読み(v1)で呼ばれ、1 文字先読み(v1)して返る
@-------------------------------------------------------------------------
Decimal:
        stmfd   sp!, {r1,r2, lr}
        mov     r2, #0              @ 正の整数を仮定
        mov     r0, #0
        mov     r1, #10
        cmp     v1, #'+
        beq     1f
        cmp     v1, #'-
        bne     2f                  @ Num
        mov     r2, #1              @ 負の整数
    1:
        bl      GetDigit
        bcs     4f                  @ 数字でなければ返る
        b       3f
    2:
        bl      IsNum
        bcs     4f                  @ 数字でない
        sub     v1, v1, #'0         @ 数値に変換

    3:
        mla     ip, r0, r1, v1      @ r0=r0*10+v1
        mov     r0, ip
        bl      GetDigit
        bcc     3b
        tst     r2, r2              @ 数は負か？
        rsbne   r0, r0, #0          @ 負にする
        msreq   cpsr_f, #0x00       @ clear carry
    4:  ldmfd   sp!, {r1,r2, pc}    @ return

@-------------------------------------------------------------------------
@ 符号無し10進数文字列 v3 の示すメモリに書き込み
@ r0 : 数値
@-------------------------------------------------------------------------
PutDecimal:
        stmfd   sp!, {r0-r2, lr}    @ push
        mov     r2, #0              @ counter
    1:  mov     r1, #10             @
        bl      udiv                @ division by 10
        add     r2, r2, #1          @ counter++
        stmfd   sp!, {r1}           @ least digit (reminder)
        cmp     r0, #0
        bne     1b                  @ done ?
    2:  ldmfd   sp!, {r0}           @ most digit
        add     r0, r0, #'0'        @ ASCII
        strb    r0, [v3], #1        @ output a digit
        subs    r2, r2, #1          @ counter--
        bne     2b
        ldmfd   sp!, {r0-r2, pc}    @ pop & return

@---------------------------------------------------------------------
@ v1 の文字が数字かどうかのチェック
@ 数字なら整数に変換して v1 返す. 非数字ならキャリーセット
@ ! 16進数と文字定数の処理を加えること
@---------------------------------------------------------------------

IsNum:  cmp     v1, #'0'            @ 0 - 9
        bcs     1f
        msr     cpsr_f, #0x20000000 @ set carry v1<'0'
        mov     pc, lr              @ return
    1:  cmp     v1, #':'            @ set carry v1>'9'
        mov     pc, lr              @ return

GetDigit:
        stmfd   sp!, {lr}
        bl      GetChar             @ 0 - 9
        bl      IsNum
        subcc   v1, v1, #'0'        @ 整数に変換 Cy=0
        ldmfd   sp!, {pc}

IsAlpha:
        stmfd   sp!, {lr}
        bl      IsAlpha1            @ 英大文字か?
        bcc     1f                  @ yes
        bl      IsAlpha2            @ 英小文字か?
    1:  ldmfd   sp!, {pc}

IsAlpha1:
        cmp     v1, #'A             @ 英大文字(A-Z)か?
        bcs     1f
        msr     cpsr_f, #0x20000000 @ if v1<'A' Cy=1
        mov     pc, lr              @ return
    1:  cmp     v1, #'[             @ if v1>'Z' Cy=1
        mov     pc, lr              @ return

IsAlpha2:
        cmp     v1, #'a             @ 英小文字(a-z)か?
        bcs     1f
        msr     cpsr_f, #0x20000000 @ if v1<'a' Cy=1
        mov     pc, lr              @ return
    1:  cmp     v1, #'z+1           @ if v1>'z' Cy=1
        mov     pc, lr              @ return

IsAlphaNum:
        stmfd   sp!, {lr}
        bl      IsAlpha             @ 英文字か?
        bcc     1f                  @ yes
        bl      IsNum               @ 数字か?
    1:  ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ ファイル読み込み
@-------------------------------------------------------------------------
READ_FILE:
        stmfd   sp!, {r7, lr}
        mov     ip, #0              @ ip=0
        ldr     r1, input_0         @ 入力バッファアドレス
    1:
        ldr     r0, [fp, #-8]       @ FileDesc
        mov     r2, #1              @ 読みこみバイト数
        mov     r7, #sys_read       @ ファイルから読みこみ
        swi     0
        tst     r0, r0
        beq     2f                  @ EOF ?

        ldrb     r0, [r1]
        cmp     r0, #10             @ LineFeed ?
        beq     3f
        add     r1, r1, #1          @ input++
        b       1b
    2:
        ldr     r0, [fp, #-8]       @ FileDesc
        bl      fclose              @ File Close
        strb    ip, [fp, #-4]       @ Read from console (0)
        bl      LoadCode            @ 起動時指定ファイル有？
        b       4f
    3:  mov     v5, ip              @ EOL=no
    4:  strb    ip, [r1]
        ldr     v3, input_0
        ldmfd   sp!, {r7, pc}

input_0:    .long   input0          @ vtllib.sのbss上のバッファ

@-------------------------------------------------------------------------
@ 数値出力 ?
@-------------------------------------------------------------------------
Com_OutNum:
        stmfd   sp!, {lr}
        bl      GetChar             @ get next
        cmp     v1, #'='
        bne     1f
        bl      Exp                 @ PrintLeft
        bl      PrintLeft
        ldmfd   sp!, {pc}

    1:
        cmp     v1, #'*'            @ 符号無し10進
        beq     on_unsigned
        cmp     v1, #'$'            @ ?$ 16進2桁
        beq     on_hex2
        cmp     v1, #'#'            @ ?# 16進4桁
        beq     on_hex4
        cmp     v1, #'?'            @ ?? 16進8桁
        beq     on_hex8
        mov     r3, v1
        bl      Exp
        and     r1, r0, #0xff       @ 表示桁数(MAX255)設定
        bl      SkipEqualExp        @ 1文字を読み飛ばした後 式の評価
        cmp     r3, #'{'            @ ?{ 8進数
        beq     on_oct
        cmp     r3, #'!'            @ ?! 2進nビット
        beq     on_bin
        cmp     r3, #'('            @ ?( print right
        beq     on_dec_right
        cmp     r3, #'['            @ ?[ print right
        beq     on_dec_right0
        b       pop_and_Error       @ スタック補正後 SyntaxError

    on_unsigned:
        bl      SkipEqualExp        @ 1文字を読み飛ばした後 式の評価
        bl      PrintLeftU
        ldmfd   sp!, {pc}
    on_hex2:
        bl      SkipEqualExp        @ 1文字を読み飛ばした後 式の評価
        bl      PrintHex2
        ldmfd   sp!, {pc}
    on_hex4:
        bl      SkipEqualExp        @ 1文字を読み飛ばした後 式の評価
        bl      PrintHex4
        ldmfd   sp!, {pc}
    on_hex8:
        bl      SkipEqualExp        @ 1文字を読み飛ばした後 式の評価
        bl      PrintHex8
        ldmfd   sp!, {pc}
    on_oct:
        bl      PrintOctal
        ldmfd   sp!, {pc}
    on_bin:
        bl      PrintBinary
        ldmfd   sp!, {pc}
    on_dec_right:
        bl      PrintRight
        ldmfd   sp!, {pc}
    on_dec_right0:
        bl      PrintRight0
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ 文字出力 $
@-------------------------------------------------------------------------
Com_OutChar:
        stmfd   sp!, {lr}
        bl      GetChar             @ get next
        cmp     v1, #'='
        beq     1f
        cmp     v1, #'$'            @ $$ 2byte
        beq     2f
        cmp     v1, #'#'            @ $# 4byte
        beq     4f
        cmp     v1, #'*'            @ $*=StrPtr
        beq     6f
        ldmfd   sp!, {pc}

    1:  bl      Exp                 @ 1バイト文字
        b       3f

    2:  bl      SkipEqualExp        @ 2バイト文字
        and     r1, r0, #0x00ff
        and     r2, r0, #0xff00
        mov     r0, r2, LSR #8      @ 上位バイトが先
        bl      OutChar
        mov     r0, r1
    3:  bl      OutChar
        ldmfd   sp!, {pc}

    4:  bl      SkipEqualExp        @ 4バイト文字
        mov     r1, r0
        mov     r2, #4
    5:  mov     r1, r1, ROR #24     @ = ROL #8
        and     r0, r1, #0xFF
        bl      OutChar
        subs    r2, r2, #1
        bne     5b
        ldmfd   sp!, {pc}

    6:  bl      SkipEqualExp
        bl      OutAsciiZ
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ 空白出力 .=n
@-------------------------------------------------------------------------
Com_Space:
        stmfd   sp!, {lr}
        bl      SkipEqualExp        @ 1文字を読み飛ばした後 式の評価
        mov     r1, r0
        mov     r0, #' '
    1:  bl      OutChar
        subs    r1, r1, #1
        bne     1b
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ 改行出力 /
@-------------------------------------------------------------------------
Com_NewLine:
        stmfd   sp!, {lr}
        bl      NewLine
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ 文字列出力 "
@-------------------------------------------------------------------------
Com_String:
        stmfd   sp!, {lr}
        mov     r1, #0
        mov     r0, v3
    1:  bl      GetChar
        cmp     v1, #'"'
        beq     2f
        cmp     v5, #1              @ EOL=yes ?
        beq     2f
        add     r1, r1, #1
        b       1b
    2:
        bl      OutString
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ GOTO #
@-------------------------------------------------------------------------
Com_GO:
        stmfd   sp!, {lr}
        bl      GetChar
        cmp     v1, #'!'
        beq     2f                  @ #! はコメント、次行移動
.ifdef VTL_LABEL
        bl      ClearLabel
.endif
        bl      SkipEqualExp2       @ = をチェックした後 式の評価
Com_GO_go:
        ldrb    r1, [fp, #-3]       @ ExecMode=Direct ?
        cmp     r1, #0
        beq     4f                  @ Directならラベル処理へ

.ifdef VTL_LABEL
        mov     r1, #'^'            @ システム変数「^」の
        ldr     r2, [fp, r1,LSL #2] @ チェック
        tst     r2, r2              @ 式中でラベル参照があるか?
        beq     1f                  @ 無い場合は行番号
        mov     v2, r0              @ v2 を指定行の先頭アドレスへ
        mov     r0, #0              @ システム変数「^」クリア
        str     r0, [fp, r1,LSL #2] @ ラベル無効化
        b       6f                  @ check
.endif

    1: @ 行番号
        tst     r0, r0              @ #=0 なら次行
        bne     3f                  @ 行番号にジャンプ
    2: @ nextline
        mov     v5, #1              @ 次行に移動  EOL=yes
        ldmfd   sp!, {pc}

    3: @ ジャンプ先行番号を検索
        ldr     r1, [v2, #+4]       @ 現在の行と行番号比較
        cmp     r0, r1
        blo     5f                  @ 先頭から検索
        bl      LineSearch_nextline @ 現在行から検索
        b       6f                  @ check

    4: @ label
.ifdef VTL_LABEL
        bl      LabelScan           @ ラベルテーブル作成
.endif

    5: @ top:
        bl      LineSearch          @ v2 を指定行の先頭へ
    6: @ check:
        ldr     r0, [v2]            @ コード末チェック
        adds    r0, r0, #1
        beq     7f                  @ stop
        mov     r0, #1
        strb    r0, [fp, #-3]       @ ExecMode=Memory
        bl      SetLineNo           @ 行番号を # に設定
        add     v3, v2, #8          @ 次行先頭
        mov     v5, #0              @ EOL=no
        ldmfd   sp!, {pc}
    7: @ stop:
        bl      CheckCGI            @ CGIモードなら終了
        bl      WarmInit1           @ 入力デバイス変更なし
        ldmfd   sp!, {pc}

.ifdef VTL_LABEL
@-------------------------------------------------------------------------
@ 式中でのラベル参照結果をクリア
@-------------------------------------------------------------------------
ClearLabel:
        mov     r1, #'^'            @
        mov     r0, #0              @ システム変数「^」クリア
        str     r0, [fp, r1,LSL #2] @ ラベル無効化
        mov     pc, lr

@-------------------------------------------------------------------------
@ コードをスキャンしてラベルとラベルの次の行アドレスをテーブルに登録
@ ラベルテーブルは16バイト／エントリで4096個(64KB)
@ 12バイトのASCIIZ(11バイトのラベル文字) + 4バイト(行先頭アドレス)
@ r0-r3保存, v1,v2 使用
@-------------------------------------------------------------------------
LabelScan:
        stmfd   sp!, {r0-r3, lr}
        mov     r1, #'='
        ldr     v2, [fp, r1,LSL #2] @ コード先頭アドレス
        ldr     v1, [v2]            @ コード末なら終了
        adds    v1, v1, #1
        bne     1f                  @ コード末でない
        ldmfd   sp!, {r0-r3, pc}    @ コードが空
    1:
        ldr     r3, LabelTable      @ ラベルテーブル先頭
        ldr     r0, TablePointer
        str     r3, [r0]            @ 登録する位置格納

    2:
        mov     r1, #8              @ テキスト先頭位置
    3:                              @ 空白をスキップ
        ldrb    v1, [v2, r1]        @ 1文字取得
        cmp     v1, #0
        beq     7f                  @ 行末なら次行
        cmp     v1, #' '            @ 空白読み飛ばし
        bne     4f                  @ ラベル登録へ
        add     r1, r1, #1
        b       3b

    4: @ nextch
        cmp     v1, #'^'            @ ラベル?
        bne     7f                  @ ラベルでなければ
       @ ラベルを登録
        add     r1, r1, #1          @ ラベル文字先頭
        mov     r2, #0              @ ラベル長
    5:
        ldrb    v1, [v2, r1]        @ 1文字取得
        cmp     v1, #0
        beq     6f                  @ 行末
        cmp     v1, #' '            @ ラベルの区切りは空白
        beq     6f                  @ ラベル文字列
        cmp     r2, #11             @ 最大11文字まで
        beq     6f                  @ 文字数
        strb    v1, [r3, r2]        @ 1文字登録
        add     r1, r1, #1
        add     r2, r2, #1
        b       5b                  @ 次の文字

    6: @ registerd
        mov     v1, #0
        strb    v1, [r3, r2]        @ ラベル文字列末
        ldr     v1, [v2]            @ 次行オフセット
        add     v1, v2, v1          @ v1に次行先頭
        str     v1, [r3, #12]       @ アドレス登録
        add     r3, r3, #16
        mov     v2, v1
        str     r3, [r0]            @ 次に登録する位置(TablePointer)

    7:                              @ 次行処理
        ldr     v1, [v2]            @ 次行オフセット
        add     v2, v2, v1          @ v1に次行先頭
        ldr     v1, [v2]            @ 次行オフセット
        adds    v1, v1, #1
        beq     8f                  @ スキャン終了
        cmp     r3, r0              @ テーブル最終位置
        beq     8f                  @ スキャン終了
        b       2b                  @ 次行の処理を繰り返し

    8: @ finish:
        ldmfd   sp!, {r0-r3, pc}

@-------------------------------------------------------------------------
@ テーブルからラベルの次の行アドレスを取得
@ ラベルの次の行の先頭アドレスを r1 と「^」に設定、v1に次の文字を設定
@ して返る。Factorから v3 を^の次に設定して呼ばれる
@ v3 はラベルの後ろ(長すぎる場合は読み飛ばして)に設定される
@ r0, r2, r3, ip は破壊
@-------------------------------------------------------------------------
LabelSearch:
        stmfd   sp!, {lr}
        ldr     r3, LabelTable      @ ラベルテーブル先頭
        ldr     r0, TablePointer
        ldr     r1, [r0]            @ テーブル最終登録位置

    1:
        mov     r2, #0              @ ラベル長
    2:
        ldrb    v1, [v3, r2]        @ ソース
        ldrb    ip, [r3, r2]        @ テーブルと比較
        tst     ip, ip              @ テーブル文字列の最後?
        bne     3f                  @ 比較を継続
        bl      IsAlphaNum
        bcs     4f                  @ v1=space, ip=0

    3:  @ 異なる
        cmp     v1, ip              @ 比較
        bne     5f                  @ 一致しない場合は次のラベル
        add     r2, r2, #1          @ 一致したら次の文字
        cmp     r2, #11             @ 長さのチェック
        bne     2b                  @ 次の文字を比較
        bl      Skip_excess         @ 長過ぎるラベルは後ろを読み飛ばし

    4:  @ found
        ldr     r1, [r3, #12]       @ テーブルからアドレス取得
        mov     r0, #'^'            @ システム変数「^」に
        str     r1, [fp, r0,LSL #2] @ ラベルの次行先頭を設定
        add     v3, v3, r2
        bl      GetChar
        msr     cpsr_f, #0x00000000 @ 見つかればキャリークリア
        ldmfd   sp!, {pc}

    5:  @ next
        add     r3, r3, #16
        cmp     r3, r1              @ テーブルの最終エントリ
        beq     6f                  @ 見つからない場合
        cmp     r3, r0              @ テーブル領域最終?
        beq     6f                  @
        b       1b                  @ 次のテーブルエントリ

    6:  @ not found:
        mov     r2, #0
        bl      Skip_excess         @ ラベルを空白か行末まで読飛ばし
@        mvn     r1, #0x00000000     @ r1 に-1を返す
        mov     r1, #0
        msr     cpsr_f, #0x20000000 @ なければキャリーセット
        ldmfd   sp!, {pc}

Skip_excess:
        stmfd   sp!, {lr}
    1:  ldrb    v1, [v3, r2]        @ 長過ぎるラベルはスキップ
        bl      IsAlphaNum
        bcs     2f                  @ 英数字以外
        add     r2, r2, #1          @ ソース行内の読み込み位置更新
        b       1b
    2:  ldmfd   sp!, {pc}

.endif

@-------------------------------------------------------------------------
@ = コード先頭アドレスを再設定
@-------------------------------------------------------------------------
Com_Top:
        stmfd   sp!, {lr}
        bl      SkipEqualExp        @ = を読み飛ばした後 式の評価
        mov     r3, r0
        bl      RangeCheck          @ ',' <= '=' < '*'
        blo     4f                  @ 範囲外エラー
        mov     r1, #'='            @ コード先頭
        str     r3, [fp, r1,LSL #2] @ 式の値を=に設定 ==r3
        mov     r1, #'*'            @ メモリ末
        ldr     r2, [fp, r1,LSL #2] @ r2=*
    1: @ nextline:                  @ コード末検索
        ldr     r0, [r3]            @ 次行へのオフセット
        adds    r1, r0, #1          @ 行先頭が -1 ?
        beq     2f                  @ yes
        tst     r0, r0
        ble     3f                  @ 次行へのオフセット <= 0 不正
        ldr     r1, [r3, #4]        @ 行番号 > 0
        tst     r1, r1
        ble     3f                  @ 行番号 <= 0 不正
        add     r3, r3, r0          @ 次行先頭アドレス
        cmp     r2, r3              @ 次行先頭 > メモリ末
        ble     3f                  @
        b       1b                  @ 次行処理
    2: @ found:
        mov     r2, r0              @ コード末発見
        b       Com_NEW_set_end     @ & 再設定
    3: @ endmark_err:
        adr     r0, EndMark_msg     @ プログラム未入力
        bl      OutAsciiZ
        bl      WarmInit            @
        ldmfd   sp!, {pc}

    4: @ range_err
        bl      RangeError
        ldmfd   sp!, {pc}

EndMark_msg:
        .asciz   "\n&=0 required.\n"
        .align   2

@-------------------------------------------------------------------------
@ コード末マークと空きメモリ先頭を設定 &
@   = (コード領域の先頭)からの相対値で指定, 絶対アドレスが設定される
@-------------------------------------------------------------------------
Com_NEW:
        stmfd   sp!, {lr}
        bl      SkipEqualExp        @ = を読み飛ばした後 式の評価
        mov     r1, #'='            @ コード先頭
        ldr     r2, [fp, r1,LSL #2] @ &==+4
        mvn     r0, #0              @ コード末マーク(-1)
        str     r0, [r2]            @ コード末マーク
Com_NEW_set_end:
        add     r2, r2, #4          @ コード末の次
        mov     r1, #'&'            @ 空きメモリ先頭
        str     r2, [fp, r1,LSL #2] @
        bl      WarmInit1           @ 入力デバイス変更なし
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ BRK *
@    メモリ最終位置を設定, brk
@-------------------------------------------------------------------------
Com_BRK:
        stmfd   sp!, {r7, lr}
        bl      SkipEqualExp        @ = を読み飛ばした後 式の評価
        mov     r7, #sys_brk        @ メモリ確保
        swi     0
        mov     r1, #'*'            @ ヒープ先頭
        str     r0, [fp, r1,LSL #2]
        ldmfd   sp!, {r7, pc}

@-------------------------------------------------------------------------
@ RANDOM '
@    乱数設定 /dev/urandom から必要バイト数読み出し
@    /usr/src/linux/drivers/char/random.c 参照
@-------------------------------------------------------------------------
Com_RANDOM:
        stmfd   sp!, {lr}
        bl      SkipEqualExp        @ = を読み飛ばした後 式の評価
        mov     r1, #'`'            @ 乱数シード設定
        str     r0, [fp, r1,LSL #2]
        bl      sgenrand
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ 範囲チェックフラグ [
@-------------------------------------------------------------------------
Com_RCheck:
        stmfd   sp!, {lr}
        bl      SkipEqualExp        @ = を読み飛ばした後 式の評価
        mov     r1, #'['            @ 範囲チェック
        str     r0, [fp, r1,LSL #2]
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ 変数または式をスタックに保存
@-------------------------------------------------------------------------
Com_VarPush:
        stmfd   sp!, {lr}
        ldr     r2, [fp, #-16]      @ VSTACK
        mov     r3, #VSTACKMAX
        sub     r3, r3, #1          @ r3 = VSTACKMAX - 1
    1: @ next
        cmp     r2, r3
        bhi     VarStackError_over
        bl      GetChar
        cmp     v1, #'='            @ +=式
        bne     2f
        bl      Exp
        add     r1, fp, #1024       @ [fp+r2*4+1024]
        str     r0, [r1, r2,LSL #2] @ 変数スタックに式を保存
        add     r2, r2, #1
        b       3f
    2: @ push2
        cmp     v1, #' '
        beq     3f
        cmp     v5 , #1             @ EOL=yes?
        beq     3f
        ldr     r0, [fp, v1,LSL #2] @ 変数の値取得
        add     r1, fp, #1024       @ [fp+r2*4+1024]
        str     r0, [r1, r2,LSL #2] @ 変数スタックに式を保存
        add     r2, r2, #1
        b       1b                  @ 次の変数
    3: @ exit
        str     r2, [fp, #-16]      @ スタックポインタ更新
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ 変数をスタックから復帰
@-------------------------------------------------------------------------
Com_VarPop:
        stmfd   sp!, {lr}
        ldr     r2, [fp, #-16]      @ VSTACK
    1: @ next:
        bl      GetChar
        cmp     v1, #' '
        beq     2f
        cmp     v5 , #1             @ EOL=yes?
        beq     2f
        subs    r2, r2, #1
        bmi     VarStackError_under
        add     r1, fp, #1024       @ [fp+r2*4+1024]
        ldr     r0, [r1, r2,LSL #2] @ 変数スタックから復帰
        str     r0, [fp, v1,LSL #2] @ 変数に値設定
        b       1b
    2: @ exit:
        str     r2, [fp, #-16]      @ スタックポインタ更新
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ ファイル格納域先頭を指定 v4使用
@-------------------------------------------------------------------------
Com_FileTop:
        stmfd   sp!, {lr}
        bl      SkipEqualExp        @ = を読み飛ばした後 式の評価
        mov     v4, r0
        bl      RangeCheck          @ 範囲チェック
        bcs     1f                  @ Com_FileEnd:1 範囲外をアクセス
        mov     r1, #'{'            @ ファイル格納域先頭
        str     r0, [fp, r1,LSL #2]
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ ファイル格納域最終を指定 v4使用
@-------------------------------------------------------------------------
Com_FileEnd:
        stmfd   sp!, {lr}
        bl      SkipEqualExp        @ = を読み飛ばした後 式の評価
        mov     v4, r0
        bl      RangeCheck          @ 範囲チェック
        bcs     1f                  @ 範囲外をアクセス
        mov     r1, #'}'            @ ファイル格納域先頭
        str     r0, [fp, r1,LSL #2]
        ldmfd   sp!, {pc}
    1: @ range_err
        bl      RangeError
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ CodeWrite <=
@-------------------------------------------------------------------------
Com_CdWrite:
        stmfd   sp!, {r7, lr}
        bl      GetFileName
        bl      fwopen              @ open
        beq     4f                  @ exit
        bmi     5f                  @ error
        str     r0, [fp, #-12]      @ FileDescW
        mov     r1, #'='
        ldr     r3, [fp, r1,LSL #2] @ コード先頭アドレス
        stmfd   sp!, {v3}

    1: @ loop
        ldr     v3, input2          @ ワークエリア(行)
        ldr     r0, [r3]            @ 次行へのオフセット
        adds    r0, r0, #1          @ コード最終か?
        beq     4f                  @ 最終なら終了
        ldr     r0, [r3, #4]        @ 行番号取得
        bl      PutDecimal          @ r0の行番号をv3に書き込み
        mov     r0, #' '            @ スペース書込み
        strb    r0, [v3], #1        @ Write One Char
        mov     r1, #8
    2: @ code:
        ldrb    r0, [r3, r1]        @ コード部分書き込み
        cmp     r0, #0              @ 行末か?
        beq     3f                  @ file出力後次行
        strb    r0, [v3], #1        @ Write One Char
        add     r1, r1, #1
        b       2b

    3: @ next:
        ldr     r1, [r3]            @ 次行オフセット
        add     r3, r3, r1          @ 次行先頭へ
        mov     r0, #10
        strb    r0, [v3], #1        @ 改行書込み
        mov     r0, #0
        strb    r0, [v3]            @ EOL

        ldr     r0, input2          @ バッファアドレス
        bl      StrLen              @ r0の文字列長をr1に返す
        mov     r2, r1              @ 書きこみバイト数
        mov     r1, r0              @ バッファアドレス
        ldr     r0, [fp, #-12]      @ FileDescW
        mov     r7, #sys_write      @ システムコール
        swi     0
        b       1b                  @ 次行処理
    4: @ exit:
        ldmfd   sp!, {v3}
        ldr     r0, [fp, #-12]      @ FileDescW
        bl      fclose              @ ファイルクローズ
        mov     v5, #1              @ EOL=yes
        ldmfd   sp!, {r7, pc}

    5: @ error:
        b       pop_and_Error

@-------------------------------------------------------------------------
@ CodeRead >=
@-------------------------------------------------------------------------
Com_CdRead:
        stmfd   sp!, {lr}
        ldrb    r0, [fp, #-4]
        cmp     r0, #1              @ Read from file
        beq     2f
        bl      GetFileName
        bl      fropen              @ open
        beq     1f
        bmi     SYS_Error
        str     r0, [fp, #-8]       @ FileDesc
        mov     r1, #1
        strb    r1, [fp, #-4]       @ Read from file
        mov     v5, r1              @ EOL
    1: @ exit
        ldmfd   sp!, {pc}
    2: @ error
        adr     r0, error_cdread
        bl      OutAsciiZ
        b       SYS_Error_return

error_cdread:   .asciz   "\nCode Read (>=) is not allowed!\n"
                .align   2

@-------------------------------------------------------------------------
@ 未定義コマンド処理(エラーストップ)
@-------------------------------------------------------------------------
pop_and_SYS_Error:
        add     sp, sp, #4          @ スタック修正
SYS_Error:
        bl      CheckError
SYS_Error_return:
        add     sp, sp, #4          @ スタック修正
        bl      WarmInit
        b       MainLoop

@-------------------------------------------------------------------------
@ システムコールエラーチェック
@-------------------------------------------------------------------------
CheckError:
        stmfd   sp!, {r0-r2,lr}
        mrs     r2, cpsr
        mov     r1, #'|'            @ 返り値を | に設定
        str     r0, [fp, r1,LSL #2]
.ifdef  DETAILED_MSG
        bl      SysCallError
.else
        tst     r0, r0
        bpl     1f
        adr     r0, Error_msg
        bl      OutAsciiZ
.endif
        msr     cpsr_f, r2
    1:  ldmfd   sp!, {r0-r2, pc}

Error_msg:      .asciz   "\nError!\n"
                .align   2

@-------------------------------------------------------------------------
@ FileWrite (=
@-------------------------------------------------------------------------
Com_FileWrite:
        stmfd   sp!, {r7, lr}
        ldrb    v1, [v3]            @ check (*=\0
        cmp     v1, #'*
        bne     1f
        bl      GetChar
        bl      GetChar
        cmp     v1, #'='
        bne     pop_and_Error
        bl      Exp                 @ Get argument
        b       2f                  @ open

    1:  bl      GetFileName
    2:  bl      fwopen              @ open
        beq     3f
        bmi     SYS_Error
        str     r0, [fp, #-12]      @ FileDescW

        mov     r2, #'{'            @ 格納領域先頭
        ldr     r1, [fp, r2,LSL #2] @ バッファ指定
        mov     r2, #'}'            @ 格納領域最終
        ldr     r3, [fp, r2,LSL #2] @
        cmp     r3, r1
        blo     3f
        sub     r2, r3, r1          @ 書き込みサイズ
        ldr     r0, [fp, #-12]      @ FileDescW
        mov     r7, #sys_write      @ システムコール
        swi     0
        bl      fclose
    3: @ exit:
        ldmfd   sp!, {r7, pc}

@-------------------------------------------------------------------------
@ FileRead )=
@-------------------------------------------------------------------------
Com_FileRead:
        stmfd   sp!, {r7, lr}
        ldrb    v1, [v3]            @ check )*=\0
        cmp     v1, #'*
        bne     1f
        bl      GetChar
        bl      GetChar
        cmp     v1, #'='
        bne     pop_and_Error
        bl      Exp                 @ Get argument
        b       2f                  @ open

    1:  bl      GetFileName
    2:  bl      fropen              @ open
        beq     3f
        bmi     SYS_Error
        str     r0, [fp, #-12]      @ 第１引数 : fd
        mov     r1, #0              @ 第２引数 : offset = 0
        mov     r2, #SEEK_END       @ 第３引数 : origin
        mov     r7, #sys_lseek      @ ファイルサイズを取得
        swi     0

        mov     r3, r0              @ file_size 退避
        ldr     r0, [fp, #-12]      @ 第１引数 : fd
        mov     r1, #0              @ 第２引数 : offset=0
        mov     r2, r1              @ 第３引数 : origin=0
        mov     r7, #sys_lseek      @ ファイル先頭にシーク
        swi     0

        mov     r0, #'{'            @ 格納領域先頭
        ldr     r1, [fp, r0,LSL #2] @ バッファ指定
        mov     r0, #')'
        str     r3, [fp, r0,LSL #2] @ 読み込みサイズ設定
        add     r2, r1, r3          @ 最終アドレス計算
        mov     r0, #'}'
        str     r2, [fp, r0,LSL #2] @ 格納領域最終設定
        mov     r0, #'*'
        ldr     r3, [fp, r0,LSL #2] @ RAM末
        cmp     r3, r1
        blo     3f                  @ r3<r1 領域不足エラー

        ldr     r0, [fp, #-12]      @ FileDescW
        mov     r7, #sys_read       @ ファイル全体を読みこみ
        swi     0
        mov     r2, r0
        ldr     r0, [fp, #-12]      @ FileDescW
        bl      fclose
        tst     r2, r2              @ Read Error
        bmi     SYS_Error
    3: @ exit
        ldmfd   sp!, {r7, pc}

@-------------------------------------------------------------------------
@
@-------------------------------------------------------------------------
@==============================================================
                .align   2
ipipe:          .long   ipipe0
opipe:          .long   opipe0
ipipe2:         .long   ipipe20
opipe2:         .long   opipe20

input2:         .long   input20
pid:            .long   pid0
FOR_direct:     .long   FOR_direct0
ExpError:       .long   ExpError0
ZeroDiv:        .long   ZeroDiv0
SigInt:         .long   SigInt0
VSTACK:         .long   VSTACK0
FileDescW:      .long   FileDescW0
FileDesc:       .long   FileDesc0
ReadFrom:       .long   ReadFrom0
ExecMode:       .long   ExecMode0
EOL:            .long   EOL0
LSTACK:         .long   LSTACK0
VarStack:       .long   VarStack0

.ifdef VTL_LABEL
LabelTable:     .long   LabelTable0
TablePointer:   .long   TablePointer0
.endif


@-------------------------------------------------------------------------
@ 終了
@-------------------------------------------------------------------------
Com_Exit:       @   7E  ~  VTL終了
                bl      RESTORE_TERMIOS
                b       Exit

@-------------------------------------------------------------------------
@ ユーザ拡張コマンド処理
@-------------------------------------------------------------------------
Com_Ext:
        stmfd   sp!, {lr}
.ifndef SMALL_VTL
.include        "ext.s"
func_err:
@        b       pop_and_Error
.endif
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ ForkExec , 外部プログラムの実行
@-------------------------------------------------------------------------
Com_Exec:
.ifndef SMALL_VTL
        stmfd   sp!, {lr}
        bl      GetChar             @ skip =
        cmp     v1, #'*
        bne     0f
        bl      SkipEqualExp
        bl      GetString2
        b       3f
    0:  bl      GetChar             @ skip "
        cmp     v1, #'"'
        subne   v3, v3, #1          @ ungetc 1文字戻す
    1:
        bl      GetString           @ 外部プログラム名取得
        ldr     r0, FileName2       @ ファイル名表示
        @ bl      OutAsciiZ
        bl      NewLine

    3:  stmfd   sp!, {v1-v4}
        bl      ParseArg            @ コマンド行の解析
        mov     v2, r1              @ リダイレクト先ファイル名
        add     r3, r3, #1          @ 子プロセスの数
        ldr     r2, exarg2          @ char ** argp
        mov     v4, #0              @ 先頭プロセス
        cmp     r3, #1
        bhi     2f                  @ パイプが必要

        @ パイプ不要の場合
        stmfd   sp!, {r7}           @ save v4
        mov     r7, #sys_fork       @ システムコール
        swi     0
        ldmfd   sp!, {r7}           @ restore v4
        tst     r0, r0
        beq     child               @ pid が 0 なら子プロセス
        b       6f

    2:  @ パイプが必要
        stmfd   sp!, {r7}           @ save v4
        ldr     v3, ipipe           @ パイプをオープン
        mov     r0, v3              @ v3 に pipe_fd 配列先頭
        mov     r7, #sys_pipe       @ pipe システムコール
        swi     0

        @------------------------------------------------------------
        @ fork
        @------------------------------------------------------------
        mov     r7, #sys_fork       @ システムコール
        swi     0
        ldmfd   sp!, {r7}           @ restore v4
        tst     r0, r0
        beq     child               @ pid が 0 なら子プロセス

        @------------------------------------------------------------
        @ 親プロセス側の処理
        @------------------------------------------------------------
        tst     v4, v4              @ 先頭プロセスか?
        blne    close_old_pipe      @ 先頭でなければパイプクローズ
        ldr     ip, [v3]            @ パイプ fd の移動
        str     ip, [v3, #+8]
        ldr     ip, [v3, #+4]
        str     ip, [v3, #+12]
        subs    r3, r3, #1          @ 残り子プロセスの数
        beq     5f                  @ 終了

    4:  add     r2, r2, #4          @ 次のコマンド文字列探索
        ldr     ip, [r2]
        cmp     ip, #0              @ コマンド区切りを探す
        bne     4b
        add     r2, r2, #4          @ 次のコマンド文字列設定
        add     v4, v4, #1          @ 次は先頭プロセスではない
        b       2b

    5:  bl      close_new_pipe
    6:  @ 終了を待つ r0=最後に起動した子プロセスpid
        ldr     r1, stat_addr
        mov     r2, #WUNTRACED      @ WNOHANG
        ldr     r3, ru              @ rusage
        stmfd   sp!, {r7}           @ save v4
        mov     r7, #sys_wait4      @ システムコール
        swi     0
        ldmfd   sp!, {r7}
        bl      SET_TERMIOS         @ 子プロセスの設定を復帰
        ldmfd   sp!, {v1-v4}
        ldmfd   sp!, {pc}

        @------------------------------------------------------------
        @ 子プロセス側の処理、 execveを実行して戻らない
        @------------------------------------------------------------
child:
        bl      RESTORE_TERMIOS
        subs    r3, r3, #1          @ 最終プロセスチェック
        bne     pipe_out            @ 最終プロセスでない
        tst     v2, v2              @ リダイレクトがあるか
        beq     pipe_in             @ リダイレクト無し, 標準出力
        mov     r0, v2              @ リダイレクト先ファイル名
        bl      fwopen              @ r0 = オープンした fd
        mov     ip, r0
        mov     r1, #1              @ 標準出力をファイルに差替え
        mov     r7, #sys_dup2       @ dup2 システムコール
        swi     0
        mov     r0, ip
        bl      fclose              @ r0 にはオープンしたfd
        b       pipe_in

pipe_out:                           @ 標準出力をパイプに
        ldr     r0, [v3, #+4]       @ 新パイプの書込み fd
        mov     r1, #1              @ 標準出力
        mov     r7, #sys_dup2       @ dup2 システムコール
        swi     0
        bl      close_new_pipe

pipe_in:
        tst     v4, v4              @ 先頭プロセスならスキップ
        beq     execve
                                    @ 標準入力をパイプに
        ldr     r0, [v3, #+8]       @ 前のパイプの読出し fd
        mov     r1, #0              @ new_fd 標準入力
        mov     r7, #sys_dup2       @ dup2 システムコール
        swi     0
        bl      close_old_pipe

execve:
        ldr     r0, [r2]            @ char * filename exarg[0]
        mov     r1, r2              @ char **argp     exarg[1]
        ldr     r2, exarg2          @
        ldr     r2, [r2, #-12]      @ char ** envp
        mov     r7, #sys_execve     @ システムコール
        swi     0
        bl      CheckError          @ 正常ならここには戻らない
        bl      Exit                @ 単なる飾り

close_new_pipe:
        stmfd   sp!, {r0, lr}
        ldr     r0, [v3, #+4]       @ 出力パイプをクローズ
        bl      fclose
        ldr     r0, [v3]            @ 入力パイプをクローズ
        bl      fclose
        ldmfd   sp!, {r0, pc}

close_old_pipe:
        stmfd   sp!, {r0, lr}
        ldr     r0, [v3, #+12]      @ 出力パイプをクローズ
        bl      fclose
        ldr     r0, [v3, #+8]       @ 入力パイプをクローズ
        bl      fclose
        ldmfd   sp!, {r0, pc}
.endif

FileName2:      .long   FileName0
exarg2:         .long   exarg0
ru:             .long   ru0
stat_addr:      .long   stat_addr0

@-------------------------------------------------------------------------
@ execve 用の引数を設定
@ コマンド文字列のバッファ FileName をAsciiZに変換してポインタの配列に設定
@ r3 に パイプの数 (子プロセス数-1) を返す．
@ r1 にリダイレクト先ファイル名文字列へのポインタを返す．
@-------------------------------------------------------------------------
ParseArg:
        stmfd   sp!, {v2, v3, lr}
        mov     r2, #0              @ 配列インデックス
        mov     r3, #0              @ パイプのカウンタ
        mov     r1, #0              @ リダイレクトフラグ
        ldr     v3, FileName2       @ コマンド文字列のバッファ
        ldr     v2, exarg2          @ ポインタの配列先頭
    1:
        ldrb    r0, [v3]            @ 連続する空白のスキップ
        tst     r0, r0              @ 行末チェック
        beq     pa_exit
        cmp     r0, #' '
        bne     2f                  @ パイプのチェック
        add     v3, v3, #1          @ 空白なら次の文字
        b       1b

    2:  cmp     r0, #'|'            @ パイプ?
        bne     3f
        add     r3, r3, #1          @ パイプのカウンタ+1
        bl      end_mark            @ null pointer書込み
        b       6f

    3:  cmp     r0, #'>'            @ リダイレクト?
        bne     4f
        mov     r1, #1              @ リダイレクトフラグ
        bl      end_mark            @ null pointer書込み
        b       6f

    4:  str     v3, [v2, r2,LSL #2] @ 引数へのポインタを登録
        add     r2, r2, #1          @ 配列インデックス+1

    5:  ldrb    r0, [v3]            @ 空白を探す
        tst     r0, r0              @ 行末チェック
        beq     7f                  @ 行末なら終了
        cmp     r0, #' '
        addne   v3, v3, #1
        bne     5b                  @ 空白でなければ次の文字
        mov     r0, #0
        strb    r0, [v3]            @ スペースを 0 に置換
        tst     r1, r1              @ リダイレクトフラグ
        bne     7f                  @ > の後ろはファイル名のみ

    6:  add     v3, v3, #1
        cmp     r2, #ARGMAX         @ 個数チェックして次
        bhs     pa_exit
        b       1b

    7:  tst     r1, r1              @ リダイレクトフラグ
        beq     pa_exit
        sub     r2, r2, #1
        ldr     r1, [v2, r2,LSL #2]
        add     r2, r2, #1
pa_exit:
        mov     r0, #0
        str     r0, [v2, r2,LSL #2] @ 引数ポインタ配列の最後
        ldmfd   sp!, {v2, v3, pc}

end_mark:
        mov     r0, #0
        str     r0, [v2, r2,LSL #2] @ コマンドの区切り NullPtr
        add     r2, r2, #1          @ 配列インデックス
        mov     pc, lr

@-------------------------------------------------------------------------
@ 組み込みコマンドの実行
@-------------------------------------------------------------------------
Com_Function:
.ifndef SMALL_VTL
        stmfd   sp!, {lr}
        bl      GetChar             @ | の次の文字
func_c:
        cmp     v1, #'c'
        bne     func_d
        bl      def_func_c          @ |c
        ldmfd   sp!, {pc}
func_d:
func_e:
        cmp     v1, #'e'
        bne     func_f
        bl      def_func_e          @ |e
        ldmfd   sp!, {pc}
func_f:
        cmp     v1, #'f'
        bne     func_l
        bl      def_func_f          @ |f
        ldmfd   sp!, {pc}
func_l:
        cmp     v1, #'l'
        bne     func_m
        bl      def_func_l          @ |l
        ldmfd   sp!, {pc}
func_m:
        cmp     v1, #'m'
        bne     func_n
        bl      def_func_m          @ |m
        ldmfd   sp!, {pc}
func_n:
func_p:
        cmp     v1, #'p'
        bne     func_q
        bl      def_func_p          @ |p
        ldmfd   sp!, {pc}
func_q:
func_r:
        cmp     v1, #'r'
        bne     func_s
        bl      def_func_r          @ |r
        ldmfd   sp!, {pc}
func_s:
        cmp     v1, #'s'
        bne     func_t
        bl      def_func_s          @ |s
        ldmfd   sp!, {pc}
func_t:
func_u:
        cmp     v1, #'u'
        bne     func_v
        bl      def_func_u          @ |u
        ldmfd   sp!, {pc}
func_v:
        cmp     v1, #'v'
        bne     func_z
        bl      def_func_v          @ |u
        ldmfd   sp!, {pc}
func_z:
        cmp     v1, #'z'
        bne     pop_and_Error
        bl      def_func_z          @ |z
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ 組み込み関数用メッセージ
@-------------------------------------------------------------------------
                .align  2
    msg_f_ca:   .asciz  ""
                .align  2
    msg_f_cd:   .asciz  "Change Directory to "
                .align  2
    msg_f_cm:   .asciz  "Change Permission \n"
                .align  2
    msg_f_cr:   .asciz  "Change Root to "
                .align  2
    msg_f_cw:   .asciz  "Current Working Directory : "
                .align  2
    msg_f_ex:   .asciz  "Exec Command\n"
                .align  2
@-------------------------------------------------------------------------

@------------------------------------
@ |c で始まる組み込みコマンド
@------------------------------------
def_func_c:
        stmfd   sp!, {lr}
        bl      GetChar             @
        cmp     v1, #'a'
        beq     func_ca             @ cat
        cmp     v1, #'d'
        beq     func_cd             @ cd
        cmp     v1, #'m'
        beq     func_cm             @ chmod
        cmp     v1, #'r'
        beq     func_cr             @ chroot
        cmp     v1, #'w'
        beq     func_cw             @ pwd
        b       pop2_and_Error
func_ca:
        adr     r0, msg_f_ca        @ |ca file
        bl      FuncBegin
        ldr     r0, [r1]            @ filename
        bl      DispFile
        ldmfd   sp!, {pc}
func_cd:
        adr     r0, msg_f_cd        @ |cd path
        bl      FuncBegin
        ldr     r1, [r1]            @ char ** argp
        ldr     r0, FileName2
        bl      OutAsciiZ
        bl      NewLine
        mov     r7, #sys_chdir      @ システムコール
        swi     0
        bl      CheckError
        ldmfd   sp!, {pc}
func_cm:
        adr     r0, msg_f_cm        @ |cm 644 file
        bl      FuncBegin
        ldr     r0, [r1, #4]        @ file name
        ldr     r1, [r1]            @ permission
        bl      Oct2Bin
        mov     r1, r0
        mov     r7, #sys_chmod      @ システムコール
        swi     0
        bl      CheckError
        ldmfd   sp!, {pc}
func_cr:
        adr     r0, msg_f_cr        @ |cr path
        bl      FuncBegin
        ldr     r1, [r1]            @ char ** argp
        ldr     r0, FileName2
        bl      OutAsciiZ
        bl      NewLine
        mov     r7, #sys_chroot     @ システムコール
        swi     0
        bl      CheckError
        ldmfd   sp!, {pc}
func_cw:
        adr     r0, msg_f_cw        @ |cw
        bl      OutAsciiZ
        ldr     r0, FileName2
        mov     r3, r0              @ save r0
        mov     r1, #FNAMEMAX
        mov     r7, #sys_getcwd     @ システムコール
        swi     0
        bl      CheckError
        mov     r0, r3              @ restore r0
        bl      OutAsciiZ
        bl      NewLine
        ldmfd   sp!, {pc}

@------------------------------------
@ |e で始まる組み込みコマンド
@------------------------------------
def_func_e:
        stmfd   sp!, {lr}
        bl      GetChar             @
        cmp     v1, #'x'
        beq     func_ex             @ execve
        b       pop2_and_Error
func_ex:
        adr     r0, msg_f_ex        @ |ex file arg ..
        bl      RESTORE_TERMIOS     @ 端末設定を戻す
        bl      FuncBegin           @ r1: char ** argp
        ldr     r0, [r1]            @ char * filename
        ldr     r2, exarg2          @
        ldr     r2, [r2, #-12]      @ char ** envp
        mov     r7, #sys_execve     @ システムコール
        swi     0
        bl      CheckError          @ 正常ならここには戻らない
        bl      SET_TERMIOS         @ 端末のローカルエコーをOFF
        ldmfd   sp!, {pc}

@------------------------------------
@ |f で始まる組み込みコマンド
@------------------------------------
def_func_f:
.ifdef FRAME_BUFFER
.include        "vtlfb.s"
.endif

@------------------------------------
@ |l で始まる組み込みコマンド
@------------------------------------
def_func_l:
        stmfd   sp!, {lr}
        bl      GetChar             @
        cmp     v1, #'s'
        beq     func_ls            @ ls
        b       pop2_and_Error

func_ls:
        adr     r0, msg_f_ls        @ |ls dir
        bl      FuncBegin
        ldr     r2, [r1]
        tst     r2, r2
        bne     1f
        adrl    r2, current_dir     @ dir 指定なし
    1:  ldr     r3, DirName2
        mov     r0, r3
    2:  ldrb    ip, [r2], #1        @ dir をコピー
        strb    ip, [r3], #1
        tst     ip, ip
        bne     2b
        ldrb    ip, [r3, #-2]       @ dir末の/をチェック
        mov     r2, #'/
        cmp     ip, r2
        beq     3f                  @ / 有
        strb    r2, [r3, #-1]       @ / 書き込み
        mov     r2, #0
        strb    r2, [r3]            @ end mark
    3:
        bl      fropen
        bmi     6f                  @ エラーチェックして終了
        stmfd   sp!, {v1, v2, v6}
        mov     v2, r0              @ fd 保存
        ldr     v6, DirName2        @ for GetFileStat
    4:  @ ディレクトリエントリ取得
        @ unsigned int fd, void * dirent, unsigned int count
        mov     r0, v2              @ fd 再設定
        ldr     r1, dir_ent2        @ バッファ先頭
        mov     v1, r1              @ v1 : struct top (dir_ent)
        ldr     r2, size_dir_ent2
        mov     r7, #sys_getdents   @ システムコール
        swi     0
        tst     r0, r0              @ valid buffer length
        bmi     6f
        beq     7f
        mov     r3, r0              @ r3 : buffer size

    5:  @ dir_entからファイル情報を取得
        mov     r1, v1              @ v1 : dir_ent
        bl      GetFileStat         @ r1:dir_entアドレス
        ldr     r2, file_stat2
        ldrh    r0, [r2, #+8]       @ file_stat.st_mode
        mov     r1, #6
        bl      PrintOctal          @ mode
        ldr     r0, [r2, #+20]      @ file_stat.st_size ?+2?
        mov     r1, #12
        bl      PrintRight          @ file size
        mov     r0, #' '
        bl      OutChar
        add     r0, v1, #10         @ dir_ent.filename
        bl      OutAsciiZ           @ filename
        bl      NewLine
        ldrh    r0, [v1, #+8]       @ record length
        subs    r3, r3, r0          @ バッファの残り
        beq     4b                  @ 次のディレクトリエントリ取得
        add     v1, v1, r0          @ 次のdir_ent
        b       5b

    6:  bl      CheckError
    7:  mov     r0, v2              @ fd
        bl      fclose
        ldmfd   sp!, {v1, v2, v6}
        ldmfd   sp!, {pc}

@ 届かないのでここでも定義
size_dir_ent2:  .long size_dir_ent0
dir_ent2:       .long   dir_ent0        @ 256 bytes
file_stat2:     .long   file_stat0      @ 64 bytes
DirName2:       .long   DirName0

@------------------------------------
@ |m で始まる組み込みコマンド
@------------------------------------
def_func_m:
         stmfd   sp!, {lr}
         bl      GetChar            @
         cmp     v1, #'d'
         beq     func_md            @ mkdir
         cmp     v1, #'o'
         beq     func_mo            @ mo
         cmp     v1, #'v'
         beq     func_mv            @ mv
         b       pop2_and_Error

func_md:
        adr     r0, msg_f_md        @ |md dir [777]
        bl      FuncBegin
        ldr     r0, [r1, #4]        @ permission
        ldr     r1, [r1]            @ directory name
        tst     r0, r0
        ldreq   r0, c755
        beq     2f
        bl      Oct2Bin
        mov     r1, r0
        mov     r7, #sys_mkdir      @ システムコール
        swi     0
        bl      CheckError
        ldmfd   sp!, {pc}

c755:   .long   0755

func_mo:
        adr     r0, msg_f_mo        @ |mo dev_name dir fstype
        bl      FuncBegin
        mov     v2, r1              @ exarg
        ldr     r0, [v2]            @ dev_name
        ldr     r1, [v2, #+4]       @ dir_name
        ldr     r2, [v2, #+8]       @ fstype
        ldr     r3, [v2, #+12]      @ flags
        tst     r3, r3              @ Check ReadOnly
        beq     1f                  @ Read/Write
        ldr     r3, [r3]
        mov     r3, #MS_RDONLY      @ ReadOnly FileSystem
    1:
        mov     r4, #0              @ void * data
        mov     r7, #sys_mount      @ システムコール
        swi     0
        bl      CheckError
        ldmfd   sp!, {pc}
func_mv:
        adr     r0, msg_f_mv        @ |mv fileold filenew
        bl      FuncBegin
        ldr     r0, [r1]
        ldr     r1, [r1, #4]
        mov     r7, #sys_rename     @ システムコール
        swi     0
        bl      CheckError
        ldmfd   sp!, {pc}

@------------------------------------
@ |p で始まる組み込みコマンド
@------------------------------------
def_func_p:
        stmfd   sp!, {lr}
        bl      GetChar             @
        cmp     v1, #'v'
        beq     func_pv             @ pivot_root
        b       pop2_and_Error

func_pv:
        adr     r0, msg_f_pv        @ |pv /dev/hda2 /mnt
        bl      FuncBegin
        ldr     r0, [r1]
        ldr     r1, [r1, #4]
        mov     r7, #sys_pivot_root @ システムコール
        swi     0
        bl      CheckError
        ldmfd   sp!, {pc}

@------------------------------------
@ |r で始まる組み込みコマンド
@------------------------------------
def_func_r:
        stmfd   sp!, {lr}
        bl      GetChar             @
        cmp     v1, #'d'
        beq     func_rd             @ rmdir
        cmp     v1, #'m'
        beq     func_rm             @ rm
        cmp     v1, #'t'
        beq     func_rt             @ rt
        b       pop2_and_Error

func_rd:
        adr     r0, msg_f_rd        @ |rd path
        bl      FuncBegin           @ char ** argp
        ldr     r0, [r1]
        mov     r7, #sys_rmdir      @ システムコール
        swi     0
        bl      CheckError
        ldmfd   sp!, {pc}

func_rm:
        adr     r0, msg_f_rm        @ |rm path
        bl      FuncBegin           @ char ** argp
        ldr     r0, [r1]
        mov     r7, #sys_unlink     @ システムコール
        swi     0
        bl      CheckError
        ldmfd   sp!, {pc}

func_rt:                            @ reset terminal
        adr     r0, msg_f_rt        @ |rt
        bl      OutAsciiZ
        bl      SET_TERMIOS2        @ cooked mode
        bl      GET_TERMIOS         @ termios の保存
        bl      SET_TERMIOS         @ raw mode
        ldmfd   sp!, {pc}

@------------------------------------
@ |s で始まる組み込みコマンド
@------------------------------------
def_func_s:
        stmfd   sp!, {lr}
        bl      GetChar             @
        cmp     v1, #'f'
        beq     func_sf             @ swapoff
        cmp     v1, #'o'
        beq     func_so             @ swapon
        cmp     v1, #'y'
        beq     func_sy             @ sync
        b       pop2_and_Error

func_sf:
        adr     r0, msg_f_sf        @ |sf dev_name
        bl      FuncBegin           @ const char * specialfile
        ldr     r0, [r1]
        mov     r7, #sys_swapoff    @ システムコール
        swi     0
        bl      CheckError
        ldmfd   sp!, {pc}

func_so:
        adr     r0, msg_f_so        @ |so dev_name
        bl      FuncBegin
        ldr     r0, [r1]            @ const char * specialfile
        mov     r1, #0              @ int swap_flags
        mov     r7, #sys_swapon     @ システムコール
        swi     0
        bl      CheckError
        ldmfd   sp!, {pc}

func_sy:
        adr     r0, msg_f_sy        @ |sy
        bl      OutAsciiZ
        mov     r7, #sys_sync       @ システムコール
        swi     0
        bl      CheckError
        ldmfd   sp!, {pc}

@------------------------------------
@ |u で始まる組み込みコマンド
@------------------------------------
def_func_u:
        stmfd   sp!, {lr}
        bl      GetChar             @
        cmp     v1, #'m'
        beq     func_um             @ umount
        cmp     v1, #'d'
        beq     func_ud             @ URL Decode
        b       pop2_and_Error

func_um:
        adr     r0, msg_f_um        @ |um dev_name
        bl      FuncBegin           @
        ldr     r0, [r1]            @ dev_name
        mov     r1, #2              @ MNT_DETACH = 0x00000002
        mov     r7, #sys_umount2    @ sys_umount2 システムコール
        swi     0
        bl      CheckError
        ldmfd   sp!, {pc}

func_ud:
        mov     r0, #'u'
        ldr     ip, [fp, r0,LSL #2] @ 引数は u[0] - u[3]
        ldr     r0, [ip]            @ r0 にURLエンコード文字列の先頭設定
        ldr     r1, [ip, #4]        @ r1 に変更範囲の文字数を設定
        ldr     r2, [ip, #8]        @ r2 にデコード後の文字列先頭を設定
        bl      URL_Decode
        str     r0, [ip, #12]       @ デコード後の文字数を設定
        ldmfd   sp!, {pc}

@------------------------------------
@ |v で始まる組み込みコマンド
@------------------------------------
def_func_v:
        stmfd   sp!, {lr}
        bl      GetChar             @
        cmp     v1, #'e'
        beq     func_ve             @ version
        cmp     v1, #'c'
        beq     func_vc             @ cpu
        b       pop2_and_Error

func_ve:
        ldr     r3, version
        mov     r0, #'%'
        str     r3, [fp, r0,LSL #2] @ 読み込みサイズ設定
        ldmfd   sp!, {pc}

func_vc:
        mov     r3, #CPU
        mov     r0, #'%'
        str     r3, [fp, r0,LSL #2] @ 読み込みサイズ設定
        ldmfd   sp!, {pc}

version:
        .long   VERSION

@------------------------------------
@ |zz システムコール
@------------------------------------
def_func_z:
        stmfd   sp!, {lr}
        bl      GetChar             @
        cmp     v1, #'c'
        beq     func_zc
        cmp     v1, #'z'
        beq     func_zz             @ system bl
        b       pop2_and_Error

func_zc:
        ldr     r0, counter1
        ldr     r3, [r0]
        mov     r0, #'%'
        str     r3, [fp, r0,LSL #2]
        ldmfd   sp!, {pc}

func_zz:
        bl      GetChar             @ skip space
        bl      SystemCall
        bl      CheckError
        ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ 組み込み関数用メッセージ
@-------------------------------------------------------------------------
    msg_f_ls:   .asciz  "List Directory\n"
                .align  2
    msg_f_md:   .asciz  "Make Directory\n"
                .align  2
    msg_f_mv:   .asciz  "Change Name\n"
                .align  2
    msg_f_mo:   .asciz  "Mount\n"
                .align  2
    msg_f_pv:   .asciz  "Pivot Root\n"
                .align  2
    msg_f_rd:   .asciz  "Remove Directory\n"
                .align  2
    msg_f_rm:   .asciz  "Remove File\n"
                .align  2
    msg_f_rt:   .asciz  "Reset Termial\n"
                .align  2
    msg_f_sf:   .asciz  "Swap Off\n"
                .align  2
    msg_f_so:   .asciz  "Swap On\n"
                .align  2
    msg_f_sy:   .asciz  "Sync\n"
                .align  2
    msg_f_um:   .asciz  "Unmount\n"
                .align  2

    counter1:   .long   counter0

@---------------------------------------------------------------------
@ v6 の文字が16進数字かどうかのチェック
@ 数字なら整数に変換して v6 に返す. 非数字ならキャリーセット
@---------------------------------------------------------------------

IsNum2: cmp     v6, #'0'            @ 0 - 9
        bcs     1f
        msr     cpsr_f, #0x20000000 @ set carry v6<'0'
        mov     pc, lr              @ return
    1:  cmp     v6, #':'            @ set carry v6>'9'
        subcc   v6, v6, #'0         @ 整数に変換 Cy=0
        mov     pc, lr              @ return

IsHex:
        stmfd   sp!, {lr}
        bl      IsHex1              @ 英大文字か?
        bcc     1f
        bl      IsHex2              @ 英小文字か?
    1:  addcc   v6, v6, #10
        ldmfd   sp!, {pc}

IsHex1:
        cmp     v6, #'A             @ 英大文字(A-Z)か?
        bcs     1f
        msr     cpsr_f, #0x20000000 @ if v6<'A' Cy=1
        mov     pc, lr              @ return
    1:  cmp     v6, #'F+1           @ if v6>'F' Cy=1
        subcc   v6, v6, #'A         @ yes
        mov     pc, lr              @ return

IsHex2:
        cmp     v6, #'a             @ 英小文字(a-z)か?
        bcs     1f
        msr     cpsr_f, #0x20000000 @ if v6<'a' Cy=1
        mov     pc, lr              @ return
    1:  cmp     v6, #'f+1           @ if v6>'f' Cy=1
        subcc   v6, v6, #'a         @ yes
        mov     pc, lr              @ return

IsHexNum:
        stmfd   sp!, {lr}
        bl      IsHex               @ 英文字か?
        bcc     1f                  @ yes
        bl      IsNum2              @ 数字か?
    1:  ldmfd   sp!, {pc}

@-------------------------------------------------------------------------
@ URLデコード
@
@ r0 にURLエンコード文字列の先頭設定
@ r1 に変更範囲の文字数を設定
@ r2 にデコード後の文字列先頭を設定
@ r0 にデコード後の文字数を返す
@-------------------------------------------------------------------------
URL_Decode:
        stmfd   sp!, {v4-v8, lr}
        add     v7, r0, r1
        sub     v7, v7, #1
        mov     v4, #0
    1:
        ldrb    v5, [r0], #1
        cmp     v5, #'+
        bne     2f
        mov     v5, #' '
        strb    v5, [r2, v4]
        b       4f
    2:  cmp     v5, #'%
        beq     3f
        strb    v5, [r2, v4]
        b       4f
    3:
        mov     v5, #0
        ldrb    v6, [r0], #1
        bl      IsHexNum
        bcs     4f
        add     v5, v5, v6
        ldrb    v6, [r0], #1
        bl      IsHexNum
        bcs     4f
        mov     v5, v5, LSL #4
        add     v5, v5, v6
        strb    v5, [r2, v4]
    4:
        add     v4, v4, #1
        cmp     r0, v7
        ble     1b

        mov     v5, #0
        strb    v5, [r2, v4]
        mov     r0, v4              @ 文字数を返す
        ldmfd   sp!, {v4-v8, pc}

@-------------------------------------------------------------------------
@ 組み込み関数用
@-------------------------------------------------------------------------
FuncBegin:
        stmfd   sp!, {lr}
        bl      OutAsciiZ
        bl      GetChar             @ get *
        cmp     v1, #'*
        bne     1f
        bl      SkipEqualExp        @ r0 にアドレス
        mov     r2, v4              @ v4退避
        mov     v4, r0              @ RangeCheckはv4を見る
        bl      RangeCheck          @ コピー先を範囲チェック
        mov     v4, r2              @ コピー先復帰
        bcs     4f                  @ 範囲外をアクセス
        bl      GetString2          @ FileNameにコピー
        b       3f
    1:  ldrb    ip, [v3]
        cmp     ip, #'"'
        bleq    GetChar             @ skip "
    2:  bl      GetString           @ パス名の取得
    3:  bl      ParseArg            @ 引数のパース
        ldr     r1, exarg2
        ldmfd   sp!, {pc}
    4:  mov     v1, #0xFF           @ エラー文字を FF
        b       LongJump            @ アクセス可能範囲を超えた

@-------------------------------------------------------------------------
@ 8進数文字列を数値に変換
@ r0 からの8進数文字列を数値に変換して r1 に返す
@-------------------------------------------------------------------------
Oct2Bin:
        stmfd   sp!, {r1, r2, lr}
        bl      GetOctal            @ r1
        bhi     2f                  @ exit
        mov     r2, r1
    1:
        bl      GetOctal
        bhi     2f
        add     r2, r2, r1, LSL#3
        b       1b
    2:
        mov     r1, r2
        ldmfd   sp!, {r1, r2, pc}

@-------------------------------------------------------------------------
@ r2 の示す8進数文字を数値に変換して r1 に返す
@ 8進数文字でないかどうかは bhiで判定可能
@-------------------------------------------------------------------------
GetOctal:
        ldr     r1, [r0], #1
        sub     r1, r1, #'0
        cmp     r1, #7
        mov     pc, lr

@-------------------------------------------------------------------------
@ ファイル内容表示
@ r0 にファイル名
@-------------------------------------------------------------------------
DispFile:
        stmfd   sp!, {r7, lr}
        bl      fropen              @ open
        bl      CheckError
        bmi     3f
        mov     r3, r0              @ FileDesc
        mov     r2, #4              @ read 1 byte
        stmfd   sp!, {r0}
        mov     r1, sp              @ r1  address
    1:
        mov     r0, r3              @ r0  fd
        mov     r7, #sys_read
        swi     0
        tst     r0, r0
        beq     2f
        mov     r2, r0              @ r2  length
        mov     r0, #1              @ r0  stdout
        mov     r7, #sys_write
        swi     0
        b       1b
    2:
        ldmfd   sp!, {r0}
        bl      fclose
    3:  ldmfd   sp!, {r7, pc}

.endif

@==============================================================
.bss

                .align   2
cgiflag0:       .long   0
counter0:       .long   0
save_stack0:    .long   0
current_arg0:   .long   0
argc0:          .long   0
argvp0:         .long   0
envp0:          .long   0
argc_vtl0:      .long   0
argp_vtl0:      .long   0
exarg0:         .skip   (ARGMAX+1)*4    @ execve 用
ipipe0:         .long   0
opipe0:         .long   0
ipipe20:        .long   0
opipe20:        .long   0
stat_addr0:     .long   0

                .align  2
input20:        .skip   MAXLINE
FileName0:      .skip   FNAMEMAX
pid0:           .long   0               @ fp-24
FOR_direct0:    .byte   0               @ fp-20
ExpError0:      .byte   0               @ fp-19
ZeroDiv0:       .byte   0               @ fp-18
SigInt0:        .byte   0               @ fp-17
VSTACK0:        .long   0               @ fp-16
FileDescW0:     .long   0               @ fp-12
FileDesc0:      .long   0               @ fp-8
ReadFrom0:      .byte   0               @ fp-4
ExecMode0:      .byte   0               @ fp-3
EOL0:           .byte   0               @ fp-2
LSTACK0:        .byte   0               @ fp-1
VarArea0:       .skip   256*4           @ fp    後半128dwordはLSTACK用
VarStack0:      .skip   VSTACKMAX*4     @ fp+1024

.ifdef VTL_LABEL
                .align  2
LabelTable0:    .skip   LABELMAX*16     @ 1024*16 bytes
TablePointer0:  .long   0
.endif

