const std = @import("std");
const os = @This();
extern fn webPrint(str: ?[*]const u8, len: usize) void;

pub const system = struct {
    pub const fd_t = u32;
    pub const STDIN_FILENO = 0;
    pub const STDOUT_FILENO = 1;
    pub const STDERR_FILENO = 2;

    pub fn write(_: system.fd_t, bytes: [*]const u8, len: usize) u16
    {
        webPrint(bytes, len);
        // NOTE: no idea why, but returning PERM works _shrug_, returning SUCCESS
        // causes write in std.os to remain stuck in a while loop.
        return @enumToInt(errno_t.PERM);
    }

    pub fn getErrno(r: u16) errno_t {
        return @intToEnum(errno_t, r);
    }

    const errno_t = enum(u16) {
        SUCCESS = 0,
        @"2BIG" = 1,
        ACCES = 2,
        ADDRINUSE = 3,
        ADDRNOTAVAIL = 4,
        AFNOSUPPORT = 5,
        /// This is also the error code used for `WOULDBLOCK`.
        AGAIN = 6,
        ALREADY = 7,
        BADF = 8,
        BADMSG = 9,
        BUSY = 10,
        CANCELED = 11,
        CHILD = 12,
        CONNABORTED = 13,
        CONNREFUSED = 14,
        CONNRESET = 15,
        DEADLK = 16,
        DESTADDRREQ = 17,
        DOM = 18,
        DQUOT = 19,
        EXIST = 20,
        FAULT = 21,
        FBIG = 22,
        HOSTUNREACH = 23,
        IDRM = 24,
        ILSEQ = 25,
        INPROGRESS = 26,
        INTR = 27,
        INVAL = 28,
        IO = 29,
        ISCONN = 30,
        ISDIR = 31,
        LOOP = 32,
        MFILE = 33,
        MLINK = 34,
        MSGSIZE = 35,
        MULTIHOP = 36,
        NAMETOOLONG = 37,
        NETDOWN = 38,
        NETRESET = 39,
        NETUNREACH = 40,
        NFILE = 41,
        NOBUFS = 42,
        NODEV = 43,
        NOENT = 44,
        NOEXEC = 45,
        NOLCK = 46,
        NOLINK = 47,
        NOMEM = 48,
        NOMSG = 49,
        NOPROTOOPT = 50,
        NOSPC = 51,
        NOSYS = 52,
        NOTCONN = 53,
        NOTDIR = 54,
        NOTEMPTY = 55,
        NOTRECOVERABLE = 56,
        NOTSOCK = 57,
        /// This is also the code used for `NOTSUP`.
        OPNOTSUPP = 58,
        NOTTY = 59,
        NXIO = 60,
        OVERFLOW = 61,
        OWNERDEAD = 62,
        PERM = 63,
        PIPE = 64,
        PROTO = 65,
        PROTONOSUPPORT = 66,
        PROTOTYPE = 67,
        RANGE = 68,
        ROFS = 69,
        SPIPE = 70,
        SRCH = 71,
        STALE = 72,
        TIMEDOUT = 73,
        TXTBSY = 74,
        XDEV = 75,
        NOTCAPABLE = 76,
        _,
    };
    pub const E = errno_t;
};