const std = @import("std");
const NATIVE_ARCH = @import("builtin").target.cpu.arch;
pub const OS = @import("builtin").target.os.tag;
pub const IS_WEB = (NATIVE_ARCH == .wasm32);
pub const IS_DESKTOP = (NATIVE_ARCH != .wasm32);
const NullStruct = struct {};

pub usingnamespace if (IS_WEB) @import("wasm_runtime/freestanding.zig") else NullStruct;
pub const web = if (IS_WEB) @import("wasm_runtime/web.zig") else NullStruct;
pub const os = if (IS_WEB) @import("wasm_runtime/wasm_os.zig") else std.os;
pub const log = if (IS_WEB) web.log else std.log.defaultLog;
pub const panic = if (IS_WEB) web.panic else std.builtin.default_panic;

