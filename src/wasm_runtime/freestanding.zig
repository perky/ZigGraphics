//! A collection of polyfill functions for freestanding so
//! commonly used C library functions may still be used.

const std = @import("std");
const builtin = @import("builtin");
const heap = @import("std").heap;
const testing = @import("std").testing;
const debug = @import("std").debug;
const maxInt = std.math.maxInt;
const isNan = std.math.isNan;
const native_arch = builtin.cpu.arch;
const native_abi = builtin.abi;
const native_os = builtin.os.tag;
const long_double_is_f128 = builtin.target.longDoubleIsF128();

const is_wasm = switch (native_arch) {
    .wasm32, .wasm64 => true,
    else => false,
};

const is_freestanding = switch (native_os) {
    .freestanding => true,
    else => false,
};

comptime {
    if (!is_freestanding) @compileLog("Compiling zig code intended for freestanding!");
}

// Entry point for wasm.
pub export fn _start() void {
    @import("root").main();
}

// =====================
// ALLOCATION
// =====================

const FreeBlock = struct {
    ptr: usize,
    size: usize
};
var free_list = std.ArrayList(FreeBlock).init(heap.page_allocator);
const LOG_ALLOC = false;

pub export fn malloc(size: usize) usize
{
    if (LOG_ALLOC) std.log.info("Allocating {d} bytes", .{size});
    var slice = heap.page_allocator.alloc(u8, size) catch @panic("Failed to allocate memory.");
    const ptr_idx = @ptrToInt(&slice[0]);
    free_list.append(FreeBlock{
        .ptr = ptr_idx,
        .size = size
    }) catch @panic("memAlloc: unable to append to free_list.");
    return ptr_idx;
}

pub export fn free(ptr_idx: usize) void
{
    for (free_list.items) |block, i| {
        if (block.ptr == ptr_idx) {
            if (LOG_ALLOC) std.log.info("Freeing {d} bytes", .{block.size});
            const ptr = @intToPtr([*]const u8, block.ptr);
            heap.page_allocator.free(ptr[0..block.size]);
            _ = free_list.swapRemove(i);
            break;
        }
    }
}

// =====================
// STRING
// =====================

export fn toupper(char: u8) callconv(.C) u8
{
    return char;
}

export fn strcpy(dest: [*:0]u8, src: [*:0]const u8) callconv(.C) [*:0]u8
{
    var i: usize = 0;
    while (src[i] != 0) : (i += 1) {
        dest[i] = src[i];
    }
    dest[i] = 0;

    return dest;
}

test "strcpy"
{
    var s1: [9:0]u8 = undefined;

    s1[0] = 0;
    _ = strcpy(&s1, "foobarbaz");
    try testing.expectEqualSlices(u8, "foobarbaz", std.mem.sliceTo(&s1, 0));
}

export fn strncpy(dest: [*:0]u8, src: [*:0]const u8, n: usize) callconv(.C) [*:0]u8
{
    var i: usize = 0;
    while (i < n and src[i] != 0) : (i += 1) {
        dest[i] = src[i];
    }
    while (i < n) : (i += 1) {
        dest[i] = 0;
    }

    return dest;
}

test "strncpy"
{
    var s1: [9:0]u8 = undefined;

    s1[0] = 0;
    _ = strncpy(&s1, "foobarbaz", @sizeOf(@TypeOf(s1)));
    try testing.expectEqualSlices(u8, "foobarbaz", std.mem.sliceTo(&s1, 0));
}

export fn strcat(dest: [*:0]u8, src: [*:0]const u8) callconv(.C) [*:0]u8
{
    var dest_end: usize = 0;
    while (dest[dest_end] != 0) : (dest_end += 1) {}

    var i: usize = 0;
    while (src[i] != 0) : (i += 1) {
        dest[dest_end + i] = src[i];
    }
    dest[dest_end + i] = 0;

    return dest;
}

test "strcat"
{
    var s1: [9:0]u8 = undefined;

    s1[0] = 0;
    _ = strcat(&s1, "foo");
    _ = strcat(&s1, "bar");
    _ = strcat(&s1, "baz");
    try testing.expectEqualSlices(u8, "foobarbaz", std.mem.sliceTo(&s1, 0));
}

export fn strncat(dest: [*:0]u8, src: [*:0]const u8, avail: usize) callconv(.C) [*:0]u8
{
    var dest_end: usize = 0;
    while (dest[dest_end] != 0) : (dest_end += 1) {}

    var i: usize = 0;
    while (i < avail and src[i] != 0) : (i += 1) {
        dest[dest_end + i] = src[i];
    }
    dest[dest_end + i] = 0;

    return dest;
}

test "strncat"
{
    var s1: [9:0]u8 = undefined;

    s1[0] = 0;
    _ = strncat(&s1, "foo1111", 3);
    _ = strncat(&s1, "bar1111", 3);
    _ = strncat(&s1, "baz1111", 3);
    try testing.expectEqualSlices(u8, "foobarbaz", std.mem.sliceTo(&s1, 0));
}

export fn strcmp(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) c_int
{
    return std.cstr.cmp(s1, s2);
}

export fn strlen(s: [*:0]const u8) callconv(.C) usize
{
    return std.mem.len(s);
}

export fn strncmp(_l: [*:0]const u8, _r: [*:0]const u8, _n: usize) callconv(.C) c_int
{
    if (_n == 0) return 0;
    var l = _l;
    var r = _r;
    var n = _n - 1;
    while (l[0] != 0 and r[0] != 0 and n != 0 and l[0] == r[0]) {
        l += 1;
        r += 1;
        n -= 1;
    }
    return @as(c_int, l[0]) - @as(c_int, r[0]);
}

export fn strerror(errnum: c_int) callconv(.C) [*:0]const u8
{
    _ = errnum;
    return "TODO strerror implementation";
}

test "strncmp"
{
    try testing.expect(strncmp("a", "b", 1) == -1);
    try testing.expect(strncmp("a", "c", 1) == -2);
    try testing.expect(strncmp("b", "a", 1) == 1);
    try testing.expect(strncmp("\xff", "\x02", 1) == 253);
}

pub export fn strstr(chaystack: [*c]const u8, cneedle: [*c]const u8) [*c]const u8
{
    const haystack = std.mem.sliceTo(chaystack, 0);
    const needle = std.mem.sliceTo(cneedle, 0);
    const maybe_index = std.mem.indexOf(u8, haystack, needle);
    if (maybe_index) |index| return &chaystack[index];
    return null;
}

// =====================
// MEM
// =====================

export fn memset(dest: ?[*]u8, c: u8, n: usize) callconv(.C) ?[*]u8 
{
    @setRuntimeSafety(false);

    var index: usize = 0;
    while (index != n) : (index += 1)
        dest.?[index] = c;

    return dest;
}

export fn __memset(dest: ?[*]u8, c: u8, n: usize, dest_n: usize) callconv(.C) ?[*]u8
{
    if (dest_n < n)
        @panic("buffer overflow");
    return memset(dest, c, n);
}

export fn memcpy(noalias dest: ?[*]u8, noalias src: ?[*]const u8, n: usize) callconv(.C) ?[*]u8
{
    @setRuntimeSafety(false);

    var index: usize = 0;
    while (index != n) : (index += 1)
        dest.?[index] = src.?[index];

    return dest;
}

export fn memmove(dest: ?[*]u8, src: ?[*]const u8, n: usize) callconv(.C) ?[*]u8
{
    @setRuntimeSafety(false);

    if (@ptrToInt(dest) < @ptrToInt(src)) {
        var index: usize = 0;
        while (index != n) : (index += 1) {
            dest.?[index] = src.?[index];
        }
    } else {
        var index = n;
        while (index != 0) {
            index -= 1;
            dest.?[index] = src.?[index];
        }
    }

    return dest;
}

export fn memcmp(vl: ?[*]const u8, vr: ?[*]const u8, n: usize) callconv(.C) c_int
{
    @setRuntimeSafety(false);

    var index: usize = 0;
    while (index != n) : (index += 1) {
        const compare_val = @bitCast(i8, vl.?[index] -% vr.?[index]);
        if (compare_val != 0) {
            return compare_val;
        }
    }

    return 0;
}

test "memcmp"
{
    const base_arr = &[_]u8{ 1, 1, 1 };
    const arr1 = &[_]u8{ 1, 1, 1 };
    const arr2 = &[_]u8{ 1, 0, 1 };
    const arr3 = &[_]u8{ 1, 2, 1 };

    try testing.expect(memcmp(base_arr[0..], arr1[0..], base_arr.len) == 0);
    try testing.expect(memcmp(base_arr[0..], arr2[0..], base_arr.len) > 0);
    try testing.expect(memcmp(base_arr[0..], arr3[0..], base_arr.len) < 0);
}

export fn bcmp(vl: [*]allowzero const u8, vr: [*]allowzero const u8, n: usize) callconv(.C) c_int
{
    @setRuntimeSafety(false);

    var index: usize = 0;
    while (index != n) : (index += 1) {
        if (vl[index] != vr[index]) {
            return 1;
        }
    }

    return 0;
}

test "bcmp"
{
    const base_arr = &[_]u8{ 1, 1, 1 };
    const arr1 = &[_]u8{ 1, 1, 1 };
    const arr2 = &[_]u8{ 1, 0, 1 };
    const arr3 = &[_]u8{ 1, 2, 1 };

    try testing.expect(bcmp(base_arr[0..], arr1[0..], base_arr.len) == 0);
    try testing.expect(bcmp(base_arr[0..], arr2[0..], base_arr.len) != 0);
    try testing.expect(bcmp(base_arr[0..], arr3[0..], base_arr.len) != 0);
}

// =====================
// MATH
// =====================

const math = std.math;

export fn fmodf(x: f32, y: f32) f32
{
    return generic_fmod(f32, x, y);
}

export fn fmod(x: f64, y: f64) f64
{
    return generic_fmod(f64, x, y);
}

export fn ceilf(x: f32) f32
{
    return math.ceil(x);
}

export fn ceil(x: f64) f64
{
    return math.ceil(x);
}

export fn ceill(x: c_longdouble) c_longdouble
{
    if (!long_double_is_f128) {
        @panic("TODO implement this");
    }
    return math.ceil(x);
}

export fn fmaf(a: f32, b: f32, c: f32) f32
{
    return math.fma(f32, a, b, c);
}

export fn fma(a: f64, b: f64, c: f64) f64
{
    return math.fma(f64, a, b, c);
}

export fn fmal(a: c_longdouble, b: c_longdouble, c: c_longdouble) c_longdouble
{
    if (!long_double_is_f128) {
        @panic("TODO implement this");
    }
    return math.fma(c_longdouble, a, b, c);
}

export fn sin(a: f64) f64
{
    return math.sin(a);
}

export fn sinf(a: f32) f32
{
    return math.sin(a);
}

export fn cos(a: f64) f64
{
    return math.cos(a);
}

export fn cosf(a: f32) f32
{
    return math.cos(a);
}

export fn sincos(a: f64, r_sin: *f64, r_cos: *f64) void
{
    r_sin.* = math.sin(a);
    r_cos.* = math.cos(a);
}

export fn sincosf(a: f32, r_sin: *f32, r_cos: *f32) void
{
    r_sin.* = math.sin(a);
    r_cos.* = math.cos(a);
}

export fn exp(a: f64) f64
{
    return math.exp(a);
}

export fn expf(a: f32) f32
{
    return math.exp(a);
}

export fn exp2(a: f64) f64
{
    return math.exp2(a);
}

export fn exp2f(a: f32) f32
{
    return math.exp2(a);
}

export fn log(a: f64) f64
{
    return math.ln(a);
}

export fn logf(a: f32) f32
{
    return math.ln(a);
}

export fn log2(a: f64) f64
{
    return math.log2(a);
}

export fn log2f(a: f32) f32
{
    return math.log2(a);
}

export fn log10(a: f64) f64
{
    return math.log10(a);
}

export fn log10f(a: f32) f32
{
    return math.log10(a);
}

export fn fabs(a: f64) f64
{
    return math.fabs(a);
}

export fn fabsf(a: f32) f32
{
    return math.fabs(a);
}

export fn trunc(a: f64) f64
{
    return math.trunc(a);
}

export fn truncf(a: f32) f32
{
    return math.trunc(a);
}

export fn truncl(a: c_longdouble) c_longdouble
{
    if (!long_double_is_f128) {
        @panic("TODO implement this");
    }
    return math.trunc(a);
}

export fn round(a: f64) f64
{
    return math.round(a);
}

export fn roundf(a: f32) f32
{
    return math.round(a);
}

export fn powf(a: f32, b: f32) f32
{
    return math.pow(f32, a, b);
}

export fn pow(a: f64, b: f64) f64
{
    return math.pow(f64, a, b);
}

export fn acosf(a: f32) f32
{
    return math.acos(a);
}

export fn atan2f(a: f32, b: f32) f32
{
    return math.atan2(f32, a, b);
}

export fn abs(a: i32) i32
{
    return math.absInt(a) catch unreachable;
}

fn generic_fmod(comptime T: type, x: T, y: T) T
{
    @setRuntimeSafety(false);

    const bits = @typeInfo(T).Float.bits;
    const uint = std.meta.Int(.unsigned, bits);
    const log2uint = math.Log2Int(uint);
    const digits = if (T == f32) 23 else 52;
    const exp_bits = if (T == f32) 9 else 12;
    const bits_minus_1 = bits - 1;
    const mask = if (T == f32) 0xff else 0x7ff;
    var ux = @bitCast(uint, x);
    var uy = @bitCast(uint, y);
    var ex = @intCast(i32, (ux >> digits) & mask);
    var ey = @intCast(i32, (uy >> digits) & mask);
    const sx = if (T == f32) @intCast(u32, ux & 0x80000000) else @intCast(i32, ux >> bits_minus_1);
    var i: uint = undefined;

    if (uy << 1 == 0 or isNan(@bitCast(T, uy)) or ex == mask)
        return (x * y) / (x * y);

    if (ux << 1 <= uy << 1) {
        if (ux << 1 == uy << 1)
            return 0 * x;
        return x;
    }

    // normalize x and y
    if (ex == 0) {
        i = ux << exp_bits;
        while (i >> bits_minus_1 == 0) : ({
            ex -= 1;
            i <<= 1;
        }) {}
        ux <<= @intCast(log2uint, @bitCast(u32, -ex + 1));
    } else {
        ux &= maxInt(uint) >> exp_bits;
        ux |= 1 << digits;
    }
    if (ey == 0) {
        i = uy << exp_bits;
        while (i >> bits_minus_1 == 0) : ({
            ey -= 1;
            i <<= 1;
        }) {}
        uy <<= @intCast(log2uint, @bitCast(u32, -ey + 1));
    } else {
        uy &= maxInt(uint) >> exp_bits;
        uy |= 1 << digits;
    }

    // x mod y
    while (ex > ey) : (ex -= 1) {
        i = ux -% uy;
        if (i >> bits_minus_1 == 0) {
            if (i == 0)
                return 0 * x;
            ux = i;
        }
        ux <<= 1;
    }
    i = ux -% uy;
    if (i >> bits_minus_1 == 0) {
        if (i == 0)
            return 0 * x;
        ux = i;
    }
    while (ux >> digits == 0) : ({
        ux <<= 1;
        ex -= 1;
    }) {}

    // scale result up
    if (ex > 0) {
        ux -%= 1 << digits;
        ux |= @as(uint, @bitCast(u32, ex)) << digits;
    } else {
        ux >>= @intCast(log2uint, @bitCast(u32, -ex + 1));
    }
    if (T == f32) {
        ux |= sx;
    } else {
        ux |= @intCast(uint, sx) << bits_minus_1;
    }
    return @bitCast(T, ux);
}

test "fmod, fmodf"
{
    inline for ([_]type{ f32, f64 }) |T| {
        const nan_val = math.nan(T);
        const inf_val = math.inf(T);

        try testing.expect(isNan(generic_fmod(T, nan_val, 1.0)));
        try testing.expect(isNan(generic_fmod(T, 1.0, nan_val)));
        try testing.expect(isNan(generic_fmod(T, inf_val, 1.0)));
        try testing.expect(isNan(generic_fmod(T, 0.0, 0.0)));
        try testing.expect(isNan(generic_fmod(T, 1.0, 0.0)));

        try testing.expectEqual(@as(T, 0.0), generic_fmod(T, 0.0, 2.0));
        try testing.expectEqual(@as(T, -0.0), generic_fmod(T, -0.0, 2.0));

        try testing.expectEqual(@as(T, -2.0), generic_fmod(T, -32.0, 10.0));
        try testing.expectEqual(@as(T, -2.0), generic_fmod(T, -32.0, -10.0));
        try testing.expectEqual(@as(T, 2.0), generic_fmod(T, 32.0, 10.0));
        try testing.expectEqual(@as(T, 2.0), generic_fmod(T, 32.0, -10.0));
    }
}

fn generic_fmin(comptime T: type, x: T, y: T) T
{
    if (isNan(x))
        return y;
    if (isNan(y))
        return x;
    return if (x < y) x else y;
}

export fn fminf(x: f32, y: f32) f32
{
    return generic_fmin(f32, x, y);
}

export fn fmin(x: f64, y: f64) f64
{
    return generic_fmin(f64, x, y);
}

test "fmin, fminf"
{
    inline for ([_]type{ f32, f64 }) |T| {
        const nan_val = math.nan(T);

        try testing.expect(isNan(generic_fmin(T, nan_val, nan_val)));
        try testing.expectEqual(@as(T, 1.0), generic_fmin(T, nan_val, 1.0));
        try testing.expectEqual(@as(T, 1.0), generic_fmin(T, 1.0, nan_val));

        try testing.expectEqual(@as(T, 1.0), generic_fmin(T, 1.0, 10.0));
        try testing.expectEqual(@as(T, -1.0), generic_fmin(T, 1.0, -1.0));
    }
}

fn generic_fmax(comptime T: type, x: T, y: T) T
{
    if (isNan(x))
        return y;
    if (isNan(y))
        return x;
    return if (x < y) y else x;
}

export fn fmaxf(x: f32, y: f32) callconv(.C) f32
{
    return generic_fmax(f32, x, y);
}

export fn fmax(x: f64, y: f64) callconv(.C) f64
{
    return generic_fmax(f64, x, y);
}

test "fmax, fmaxf"
{
    inline for ([_]type{ f32, f64 }) |T| {
        const nan_val = math.nan(T);

        try testing.expect(isNan(generic_fmax(T, nan_val, nan_val)));
        try testing.expectEqual(@as(T, 1.0), generic_fmax(T, nan_val, 1.0));
        try testing.expectEqual(@as(T, 1.0), generic_fmax(T, 1.0, nan_val));

        try testing.expectEqual(@as(T, 10.0), generic_fmax(T, 1.0, 10.0));
        try testing.expectEqual(@as(T, 1.0), generic_fmax(T, 1.0, -1.0));
    }
}

// NOTE: The original code is full of implicit signed -> unsigned assumptions and u32 wraparound
// behaviour. Most intermediate i32 values are changed to u32 where appropriate but there are
// potentially some edge cases remaining that are not handled in the same way.
export fn sqrt(x: f64) f64 
{
    const tiny: f64 = 1.0e-300;
    const sign: u32 = 0x80000000;
    const u = @bitCast(u64, x);

    var ix0 = @intCast(u32, u >> 32);
    var ix1 = @intCast(u32, u & 0xFFFFFFFF);

    // sqrt(nan) = nan, sqrt(+inf) = +inf, sqrt(-inf) = nan
    if (ix0 & 0x7FF00000 == 0x7FF00000) {
        return x * x + x;
    }

    // sqrt(+-0) = +-0
    if (x == 0.0) {
        return x;
    }
    // sqrt(-ve) = snan
    if (ix0 & sign != 0) {
        return math.snan(f64);
    }

    // normalize x
    var m = @intCast(i32, ix0 >> 20);
    if (m == 0) {
        // subnormal
        while (ix0 == 0) {
            m -= 21;
            ix0 |= ix1 >> 11;
            ix1 <<= 21;
        }

        // subnormal
        var i: u32 = 0;
        while (ix0 & 0x00100000 == 0) : (i += 1) {
            ix0 <<= 1;
        }
        m -= @intCast(i32, i) - 1;
        ix0 |= ix1 >> @intCast(u5, 32 - i);
        ix1 <<= @intCast(u5, i);
    }

    // unbias exponent
    m -= 1023;
    ix0 = (ix0 & 0x000FFFFF) | 0x00100000;
    if (m & 1 != 0) {
        ix0 += ix0 + (ix1 >> 31);
        ix1 = ix1 +% ix1;
    }
    m >>= 1;

    // sqrt(x) bit by bit
    ix0 += ix0 + (ix1 >> 31);
    ix1 = ix1 +% ix1;

    var q: u32 = 0;
    var q1: u32 = 0;
    var s0: u32 = 0;
    var s1: u32 = 0;
    var r: u32 = 0x00200000;
    var t: u32 = undefined;
    var t1: u32 = undefined;

    while (r != 0) {
        t = s0 +% r;
        if (t <= ix0) {
            s0 = t + r;
            ix0 -= t;
            q += r;
        }
        ix0 = ix0 +% ix0 +% (ix1 >> 31);
        ix1 = ix1 +% ix1;
        r >>= 1;
    }

    r = sign;
    while (r != 0) {
        t1 = s1 +% r;
        t = s0;
        if (t < ix0 or (t == ix0 and t1 <= ix1)) {
            s1 = t1 +% r;
            if (t1 & sign == sign and s1 & sign == 0) {
                s0 += 1;
            }
            ix0 -= t;
            if (ix1 < t1) {
                ix0 -= 1;
            }
            ix1 = ix1 -% t1;
            q1 += r;
        }
        ix0 = ix0 +% ix0 +% (ix1 >> 31);
        ix1 = ix1 +% ix1;
        r >>= 1;
    }

    // rounding direction
    if (ix0 | ix1 != 0) {
        var z = 1.0 - tiny; // raise inexact
        if (z >= 1.0) {
            z = 1.0 + tiny;
            if (q1 == 0xFFFFFFFF) {
                q1 = 0;
                q += 1;
            } else if (z > 1.0) {
                if (q1 == 0xFFFFFFFE) {
                    q += 1;
                }
                q1 += 2;
            } else {
                q1 += q1 & 1;
            }
        }
    }

    ix0 = (q >> 1) + 0x3FE00000;
    ix1 = q1 >> 1;
    if (q & 1 != 0) {
        ix1 |= 0x80000000;
    }

    // NOTE: musl here appears to rely on signed twos-complement wraparound. +% has the same
    // behaviour at least.
    var iix0 = @intCast(i32, ix0);
    iix0 = iix0 +% (m << 20);

    const uz = (@intCast(u64, iix0) << 32) | ix1;
    return @bitCast(f64, uz);
}

test "sqrt" 
{
    const V = [_]f64{
        0.0,
        4.089288054930154,
        7.538757127071935,
        8.97780793672623,
        5.304443821913729,
        5.682408965311888,
        0.5846878579110049,
        3.650338664297043,
        0.3178091951800732,
        7.1505232436382835,
        3.6589165881946464,
    };

    // Note that @sqrt will either generate the sqrt opcode (if supported by the
    // target ISA) or a call to `sqrtf` otherwise.
    for (V) |val|
        try testing.expectEqual(@sqrt(val), sqrt(val));
}

test "sqrt special" 
{
    try testing.expect(std.math.isPositiveInf(sqrt(std.math.inf(f64))));
    try testing.expect(sqrt(0.0) == 0.0);
    try testing.expect(sqrt(-0.0) == -0.0);
    try testing.expect(isNan(sqrt(-1.0)));
    try testing.expect(isNan(sqrt(std.math.nan(f64))));
}

export fn sqrtf(x: f32) f32
{
    const tiny: f32 = 1.0e-30;
    const sign: i32 = @bitCast(i32, @as(u32, 0x80000000));
    var ix: i32 = @bitCast(i32, x);

    if ((ix & 0x7F800000) == 0x7F800000) {
        return x * x + x; // sqrt(nan) = nan, sqrt(+inf) = +inf, sqrt(-inf) = snan
    }

    // zero
    if (ix <= 0) {
        if (ix & ~sign == 0) {
            return x; // sqrt (+-0) = +-0
        }
        if (ix < 0) {
            return math.snan(f32);
        }
    }

    // normalize
    var m = ix >> 23;
    if (m == 0) {
        // subnormal
        var i: i32 = 0;
        while (ix & 0x00800000 == 0) : (i += 1) {
            ix <<= 1;
        }
        m -= i - 1;
    }

    m -= 127; // unbias exponent
    ix = (ix & 0x007FFFFF) | 0x00800000;

    if (m & 1 != 0) { // odd m, double x to even
        ix += ix;
    }

    m >>= 1; // m = [m / 2]

    // sqrt(x) bit by bit
    ix += ix;
    var q: i32 = 0; // q = sqrt(x)
    var s: i32 = 0;
    var r: i32 = 0x01000000; // r = moving bit right -> left

    while (r != 0) {
        const t = s + r;
        if (t <= ix) {
            s = t + r;
            ix -= t;
            q += r;
        }
        ix += ix;
        r >>= 1;
    }

    // floating add to find rounding direction
    if (ix != 0) {
        var z = 1.0 - tiny; // inexact
        if (z >= 1.0) {
            z = 1.0 + tiny;
            if (z > 1.0) {
                q += 2;
            } else {
                if (q & 1 != 0) {
                    q += 1;
                }
            }
        }
    }

    ix = (q >> 1) + 0x3f000000;
    ix += m << 23;
    return @bitCast(f32, ix);
}

test "sqrtf"
{
    const V = [_]f32{
        0.0,
        4.089288054930154,
        7.538757127071935,
        8.97780793672623,
        5.304443821913729,
        5.682408965311888,
        0.5846878579110049,
        3.650338664297043,
        0.3178091951800732,
        7.1505232436382835,
        3.6589165881946464,
    };

    // Note that @sqrt will either generate the sqrt opcode (if supported by the
    // target ISA) or a call to `sqrtf` otherwise.
    for (V) |val|
        try std.testing.expectEqual(@sqrt(val), sqrtf(val));
}

test "sqrtf special"
{
    try std.testing.expect(std.math.isPositiveInf(sqrtf(std.math.inf(f32))));
    try std.testing.expect(sqrtf(0.0) == 0.0);
    try std.testing.expect(sqrtf(-0.0) == -0.0);
    try std.testing.expect(isNan(sqrtf(-1.0)));
    try std.testing.expect(isNan(sqrtf(std.math.nan(f32))));
}

export fn atof(str: ?[*:0]const u8) f64
{
    return std.fmt.parseFloat(f64, std.mem.sliceTo(str.?, 0)) catch unreachable;
}

// ========================
// SSP
// ========================

export fn __stack_chk_fail() callconv(.C) noreturn
{
    @panic("stack smashing detected");
}

export fn __chk_fail() callconv(.C) noreturn
{
    @panic("buffer overflow detected");
}

// Emitted when targeting some architectures (eg. i386)
// XXX: This symbol should be hidden
export fn __stack_chk_fail_local() callconv(.C) noreturn
{
    __stack_chk_fail();
}

// XXX: Initialize the canary with random data
export var __stack_chk_guard: usize = blk: {
    var buf = [1]u8{0} ** @sizeOf(usize);
    buf[@sizeOf(usize) - 1] = 255;
    buf[@sizeOf(usize) - 2] = '\n';
    break :blk @bitCast(usize, buf);
};

export fn __strcpy_chk(dest: [*:0]u8, src: [*:0]const u8, dest_n: usize) callconv(.C) [*:0]u8
{
    @setRuntimeSafety(false);

    var i: usize = 0;
    while (i < dest_n and src[i] != 0) : (i += 1) {
        dest[i] = src[i];
    }

    if (i == dest_n) __chk_fail();

    dest[i] = 0;

    return dest;
}

export fn __strncpy_chk(dest: [*:0]u8, src: [*:0]const u8, n: usize, dest_n: usize) callconv(.C) [*:0]u8
{
    if (dest_n < n) __chk_fail();
    return strncpy(dest, src, n);
}

export fn __strcat_chk(dest: [*:0]u8, src: [*:0]const u8, dest_n: usize) callconv(.C) [*:0]u8
{
    @setRuntimeSafety(false);

    var avail = dest_n;

    var dest_end: usize = 0;
    while (avail > 0 and dest[dest_end] != 0) : (dest_end += 1) {
        avail -= 1;
    }

    if (avail < 1) __chk_fail();

    var i: usize = 0;
    while (avail > 0 and src[i] != 0) : (i += 1) {
        dest[dest_end + i] = src[i];
        avail -= 1;
    }

    if (avail < 1) __chk_fail();

    dest[dest_end + i] = 0;

    return dest;
}

export fn __strncat_chk(dest: [*:0]u8, src: [*:0]const u8, n: usize, dest_n: usize) callconv(.C) [*:0]u8
{
    @setRuntimeSafety(false);

    var avail = dest_n;

    var dest_end: usize = 0;
    while (avail > 0 and dest[dest_end] != 0) : (dest_end += 1) {
        avail -= 1;
    }

    if (avail < 1) __chk_fail();

    var i: usize = 0;
    while (avail > 0 and i < n and src[i] != 0) : (i += 1) {
        dest[dest_end + i] = src[i];
        avail -= 1;
    }

    if (avail < 1) __chk_fail();

    dest[dest_end + i] = 0;

    return dest;
}

export fn __memcpy_chk(noalias dest: ?[*]u8, noalias src: ?[*]const u8, n: usize, dest_n: usize) callconv(.C) ?[*]u8
{
    if (dest_n < n) __chk_fail();
    return memcpy(dest, src, n);
}

export fn __memmove_chk(dest: ?[*]u8, src: ?[*]const u8, n: usize, dest_n: usize) callconv(.C) ?[*]u8
{
    if (dest_n < n) __chk_fail();
    return memmove(dest, src, n);
}

export fn __memset_chk(dest: ?[*]u8, c: u8, n: usize, dest_n: usize) callconv(.C) ?[*]u8
{
    if (dest_n < n) __chk_fail();
    return memset(dest, c, n);
}

export fn __assert_fail(assertion: ?[*:0]const u8, file: ?[*:0]const u8, line: u32, function: ?[*:0]const u8) void
{
    _ = assertion;
    _ = file;
    _ = line;
    _ = function;
    std.log.err("{s} -- {s}:{d}", .{assertion.?, file.?, line});
    @panic("assert fail");
}

// ========================
// QSORT
// ========================

const QuicksortComparisonSignature = fn(left: *u8, right: *u8) callconv(.C) i32;

pub fn qsort(base: [*c]u8, count: usize, elem_size: usize, compar_fn: QuicksortComparisonSignature) void
{
    quicksort(base, elem_size, @intCast(i64, 0), @intCast(i64, count), compar_fn);
}

fn quicksortComparAscendingU8(left: *u8, right: *u8) callconv(.C) i32
{
    return @intCast(i32, left.*) - @intCast(i32, right.*);
}

fn quicksortComparAscendingI32(left: *u8, right: *u8) callconv(.C) i32
{
    var left_int = @ptrCast(*i32, @alignCast(@alignOf(i32), left)).*;
    var right_int = @ptrCast(*i32, @alignCast(@alignOf(i32), right)).*;
    return left_int - right_int;
}

fn quicksort(ptr: [*]u8, elem_size: usize, low: i64, high: i64, compar_fn: QuicksortComparisonSignature) void
{
    if (low < high)
    {
        var idx = quicksortPartition(ptr, elem_size, low, high, compar_fn);
        quicksort(ptr, elem_size, low, idx - 1, compar_fn);
        quicksort(ptr, elem_size, idx + 1, high, compar_fn);
    }
}

fn quicksortPartition(ptr: [*]u8, elem_size: usize, low: i64, high: i64, compar_fn: QuicksortComparisonSignature) i64
{
    var pivot = &ptr[@intCast(usize, high)*elem_size];
    var i: i64 = low - 1;
    var j = low;
    while (j <= high) : (j += 1) {
        if (compar_fn(&ptr[@intCast(usize, j) * elem_size], pivot) < 0) {
            i += 1;
            quicksortSwap(ptr, elem_size, @intCast(usize, i), @intCast(usize, j));
        }
    }
    quicksortSwap(ptr, elem_size, @intCast(usize, i + 1), @intCast(usize, high));
    return i + 1;
}

fn quicksortSwap(ptr: [*]u8, elem_size: usize, left: usize, right: usize) void
{
    if (elem_size == 1)
    {
        var tmp = ptr[left];
        ptr[left] = ptr[right];
        ptr[right] = tmp;  
    }
    else
    {
        var tmp = heap.page_allocator.alloc(u8, elem_size) catch unreachable;
        defer heap.page_allocator.free(tmp);

        var i: usize = 0;
        while (i < elem_size) : (i += 1) {
            tmp[i] = ptr[left * elem_size + i];
        }

        i = 0;
        while (i < elem_size) : (i += 1) {
            ptr[left * elem_size + i] = ptr[right * elem_size + i];
        }

        i = 0;
        while (i < elem_size) : (i += 1) {
            ptr[right * elem_size + i] = tmp[i];
        }
    }
}

test "quicksort u8" 
{
    var input = [_]u8{ 5, 2, 3, 5, 1, 2, 255, 65};
    quicksort(&input, @sizeOf(u8), 0, input.len - 1, quicksortComparAscendingU8);
    try testing.expectEqual(input, [_]u8{1,2,2,3,5,5,65,255});
}

test "quicksort i32"
{
    var input = [_]i32{ 5, -2, 3, -5, 1, 2, 255, 65};
    quicksort(@ptrCast([*]u8, &input), @sizeOf(i32), 0, input.len - 1, quicksortComparAscendingI32);
    try testing.expectEqual(input, [_]i32{-5,-2,1,2,3,5,65,255});
}