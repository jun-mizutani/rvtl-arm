@---------------------------------------------------------------------
@   Mersenne Twister
@   file : mt19937.s
@     Rewritten in ARM Assembly by Jun Mizutani 2003/09/06.
@     From original code in C by Takuji Nishimura(mt19937int.c).
@     ARM version Copyright (C) 2003 Jun Mizutani.
@---------------------------------------------------------------------

@ A C-program for MT19937: Integer version (1999/10/28)
@  genrand() generates one pseudorandom unsigned integer (32bit)
@ which is uniformly distributed among 0 to 2^32-1  for each
@ call. sgenrand(seed) sets initial values to the working area
@ of 624 words. Before genrand(), sgenrand(seed) must be
@ called once. (seed is any 32-bit integer.)
@   Coded by Takuji Nishimura, considering the suggestions by
@ Topher Cooper and Marc Rieffel in July-Aug. 1997.
@
@ This library is free software; you can redistribute it and/or
@ modify it under the terms of the GNU Library General Public
@ License as published by the Free Software Foundation; either
@ version 2 of the License, or (at your option) any later
@ version.
@ This library is distributed in the hope that it will be useful,
@ but WITHOUT ANY WARRANTY; without even the implied warranty of
@ MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
@ See the GNU Library General Public License for more details.
@ You should have received a copy of the GNU Library General
@ Public License along with this library; if not, write to the
@ Free Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
@ 02111-1307  USA
@
@ Copyright (C) 1997, 1999 Makoto Matsumoto and Takuji Nishimura.
@ Any feedback is very welcome. For any question, comments,
@ see http://www.math.keio.ac.jp/matumoto/emt.html or email
@ matumoto@math.keio.ac.jp
@
@ REFERENCE
@ M. Matsumoto and T. Nishimura,
@ "Mersenne Twister: A 623-Dimensionally Equidistributed Uniform
@ Pseudo-Random Number Generator",
@ ACM Transactions on Modeling and Computer Simulation,
@ Vol. 8, No. 1, January 1998, pp 3--30.

.text
@---------------------------------------------------------------------
@ Initialize Mersenne Twister
@   enter r0 : seed
@---------------------------------------------------------------------
sgenrand:
        stmfd   sp!, {r0-r3, v3-v6, ip, lr}
        ldr     v3, mt
        ldr     v4, N
        ldr     v5, nffff0000
        ldr     v6, n69069
        mov     r2, #0              @ I=0
    1:
        and     r1, r0, v5          @ seed & 0xffff0000
        mul     r0, v6, r0
        add     r0, r0, #1
        and     ip, r0, v5          @ S & 0xffff0000
        mov     ip, ip,LSR #16
        orr     r1, r1, ip
        mul     r0, v6, r0
        add     r0, r0, #1
        str     r1, [v3, r2,LSL #2] @ mt[I]
        add     r2, r2, #1          @ I=I+1
        cmp     r2, v4
        blt     1b                  @ I+1 < 624
        ldr     r1, mti
        str     v4, [r1]            @ mti=N
        ldmfd   sp!, {r0-r3, v3-v6, ip, pc}

@---------------------------------------------------------------------
@ Generate Random Number
@   return r0 : random number
@---------------------------------------------------------------------
genrand:
        stmfd   sp!, {r1-r12, lr}
        ldr     v2, mti
        ldr     v3, mt
        ldr     v4, N
        ldr     r0, [v2]            @ mti
        sub     r2, v4, #1          @ N-1
        cmp     r0, r2              @ 623
        ble     3f                  @ from mt[]
        ldr     v5, M
        ldr     v6, UPPER_MASK
        ldr     v7, LOWER_MASK
        ldr     v8, MATRIX_A
        mov     v1, #0              @ K=0
    1:
        ldr     r0, [v3, v1,LSL #2] @ mt[K]
        and     r0, r0, v6          @ UPPER_MASK
        add     r3, v1, #1          @ J=K+1
        bl      rnd_common2         @ return Y>>1:r0,Z:r1
        add     r2, v1, v5
        bl      rnd_common
        str     r1, [v3, v1,LSL #2] @ mt[K]=P^Q^Z
        add     v1, v1, #1          @ K=K+1
        sub     r0, v4, v5          @ N-M
        cmp     v1, r0
        blt     1b
    2:
        ldr     r0, [v3, v1,LSL #2] @ mt[K]
        and     r0, r0, v6          @ UPPER_MASK
        add     r3, v1, #1          @ J=K+1
        bl      rnd_common2         @ return Y>>1:r0,Z:r1
        sub     r2, v5, v4
        add     r2, v1, r2          @ K+(M-N)
        bl      rnd_common
        str     r1, [v3, v1,LSL #2] @ mt[K]=P^Q^Z
        add     v1, v1, #1          @ K=K+1
        sub     r2, v4, #1          @ 623
        cmp     v1, r2
        blt     2b

        ldr     r0, [v3, v1,LSL #2] @ mt[K]
        and     r0, r0, v6          @ UPPER_MASK
        mov     r3, #0              @ J=0
        bl      rnd_common2         @ return Y>>1:r0,Z:r1
        sub     r2, v5, #1          @ 396
        bl      rnd_common
        sub     r2, v4, #1          @ 623
        str     r1, [v3, r2,LSL #2] @ mt[623]=P^Q^Z
        mov     r0, #0
        str     r0, [v2]            @ mti=0
    3:
        ldr     v6, TEMPERING_MASK_B
        ldr     v7, TEMPERING_MASK_C
        ldr     r0, [v2]            @ mti
        ldr     r3, [v3, r0,LSL #2] @ y=mt[mti]
        add     r0, r0, #1
        str     r0, [v2]            @ mti++
        mov     r0, r3,LSR #11      @ y>>11
        eor     r3, r3, r0          @ y=y^(y>>11)
        mov     r0, r3,LSL #7       @ y << 7
        and     r0, r0, v6          @ TEMPERING_MASK_B
        eor     r3, r3, r0
        mov     r0, r3,LSL #15
        and     r0, r0, v7          @ TEMPERING_MASK_C
        eor     r3, r3, r0
        mov     r0, r3,LSR #18
        eor     r0, r3, r0
        ldmfd   sp!, {r1-r12, pc}

    rnd_common:
        ldr     r3, [v3, r2,LSL #2] @ mt[x]
        eor     r3, r3, r0          @ mt[x]^P
        eor     r1, r3, r1
        mov     pc, lr
    rnd_common2:
        ldr     r1, [v3, r3,LSL #2] @ mt[J]
        and     r1, r1, v7          @ LOWER_MASK
        orr     r3, r0, r1          @ y
        mov     r0, r3, LSR #1      @ r0=(y>>1)
        mov     r1, #0
        tst     r3, #1
        movne   r1, v8              @ MATRIX_A
        mov     pc, lr

N:                  .long   624
M:                  .long   397
n69069:             .long   69069
nffff0000:          .long   0xffff0000
TEMPERING_MASK_B:   .long   0x9d2c5680
TEMPERING_MASK_C:   .long   0xefc60000
UPPER_MASK:         .long   0x80000000
LOWER_MASK:         .long   0x7fffffff
MATRIX_A:           .long   0x9908b0df
mt:                 .long   mt0
mti:                .long   mti0

.data
mti0:               .long   N + 1

.bss
mt0:                .skip   624 * 4
