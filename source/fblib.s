@-------------------------------------------------------------------------
@  file : fblib.s
@  2003/10/05
@  2013/04/25 arm eabi, linux 3.6 
@  2015/11/12 Change the mnemonic of SWI instruction to SVC 
@  Copyright (C) 2003-2015  Jun Mizutani <mizutani.jun@nifty.ne.jp>
@-------------------------------------------------------------------------

.ifndef __FBLIB
__FBLIB = 1

.ifndef __SYSCALL
.include    "syscalls.s"
.endif

.ifndef O_RDWR
O_RDWR                  = 2
.endif

PROT_READ               = 0x1     @ page can be read
PROT_WRITE              = 0x2     @ page can be written
MAP_SHARED              = 0x01    @ Share changes

FBIOGET_VSCREENINFO     = 0x4600
FBIOPUT_VSCREENINFO     = 0x4601
FBIOGET_FSCREENINFO     = 0x4602
FBIOGETCMAP             = 0x4604
FBIOPUTCMAP             = 0x4605

@==============================================================

.text

@-------------------------------------------------------------------------
@ open framebuffer device file
@-------------------------------------------------------------------------
fbdev_open:
        stmfd   sp!, {r1-r2, r7, lr}
        adr     r0, fb_device           @ open /dev/fb0
        mov     r1, #O_RDWR             @ flag
        mov     r2, #0                  @ mode
        mov     r7, #sys_open
        svc     0
        ldr     r1, fb_desc
        str     r0, [r1]                @ save fd
        cmp     r0, #0
        ldmfd   sp!, {r1-r2, r7, pc}    @ return
fb_device:
        .asciz  "/dev/fb0"

        .align  2
@-------------------------------------------------------------------------
@ close framebuffer
@-------------------------------------------------------------------------
fbdev_close:
        stmfd   sp!, {r0, r1, r7, lr}
        ldr     r1, fb_desc             @ close /dev/fb0
        ldr     r0, [r1]
        mov     r7, #sys_close
        svc     0
        tst     r0, r0
        ldmfd   sp!, {r0, r1, r7, pc}   @ return

@-------------------------------------------------------------------------
@ フレームバッファの物理状態を取得
@-------------------------------------------------------------------------
fb_get_fscreen:
        stmfd   sp!, {r0-r2, r7, lr}
        ldr     r1, fb_desc
        ldr     r0, [r1]
        ldr     r1, =FBIOGET_FSCREENINFO
        ldr     r2, fscinfo             @ 保存先指定
        mov     r7, #sys_ioctl
        svc     0
        cmp     r0, #0
        ldmfd   sp!, {r0-r2, r7, pc}    @ return

@-------------------------------------------------------------------------
@ 現在のフレームバッファの状態を取得
@-------------------------------------------------------------------------
fb_get_screen:
        stmfd   sp!, {r0-r2, r7, lr}
        ldr     r1, fb_desc
        ldr     r0, [r1]
        ldr     r1, =FBIOGET_VSCREENINFO
        ldr     r2, scinfsave           @ 保存先指定
        mov     r7, #sys_ioctl
        svc     0
        cmp     r0, #0
        ldmfd   sp!, {r0-r2, r7, pc}    @ return

@-------------------------------------------------------------------------
@ フレームバッファ設定を書きこむ
@-------------------------------------------------------------------------
fb_set_screen:
        stmfd   sp!, {r0-r2, r7, lr}
        ldr     r1, fb_desc
        ldr     r0, [r1]
        ldr     r1, =FBIOPUT_VSCREENINFO
        ldr     r2, scinfdata           @ 設定済みデータ
        mov     r7, #sys_ioctl
        svc     0
        cmp     r0, #0
        ldmfd   sp!, {r0-r2, r7, pc}    @ return

@-------------------------------------------------------------------------
@ 保存済みのフレームバッファ設定を新規設定用にコピー
@-------------------------------------------------------------------------
fb_copy_scinfo:
        stmfd   sp!, {r0-r3, lr}
        ldr     r0, scinfsave
        ldr     r1, scinfdata
        ldr     r2, fb_screeninfo_size
   1:   ldr     r3, [r0],#4             @ post-indexed addressing
        str     r3, [r1],#4
        subs    r2, r2, #1
        bne     1b
        ldmfd   sp!, {r0-r3, pc}        @ return

@-------------------------------------------------------------------------
@ フレームバッファメモリをマッピング (3.04.1)
@-------------------------------------------------------------------------
fb_map_screen:
        stmfd   sp!, {r1-r7, lr}
        ldr     r0, scinfsave           @ screen_info structure
        ldr     r6, fb_addr
        ldr     r1, [r0, #+12]          @ yres_virtual
        ldr     r2, [r0, #+8]           @ xres_virtual
        mul     r1, r2, r1              @ x * y
        ldr     r2, [r0, #+24]          @ bits_per_pixel
        mov     r2, r2, LSR #3
        mul     r1, r2, r1              @ len = x*y*depth/8
	str     r1, [r6, #+4]           @ fb_len
        mov     r0, #0                  @ addr
        ldr     r2, =(PROT_READ|PROT_WRITE) @ prot
        ldr     r3, =MAP_SHARED         @ flags
        ldr     r5, fb_desc
        ldr     r4, [r5]                @ fd
        mov     r5, #0
        mov     r7, #sys_mmap2          @ 192
        svc     0
	str     r0, [r6]                @ fb_addr
        cmp     r0, #0
        rsbmi   r1, r0, #0              @ if r0 < 0 then r1 = -r0 
        cmpmi   r1, #255                @ if r1 < 255 then error
        ldmfd   sp!, {r1-r7, pc}        @ return

@-------------------------------------------------------------------------
@ フレームバッファメモリをアンマップ (3.03.2)
@-------------------------------------------------------------------------
fb_unmap_screen:
        stmfd   sp!, {r0-r2, r7, lr}
        ldr     r2, fb_addr
        ldr     r0, [r2]                @ adr
        ldr     r1, [r2, #+4]           @ len
        mov     r7, #sys_munmap
        svc     0
        tst     r0, r0
        ldmfd   sp!, {r0-r2, r7, pc}    @ return

@-------------------------------------------------------------------------
@ 保存済みのフレームバッファ設定を復帰
@-------------------------------------------------------------------------
fb_restore_sc:
        stmfd   sp!, {r0-r2, r7, lr}
        adr     r1, fb_desc
        ldr     r0, [r1]
        ldr     r1, =FBIOPUT_VSCREENINFO
        ldr     r2, scinfsave
        mov     r7, #sys_ioctl
        svc     0
        tst     r0, r0
        ldmfd   sp!, {r0-r2, r7, pc}    @ return


@==============================================================

                    .align   2

@mmap_arg:               .long   _mmap_arg
scinfsave:              .long   scinfo_save
scinfdata:              .long   scinfo_data
fscinfo:                .long   fsc_info
fb_screeninfo_size:     .long   (scinfo_data - scinfo_save)/4
fb_desc:                .long   _fb_desc
fb_addr:                .long   _fb_addr
fb_len:                 .long   _fb_len

.pool

@==============================================================
.bss

_fb_desc:               .long   0
_fb_addr:               .long   0
_fb_len:                .long   0

scinfo_save:
sis_xres:               .long   0   @ visible resolution
sis_yres:               .long   0
sis_xres_virtual:       .long   0   @ virtual resolution
sis_yres_virtual:       .long   0
sis_xoffset:            .long   0   @ offset from virtual to visible
sis_yoffset:            .long   0   @ resolution
sis_bits_per_pixel:     .long   0   @ guess what
sis_grayscale:          .long   0   @ != 0 Graylevels instead of colors
sis_red_offset:         .long   0   @ beginning of bitfield
sis_red_length:         .long   0   @ length of bitfield
sis_red_msb_right:      .long   0   @ != 0 : Most significant bit is
sis_green_offset:       .long   0   @ beginning of bitfield
sis_green_length:       .long   0   @ length of bitfield
sis_green_msb_right:    .long   0   @ != 0 : Most significant bit is
sis_blue_offset:        .long   0   @ beginning of bitfield
sis_blue_length:        .long   0   @ length of bitfield
sis_blue_msb_right:     .long   0   @ != 0 : Most significant bit is
sis_transp_offset:      .long   0   @ beginning of bitfield
sis_transp_length:      .long   0   @ length of bitfield
sis_transp_msb_right:   .long   0   @ != 0 : Most significant bit is
sis_nonstd:             .long   0   @ != 0 Non standard pixel format
sis_activate:           .long   0   @ see FB_ACTIVATE_*
sis_height:             .long   0   @ height of picture in mm
sis_width:              .long   0   @ width of picture in mm
sis_accel_flags:        .long   0   @ acceleration flags (hints)
sis_pixclock:           .long   0   @ pixel clock in ps (pico seconds)
sis_left_margin:        .long   0   @ time from sync to picture
sis_right_margin:       .long   0   @ time from picture to sync
sis_upper_margin:       .long   0   @ time from sync to picture
sis_lower_margin:       .long   0
sis_hsync_len:          .long   0   @ length of horizontal sync
sis_vsync_len:          .long   0   @ length of vertical sync
sis_sync:               .long   0   @ see FB_SYNC_*
sis_vmode:              .long   0   @ see FB_VMODE_*
sis_reserved:           .space  24  @ Reserved for future compatibility

scinfo_data:            .skip   (scinfo_data - scinfo_save)

fsc_info:
fsi_id:                 .space  16  @  0 identification string
fsi_smem_start:         .long   0   @ 16 Start of frame buffer mem
fsi_smem_len:           .long   0   @ 20 Length of frame buffer mem
fsi_type:               .long   0   @ 24 see FB_TYPE_*
fsi_type_aux:           .long   0   @ 28 Interleave for interleaved Planes
fsi_visual:             .long   0   @ 32 see FB_VISUAL_*
fsi_xpanstep:           .hword  0   @ 36 zero if no hardware panning
fsi_ypanstep:           .hword  0   @ 38 zero if no hardware panning
fsi_ywrapstep:          .hword  0   @ 40 zero if no hardware ywrap
fsi_padding:            .hword  0   @ 42 for alignment, jm 1/26/2001
fsi_line_length:        .long   0   @ 44 length of a line in bytes
fsi_mmio_start:         .long   0   @ 48 Start of Memory Mapped I/O
fsi_mmio_len:           .long   0   @ 52 Length of Memory Mapped I/O
fsi_accel:              .long   0   @ 56 Type of acceleration available
fsi_reserved:           .space  6   @ Reserved for future compatibility

.endif
