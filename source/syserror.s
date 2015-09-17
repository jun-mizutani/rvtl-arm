@-------------------------------------------------------------------------
@ file : syserror.s
@ 2009/03/15
@ Copyright (C) 2003-2009 Jun Mizutani <mizutani.jun@nifty.ne.jp>
@ Read LICENSE file for full copyright information (GNU GPL)
@-------------------------------------------------------------------------

.include        "errno.s"

.ifndef __SYSERR_INC
__SYSERR_INC = 1

@;==============================================================
.text

SysCallError:
        stmfd   sp!, {r0-r4, lr}
        mrs     r4, cpsr
        tst     r0, r0
        bpl     3f
        rsb     r0, r0, #0
        mov     r1, r0
        ldr     r2, =sys_error_end
        adr     r3, sys_error_tbl
    1:
        ldr     ip, [r3]
        cmp     r1, ip
        beq     2f
        add     r3, r3, #8
        cmp     r3, r2
        bne     1b
        b       3f
    2:
        ldr     r0, [r3, #+4]
        bl      OutAsciiZ
        bl      NewLine
    3:
        msr     cpsr_f, r4
        ldmfd   sp!, {r0-r4, pc}        @ return

@==============================================================
.pool

        .align 2
sys_error_tbl:
        .long  EPERM          ,    msg_EPERM
        .long  ENOENT         ,    msg_ENOENT
        .long  ESRCH          ,    msg_ESRCH
        .long  EINTR          ,    msg_EINTR
        .long  EIO            ,    msg_EIO
        .long  ENXIO          ,    msg_ENXIO
        .long  E2BIG          ,    msg_E2BIG
        .long  ENOEXEC        ,    msg_ENOEXEC
        .long  EBADF          ,    msg_EBADF
        .long  ECHILD         ,    msg_ECHILD
        .long  EAGAIN         ,    msg_EAGAIN
        .long  ENOMEM         ,    msg_ENOMEM
        .long  EACCES         ,    msg_EACCES
        .long  EFAULT         ,    msg_EFAULT
        .long  ENOTBLK        ,    msg_ENOTBLK
        .long  EBUSY          ,    msg_EBUSY
        .long  EEXIST         ,    msg_EEXIST
        .long  EXDEV          ,    msg_EXDEV
        .long  ENODEV         ,    msg_ENODEV
        .long  ENOTDIR        ,    msg_ENOTDIR
        .long  EISDIR         ,    msg_EISDIR
        .long  EINVAL         ,    msg_EINVAL
        .long  ENFILE         ,    msg_ENFILE
        .long  EMFILE         ,    msg_EMFILE
        .long  ENOTTY         ,    msg_ENOTTY
        .long  ETXTBSY        ,    msg_ETXTBSY
        .long  EFBIG          ,    msg_EFBIG
        .long  ENOSPC         ,    msg_ENOSPC
        .long  ESPIPE         ,    msg_ESPIPE
        .long  EROFS          ,    msg_EROFS
        .long  EMLINK         ,    msg_EMLINK
        .long  EPIPE          ,    msg_EPIPE
        .long  EDOM           ,    msg_EDOM
        .long  ERANGE         ,    msg_ERANGE
        .long  EDEADLK        ,    msg_EDEADLK
        .long  ENAMETOOLONG   ,    msg_ENAMETOOLONG
        .long  ENOLCK         ,    msg_ENOLCK
        .long  ENOSYS         ,    msg_ENOSYS
        .long  ENOTEMPTY      ,    msg_ENOTEMPTY
        .long  ELOOP          ,    msg_ELOOP
        .long  EWOULDBLOCK    ,    msg_EWOULDBLOCK
        .long  ENOMSG         ,    msg_ENOMSG
        .long  EIDRM          ,    msg_EIDRM
        .long  ECHRNG         ,    msg_ECHRNG
        .long  EL2NSYNC       ,    msg_EL2NSYNC
        .long  EL3HLT         ,    msg_EL3HLT
        .long  EL3RST         ,    msg_EL3RST
        .long  ELNRNG         ,    msg_ELNRNG
        .long  EUNATCH        ,    msg_EUNATCH
        .long  ENOCSI         ,    msg_ENOCSI
        .long  EL2HLT         ,    msg_EL2HLT
        .long  EBADE          ,    msg_EBADE
        .long  EBADR          ,    msg_EBADR
        .long  EXFULL         ,    msg_EXFULL
        .long  ENOANO         ,    msg_ENOANO
        .long  EBADRQC        ,    msg_EBADRQC
        .long  EBADSLT        ,    msg_EBADSLT
        .long  EDEADLOCK      ,    msg_EDEADLOCK
        .long  EBFONT         ,    msg_EBFONT
        .long  ENOSTR         ,    msg_ENOSTR
        .long  ENODATA        ,    msg_ENODATA
        .long  ETIME          ,    msg_ETIME
        .long  ENOSR          ,    msg_ENOSR
        .long  ENONET         ,    msg_ENONET
        .long  ENOPKG         ,    msg_ENOPKG
        .long  EREMOTE        ,    msg_EREMOTE
        .long  ENOLINK        ,    msg_ENOLINK
        .long  EADV           ,    msg_EADV
        .long  ESRMNT         ,    msg_ESRMNT
        .long  ECOMM          ,    msg_ECOMM
        .long  EPROTO         ,    msg_EPROTO
        .long  EMULTIHOP      ,    msg_EMULTIHOP
        .long  EDOTDOT        ,    msg_EDOTDOT
        .long  EBADMSG        ,    msg_EBADMSG
        .long  EOVERFLOW      ,    msg_EOVERFLOW
        .long  ENOTUNIQ       ,    msg_ENOTUNIQ
        .long  EBADFD         ,    msg_EBADFD
        .long  EREMCHG        ,    msg_EREMCHG
        .long  ELIBACC        ,    msg_ELIBACC
        .long  ELIBBAD        ,    msg_ELIBBAD
        .long  ELIBSCN        ,    msg_ELIBSCN
        .long  ELIBMAX        ,    msg_ELIBMAX
        .long  ELIBEXEC       ,    msg_ELIBEXEC
        .long  EILSEQ         ,    msg_EILSEQ
        .long  ERESTART       ,    msg_ERESTART
        .long  ESTRPIPE       ,    msg_ESTRPIPE
        .long  EUSERS         ,    msg_EUSERS
        .long  ENOTSOCK       ,    msg_ENOTSOCK
        .long  EDESTADDRREQ   ,    msg_EDESTADDRREQ
        .long  EMSGSIZE       ,    msg_EMSGSIZE
        .long  EPROTOTYPE     ,    msg_EPROTOTYPE
        .long  ENOPROTOOPT    ,    msg_ENOPROTOOPT
        .long  EPROTONOSUPPORT,    msg_EPROTONOSUPPORT
        .long  ESOCKTNOSUPPORT,    msg_ESOCKTNOSUPPORT
        .long  EOPNOTSUPP     ,    msg_EOPNOTSUPP
        .long  EPFNOSUPPORT   ,    msg_EPFNOSUPPORT
        .long  EAFNOSUPPORT   ,    msg_EAFNOSUPPORT
        .long  EADDRINUSE     ,    msg_EADDRINUSE
        .long  EADDRNOTAVAIL  ,    msg_EADDRNOTAVAIL
        .long  ENETDOWN       ,    msg_ENETDOWN
        .long  ENETUNREACH    ,    msg_ENETUNREACH
        .long  ENETRESET      ,    msg_ENETRESET
        .long  ECONNABORTED   ,    msg_ECONNABORTED
        .long  ECONNRESET     ,    msg_ECONNRESET
        .long  ENOBUFS        ,    msg_ENOBUFS
        .long  EISCONN        ,    msg_EISCONN
        .long  ENOTCONN       ,    msg_ENOTCONN
        .long  ESHUTDOWN      ,    msg_ESHUTDOWN
        .long  ETOOMANYREFS   ,    msg_ETOOMANYREFS
        .long  ETIMEDOUT      ,    msg_ETIMEDOUT
        .long  ECONNREFUSED   ,    msg_ECONNREFUSED
        .long  EHOSTDOWN      ,    msg_EHOSTDOWN
        .long  EHOSTUNREACH   ,    msg_EHOSTUNREACH
        .long  EALREADY       ,    msg_EALREADY
        .long  EINPROGRESS    ,    msg_EINPROGRESS
        .long  ESTALE         ,    msg_ESTALE
        .long  EUCLEAN        ,    msg_EUCLEAN
        .long  ENOTNAM        ,    msg_ENOTNAM
        .long  ENAVAIL        ,    msg_ENAVAIL
        .long  EISNAM         ,    msg_EISNAM
        .long  EREMOTEIO      ,    msg_EREMOTEIO
        .long  EDQUOT         ,    msg_EDQUOT
        .long  ENOMEDIUM      ,    msg_ENOMEDIUM
        .long  EMEDIUMTYPE    ,    msg_EMEDIUMTYPE

sys_error_end:

                     .align 2
msg_EPERM:           .asciz "[EPERM] Operation not permitted"
msg_ENOENT:          .asciz "[ENOENT] No such file or directory"
msg_ESRCH:           .asciz "[ESRCH] No such process"
msg_EINTR:           .asciz "[EINTR] Interrupted system call"
msg_EIO:             .asciz "[EIO] I/O error"
msg_ENXIO:           .asciz "[ENXIO] No such device or address"
msg_E2BIG:           .asciz "[E2BIG] Arg list too long"
msg_ENOEXEC:         .asciz "[ENOEXEC] Exec format error"
msg_EBADF:           .asciz "[EBADF] Bad file number"
msg_ECHILD:          .asciz "[ECHILD] No child processes"
msg_EAGAIN:          .asciz "[EAGAIN] Try again"
msg_ENOMEM:          .asciz "[ENOMEM] Out of memory"
msg_EACCES:          .asciz "[EACCES] Permission denied"
msg_EFAULT:          .asciz "[EFAULT] Bad address"
msg_ENOTBLK:         .asciz "[ENOTBLK] Block device required"
msg_EBUSY:           .asciz "[EBUSY] Device or resource busy"
msg_EEXIST:          .asciz "[EEXIST] File exists"
msg_EXDEV:           .asciz "[EXDEV] Cross-device link"
msg_ENODEV:          .asciz "[ENODEV] No such device"
msg_ENOTDIR:         .asciz "[ENOTDIR] Not a directory"
msg_EISDIR:          .asciz "[EISDIR] Is a directory"
msg_EINVAL:          .asciz "[EINVAL] Invalid argument"
msg_ENFILE:          .asciz "[ENFILE] File table overflow"
msg_EMFILE:          .asciz "[EMFILE] Too many open files"
msg_ENOTTY:          .asciz "[ENOTTY] Not a typewriter"
msg_ETXTBSY:         .asciz "[ETXTBSY] Text file busy"
msg_EFBIG:           .asciz "[EFBIG] File too large"
msg_ENOSPC:          .asciz "[ENOSPC] No space left on device"
msg_ESPIPE:          .asciz "[ESPIPE] Illegal seek"
msg_EROFS:           .asciz "[EROFS] Read-only file system"
msg_EMLINK:          .asciz "[EMLINK] Too many links"
msg_EPIPE:           .asciz "[EPIPE] Broken pipe"
msg_EDOM:            .asciz "[EDOM] Math argument out of domain of func"
msg_ERANGE:          .asciz "[ERANGE] Math result not representable"
msg_EDEADLK:         .asciz "[EDEADLK] Resource deadlock would occur"
msg_ENAMETOOLONG:    .asciz "[ENAMETOOLONG] File name too long"
msg_ENOLCK:          .asciz "[ENOLCK] No record locks available"
msg_ENOSYS:          .asciz "[ENOSYS] Function not implemented"
msg_ENOTEMPTY:       .asciz "[ENOTEMPTY] Directory not empty"
msg_ELOOP:           .asciz "[ELOOP] Too many symbolic links encountered"
msg_EWOULDBLOCK:     .asciz "[EWOULDBLOCK] Operation would block"
msg_ENOMSG:          .asciz "[ENOMSG] No message of desired type"
msg_EIDRM:           .asciz "[EIDRM] Identifier removed"
msg_ECHRNG:          .asciz "[ECHRNG] Channel number out of range"
msg_EL2NSYNC:        .asciz "[EL2NSYNC] Level 2 not synchronized"
msg_EL3HLT:          .asciz "[EL3HLT] Level 3 halted"
msg_EL3RST:          .asciz "[EL3RST] Level 3 reset"
msg_ELNRNG:          .asciz "[ELNRNG] Link number out of range"
msg_EUNATCH:         .asciz "[EUNATCH] Protocol driver not attached"
msg_ENOCSI:          .asciz "[ENOCSI] No CSI structure available"
msg_EL2HLT:          .asciz "[EL2HLT] Level 2 halted"
msg_EBADE:           .asciz "[EBADE] Invalid exchange"
msg_EBADR:           .asciz "[EBADR] Invalid request descriptor"
msg_EXFULL:          .asciz "[EXFULL] Exchange full"
msg_ENOANO:          .asciz "[ENOANO] No anode"
msg_EBADRQC:         .asciz "[EBADRQC] Invalid request code"
msg_EBADSLT:         .asciz "[EBADSLT] Invalid slot"
msg_EDEADLOCK:       .asciz "[EDEADLOCK] Resource deadlock would occur"
msg_EBFONT:          .asciz "[EBFONT] Bad font file format"
msg_ENOSTR:          .asciz "[ENOSTR] Device not a stream"
msg_ENODATA:         .asciz "[ENODATA] No data available"
msg_ETIME:           .asciz "[ETIME] Timer expired"
msg_ENOSR:           .asciz "[ENOSR] Out of streams resources"
msg_ENONET:          .asciz "[ENONET] Machine is not on the network"
msg_ENOPKG:          .asciz "[ENOPKG] Package not installed"
msg_EREMOTE:         .asciz "[EREMOTE] Object is remote"
msg_ENOLINK:         .asciz "[ENOLINK] Link has been severed"
msg_EADV:            .asciz "[EADV] Advertise error"
msg_ESRMNT:          .asciz "[ESRMNT] Srmount error"
msg_ECOMM:           .asciz "[ECOMM] Communication error on send"
msg_EPROTO:          .asciz "[EPROTO] Protocol error"
msg_EMULTIHOP:       .asciz "[EMULTIHOP] Multihop attempted"
msg_EDOTDOT:         .asciz "[EDOTDOT] RFS specific error"
msg_EBADMSG:         .asciz "[EBADMSG] Not a data message"
msg_EOVERFLOW:       .asciz "[EOVERFLOW] Value too large for defined data type"
msg_ENOTUNIQ:        .asciz "[ENOTUNIQ] Name not unique on network"
msg_EBADFD:          .asciz "[EBADFD] File descriptor in bad state"
msg_EREMCHG:         .asciz "[EREMCHG] Remote address changed"
msg_ELIBACC:         .asciz "[ELIBACC] Can not access a needed shared library"
msg_ELIBBAD:         .asciz "[ELIBBAD] Accessing a corrupted shared library"
msg_ELIBSCN:         .asciz "[ELIBSCN] .lib section in a.out corrupted"
msg_ELIBMAX:         .asciz "[ELIBMAX] Attempting to link in too many shared libraries"
msg_ELIBEXEC:        .asciz "[ELIBEXEC] Cannot exec a shared library directly"
msg_EILSEQ:          .asciz "[EILSEQ] Illegal byte sequence"
msg_ERESTART:        .asciz "[ERESTART] Interrupted system call should be restarted"
msg_ESTRPIPE:        .asciz "[ESTRPIPE] Streams pipe error"
msg_EUSERS:          .asciz "[EUSERS] Too many users"
msg_ENOTSOCK:        .asciz "[ENOTSOCK] Socket operation on non-socket"
msg_EDESTADDRREQ:    .asciz "[EDESTADDRREQ] Destination address required"
msg_EMSGSIZE:        .asciz "[EMSGSIZE] Message too long"
msg_EPROTOTYPE:      .asciz "[EPROTOTYPE] Protocol wrong type for socket"
msg_ENOPROTOOPT:     .asciz "[ENOPROTOOPT] Protocol not available"
msg_EPROTONOSUPPORT: .asciz "[EPROTONOSUPPORT] Protocol not supported"
msg_ESOCKTNOSUPPORT: .asciz "[ESOCKTNOSUPPORT] Socket type not supported"
msg_EOPNOTSUPP:      .asciz "[EOPNOTSUPP] Operation not supported on transport endpoint"
msg_EPFNOSUPPORT:    .asciz "[EPFNOSUPPORT] Protocol family not supported"
msg_EAFNOSUPPORT:    .asciz "[EAFNOSUPPORT] Address family not supported by protocol"
msg_EADDRINUSE:      .asciz "[EADDRINUSE] Address already in use"
msg_EADDRNOTAVAIL:   .asciz "[EADDRNOTAVAIL] Cannot assign requested address"
msg_ENETDOWN:        .asciz "[ENETDOWN] Network is down"
msg_ENETUNREACH:     .asciz "[ENETUNREACH] Network is unreachable"
msg_ENETRESET:       .asciz "[ENETRESET] Network dropped connection because of reset "
msg_ECONNABORTED:    .asciz "[ECONNABORTED] Software caused connection abort"
msg_ECONNRESET:      .asciz "[ECONNRESET] Connection reset by peer"
msg_ENOBUFS:         .asciz "[ENOBUFS] No buffer space available"
msg_EISCONN:         .asciz "[EISCONN] Transport endpoint is already connected"
msg_ENOTCONN:        .asciz "[ENOTCONN] Transport endpoint is not connected"
msg_ESHUTDOWN:       .asciz "[ESHUTDOWN] Cannot send after transport endpoint shutdown"
msg_ETOOMANYREFS:    .asciz "[ETOOMANYREFS] Too many references: cannot splice"
msg_ETIMEDOUT:       .asciz "[ETIMEDOUT] Connection timed out"
msg_ECONNREFUSED:    .asciz "[ECONNREFUSED] Connection refused"
msg_EHOSTDOWN:       .asciz "[EHOSTDOWN] Host is down"
msg_EHOSTUNREACH:    .asciz "[EHOSTUNREACH] No route to host"
msg_EALREADY:        .asciz "[EALREADY] Operation already in progress"
msg_EINPROGRESS:     .asciz "[EINPROGRESS] Operation now in progress"
msg_ESTALE:          .asciz "[ESTALE] Stale NFS file handle"
msg_EUCLEAN:         .asciz "[EUCLEAN] Structure needs cleaning"
msg_ENOTNAM:         .asciz "[ENOTNAM] Not a XENIX named type file"
msg_ENAVAIL:         .asciz "[ENAVAIL] No XENIX semaphores available"
msg_EISNAM:          .asciz "[EISNAM] Is a named type file"
msg_EREMOTEIO:       .asciz "[EREMOTEIO] Remote I/O error"
msg_EDQUOT:          .asciz "[EDQUOT] Quota exceeded"
msg_ENOMEDIUM:       .asciz "[ENOMEDIUM] No medium found"
msg_EMEDIUMTYPE:     .asciz "[EMEDIUMTYPE] Wrong medium type"
                     .align 2
.endif
