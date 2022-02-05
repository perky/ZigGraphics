const log = @import("std").log;
const math = @import("std").math;
const fmt = @import("std").fmt;
const mem = @import("std").mem;

export fn ImSqrt(val: f32) f32 { return @sqrt(val); }
export fn ImSin(val: f32) f32 { return @sin(val); }
export fn ImCos(val: f32) f32 { return @cos(val); }
export fn ImFabs(val: f32) f32 { return @fabs(val); }
export fn ImCeil(val: f32) f32 { return @ceil(val); }
export fn ImFloorStd(val: f32) f32 { return @floor(val); }
export fn ImAcos(val: f32) f32 { return math.acos(val); }
export fn ImAtan2(y: f32, x: f32) f32 { return math.atan2(f32, y, x); }
export fn ImFmod(a: f32, b: f32) f32 { return @mod(a, b); }
export fn ImPowF32(a: f32, b: f32) f32 { return math.pow(f32, a, b); }
export fn ImPowF64(a: f64, b: f64) f64 { return math.pow(f64, a, b); }
export fn ImAtof(cstr: [*c]const u8) f32
{
    const str = mem.sliceTo(cstr, 0);
    return fmt.parseFloat(f32, str) catch unreachable;
}

//IMGUI_API int           ImFormatString(char* buf, size_t buf_size, const char* fmt, ...) IM_FMTARGS(3);
//IMGUI_API int           ImFormatStringV(char* buf, size_t buf_size, const char* fmt, va_list args) IM_FMTLIST(3);
// pub export fn ImFormatString(buf: [*c]u8, buf_size: usize, format: [*c]const u8, args: [*c]u8) i32
// {
//     var bufSlice = buf[0..buf_size];
//     const formatSlice = mem.sliceTo(format, 0);
//     // const argsSlice = mem.sliceTo(args, 0);
//     log.info("ImFormatString [{s}], [{d}], [{s}]\n", .{bufSlice, buf_size, formatSlice});
//     _ = buf;
//     _ = buf_size;
//     _ = format;
//     _ = args;


//     const result = fmt.bufPrint(bufSlice, formatSlice, args) catch unreachable;
//     log.info("ImFormatString::result {s}\n", .{result});
//     return 0;
// }

// pub export fn ImFormatStringV(buf: [*c]u8, buf_size: usize, format: [*c]const u8, args: [*c]u8) i32
// {
//     const bufSlice = mem.sliceTo(buf, 0);
//     const formatSlice = mem.sliceTo(format, 0);
//     const argsSlice = mem.sliceTo(args, 0);
//     log.info("ImFormatStringV [{s}], [{d}], [{s}], [{s}]\n", .{bufSlice, buf_size, formatSlice, argsSlice});
//     _ = buf;
//     _ = buf_size;
//     _ = format;
//     _ = args;
//     return 0;
// }