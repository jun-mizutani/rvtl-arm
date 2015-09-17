@-------------------------------------------------------------------------
@  Return of the Very Tiny Language for ARM
@  2003/09/10
@  Copyright (C) 2003 Jun Mizutani <mizutani.jun@nifty.ne.jp>
@
@  file : ext.s
@-------------------------------------------------------------------------

        stmfd   sp!, {lr}
        bl      GetChar             @
        cmp     r0, #'j'
        beq     ext_j
        b       func_err

ext_j:
        bl      GetChar             @
        cmp     r0, #'m'
        beq     ext_jm
        b       func_err
ext_jm:
        ldmfd   sp!, {pc}        @ return
