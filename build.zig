const std = @import("std");
const glfw = @import("lib/mach-glfw/build.zig");
const OpenGl = @import("src/opengl_externs.zig");

pub fn build(b: *std.build.Builder) !void
{
    const mode = b.standardReleaseOptions();

    { // Write OpenGL bindings to file.
        const file = try std.fs.cwd().createFile(
            "opengl_generated.zig",
            .{ .read = true },
        );
        defer file.close();
        _ = try file.write("pub const Gl = @import(\"src/opengl_externs.zig\");\n");
        inline for (@typeInfo(OpenGl.Functions).Struct.decls) |decl|
        {
            _ = try file.write("pub var ");
            var output: [128]u8 = undefined;
            const output_size = std.mem.replacementSize(u8, decl.name, "gl", "");
            _ = std.mem.replace(u8, decl.name, "gl", "", output[0..]);
            _ = try file.write(output[0..output_size]);
            _ = try file.write(" = Gl.Functions.");
            _ = try file.write(decl.name);
            _ = try file.write(";\n");
        }
    }
    
    // DESKTOP
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable("zig_graphics", "main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addPackagePath("glfw", "lib/mach-glfw/src/main.zig");
    exe.addPackagePath("opengl_bindings", "opengl_generated.zig");
    exe.addIncludeDir("include/");
    switch (target.getOsTag()) {
        .windows => {
            exe.linkSystemLibrary("opengl32");
        },
        .linux => {
            exe.linkSystemLibrary("GL");
        },
        .macos => {
            exe.linkFramework("OpenGL");
        },
        else => {
            @panic("Unsupported os.");
        }
    }
    exe.install();
    glfw.link(b, exe, .{});
    b.getInstallStep().dependOn(&exe.step);

    // WASM
    const web = b.addSharedLibrary("zig_graphics_web", "main.zig", .unversioned);
    web.setTarget(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding
    });
    web.setBuildMode(mode);
    web.linkLibC();
    web.addPackagePath("opengl_bindings", "opengl_generated.zig");
    web.addIncludeDir("include");
    web.setOutputDir("docs/");
    web.install();
    b.getInstallStep().dependOn(&web.step);
}