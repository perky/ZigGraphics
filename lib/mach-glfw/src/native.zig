//! Native access functions
const std = @import("std");

const Window = @import("Window.zig");
const Monitor = @import("Monitor.zig");
const Error = @import("errors.zig").Error;
const getError = @import("errors.zig").getError;

const internal_debug = @import("internal_debug.zig");

const BackendOptions = struct {
    win32: bool = false,
    wgl: bool = false,
    cocoa: bool = false,
    nsgl: bool = false,
    x11: bool = false,
    glx: bool = false,
    wayland: bool = false,
    egl: bool = false,
    osmesa: bool = false,
};

/// This function returns a type which allows provides an interface to access 
/// the native handles based on backends selected.
///
/// The available window API options are:
/// * win32
/// * cocoa
/// * x11
/// * wayland
///
/// The available context API options are:
///
/// * wgl
/// * nsgl
/// * glx
/// * egl
/// * osmesa
///
/// The chosen backends must match those the library was compiled for. Failure to do so
/// will cause a link-time error.
pub fn Native(comptime options: BackendOptions) type {
    const native = @cImport({
        @cDefine("GLFW_INCLUDE_VULKAN", "1");
        @cInclude("GLFW/glfw3.h");

        if (options.win32) @cDefine("GLFW_EXPOSE_NATIVE_WIN32", "1");
        if (options.wgl) @cDefine("GLFW_EXPOSE_NATIVE_WGL", "1");
        if (options.cocoa) @cDefine("GLFW_EXPOSE_NATIVE_COCOA", "1");
        if (options.nsgl) @cDefine("GLFW_EXPOSE_NATIVE_NGSL", "1");
        if (options.x11) @cDefine("GLFW_EXPOSE_NATIVE_X11", "1");
        if (options.glx) @cDefine("GLFW_EXPOSE_NATIVE_GLX", "1");
        if (options.wayland) @cDefine("GLFW_EXPOSE_NATIVE_WAYLAND", "1");
        if (options.egl) @cDefine("GLFW_EXPOSE_NATIVE_EGL", "1");
        if (options.osmesa) @cDefine("GLFW_EXPOSE_NATIVE_OSMESA", "1");
        @cInclude("GLFW/glfw3native.h");
    });

    return struct {
        /// Returns the adapter device name of the specified monitor.
        ///
        /// return: The UTF-8 encoded adapter device name (for example `\\.\DISPLAY1`) of the
        /// specified monitor.
        ///
        /// Possible errors include glfw.Error.NotInitalized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getWin32Adapter(monitor: Monitor) [*:0]const u8 {
            internal_debug.assertInitialized();
            const adapter = native.glfwGetWin32Adapter(@ptrCast(*native.GLFWmonitor, monitor.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                else => unreachable,
            };
            return adapter;
        }

        /// Returns the display device name of the specified monitor.
        ///
        /// return: The UTF-8 encoded display device name (for example `\\.\DISPLAY1\Monitor0`) 
        /// of the specified monitor.
        ///
        /// Possible errors include glfw.Error.NotInitalized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getWin32Monitor(monitor: Monitor) [*:0]const u8 {
            internal_debug.assertInitialized();
            const mon = native.glfwWin32Monitor(@ptrCast(*native.GLFWmonitor, monitor.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                else => unreachable,
            };
            return mon;
        }

        /// Returns the `HWND` of the specified window.
        ///
        /// The `HDC` associated with the window can be queried with the
        /// [GetDC](https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getdc)
        /// function.
        /// ```
        /// const dc = std.os.windows.user32.GetDC(native.getWin32Window(window));
        /// ```
        /// This DC is private and does not need to be released.
        ///
        /// Possible errors include glfw.Error.NotInitalized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getWin32Window(window: Window) std.os.windows.HWND {
            internal_debug.assertInitialized();
            const win = native.glfwGetWin32Window(@ptrCast(*native.GLFWwindow, window.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                else => unreachable,
            };
            return @ptrCast(std.os.windows.HWND, win);
        }

        /// Returns the `HGLRC` of the specified window.
        ///
        /// The `HDC` associated with the window can be queried with the
        /// [GetDC](https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getdc)
        /// function.
        /// ```
        /// const dc = std.os.windows.user32.GetDC(native.getWin32Window(window));
        /// ```
        /// This DC is private and does not need to be released.
        ///
        /// Possible errors include glfw.Error.NotInitalized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getWGLContext(window: Window) error{NoWindowContext}!std.os.windows.HGLRC {
            internal_debug.assertInitialized();
            const context = native.glfwGetWGLContext(@ptrCast(*native.GLFWwindow, window.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                Error.NoWindowContext => |e| @errSetCast(error{NoWindowContext}, e),
                else => unreachable,
            };
            return context;
        }

        /// Returns the `CGDirectDisplayID` of the specified monitor.
        ///
        /// Possible errors include glfw.Error.NotInitalized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getCocoaMonitor(monitor: Monitor) u32 {
            internal_debug.assertInitialized();
            const mon = native.glfwGetCocoaMonitor(@ptrCast(*native.GLFWmonitor, monitor.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                else => unreachable,
            };
            return mon;
        }

        /// Returns the `NSWindow` of the specified window.
        ///
        /// Possible errors include glfw.Error.NotInitalized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getCocoaWindow(window: Window) u32 {
            internal_debug.assertInitialized();
            const win = native.glfwGetCocoaWindow(@ptrCast(*native.GLFWwindow, window.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                else => unreachable,
            };
            return win;
        }

        /// Returns the `NSWindow` of the specified window.
        ///
        /// Possible errors include glfw.Error.NotInitialized, glfw.Error.NoWindowContext.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getNSGLContext(window: Window) error{NoWindowContext}!u32 {
            internal_debug.assertInitialized();
            const context = native.glfwGetNSGLContext(@ptrCast(*native.GLFWwindow, window.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                Error.NoWindowContext => |e| @errSetCast(error{NoWindowContext}, e),
                else => unreachable,
            };
            return context;
        }

        /// Returns the `Display` used by GLFW.
        ///
        /// Possible errors include glfw.Error.NotInitalized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getX11Display() *anyopaque {
            internal_debug.assertInitialized();
            const display = native.glfwGetX11Display();
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                else => unreachable,
            };
            return @ptrCast(*anyopaque, display);
        }

        /// Returns the `RRCrtc` of the specified monitor.
        ///
        /// Possible errors include glfw.Error.NotInitalized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getX11Adapter(monitor: Monitor) u32 {
            internal_debug.assertInitialized();
            const adapter = native.glfwGetX11Adapter(@ptrCast(*native.GLFWMonitor, monitor.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                else => unreachable,
            };
            return adapter;
        }

        /// Returns the `RROutput` of the specified monitor.
        ///
        /// Possible errors include glfw.Error.NotInitalized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getX11Monitor(monitor: Monitor) u32 {
            internal_debug.assertInitialized();
            const mon = native.glfwGetX11Monitor(@ptrCast(*native.GLFWmonitor, monitor.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                else => unreachable,
            };
            return mon;
        }

        /// Returns the `Window` of the specified window.
        ///
        /// Possible errors include glfw.Error.NotInitalized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getX11Window(window: Window) u32 {
            internal_debug.assertInitialized();
            const win = native.glfwGetX11Window(@ptrCast(*native.GLFWwindow, window.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                else => unreachable,
            };
            return @intCast(u32, win);
        }

        /// Sets the current primary selection to the specified string.
        ///
        /// Possible errors include glfw.Error.NotInitialized and glfw.Error.PlatformError.
        ///
        /// The specified string is copied before this function returns.
        ///
        /// thread_safety: This function must only be called from the main thread.
        pub fn setX11SelectionString(string: [*:0]const u8) error{PlatformError}!void {
            internal_debug.assertInitialized();
            native.glfwSetX11SelectionString(string);
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                Error.PlatformError => |e| @errSetCast(error{PlatformError}, e),
                else => unreachable,
            };
        }

        /// Returns the contents of the current primary selection as a string.
        ///
        /// Possible errors include glfw.Error.NotInitialized and glfw.Error.PlatformError.
        ///
        /// The returned string is allocated and freed by GLFW. You should not free it
        /// yourself. It is valid until the next call to getX11SelectionString or 
        /// setX11SelectionString, or until the library is terminated.
        ///
        /// thread_safety: This function must only be called from the main thread.
        pub fn getX11SelectionString() error{FormatUnavailable}![*:0]const u8 {
            internal_debug.assertInitialized();
            const str = native.glfwGetX11SelectionString();
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                Error.FormatUnavailable => |e| @errSetCast(error{FormatUnavailable}, e),
                else => unreachable,
            };
            return str;
        }

        /// Returns the `GLXContext` of the specified window.
        ///
        /// Possible errors include glfw.Error.NoWindowContext and glfw.Error.NotInitialized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getGLXContext(window: Window) error{NoWindowContext}!*anyopaque {
            internal_debug.assertInitialized();
            const context = native.glfwGetGLXContext(@ptrCast(*native.GLFWwindow, window.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                Error.NoWindowContext => |e| @errSetCast(error{NoWindowContext}, e),
                else => unreachable,
            };
            return @ptrCast(*anyopaque, context);
        }

        /// Returns the `GLXWindow` of the specified window.
        ///
        /// Possible errors include glfw.Error.NoWindowContext and glfw.Error.NotInitialized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getGLXWindow(window: Window) error{NoWindowContext}!*anyopaque {
            internal_debug.assertInitialized();
            const win = native.glfwGetGLXWindow(@ptrCast(*native.GLFWwindow, window.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                Error.NoWindowContext => |e| @errSetCast(error{NoWindowContext}, e),
                else => unreachable,
            };
            return @ptrCast(*anyopaque, win);
        }

        /// Returns the `*wl_display` used by GLFW.
        ///
        /// Possible errors include glfw.Error.NotInitalized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getWaylandDisplay() *anyopaque {
            internal_debug.assertInitialized();
            const display = native.glfwGetWaylandDisplay();
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                else => unreachable,
            };
            return @ptrCast(*anyopaque, display);
        }

        /// Returns the `*wl_output` of the specified monitor.
        ///
        /// Possible errors include glfw.Error.NotInitalized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getWaylandMonitor(monitor: Monitor) *anyopaque {
            internal_debug.assertInitialized();
            const mon = native.glfwGetWaylandMonitor(@ptrCast(*native.GLFWmonitor, monitor.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                else => unreachable,
            };
            return @ptrCast(*anyopaque, mon);
        }

        /// Returns the `*wl_surface` of the specified window.
        ///
        /// Possible errors include glfw.Error.NotInitalized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getWaylandWindow(window: Window) *anyopaque {
            internal_debug.assertInitialized();
            const win = native.glfwGetWaylandWindow(@ptrCast(*native.GLFWwindow, window.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                else => unreachable,
            };
            return @ptrCast(*anyopaque, win);
        }

        /// Returns the `EGLDisplay` used by GLFW.
        ///
        /// Possible errors include glfw.Error.NotInitalized.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getEGLDisplay() *anyopaque {
            internal_debug.assertInitialized();
            const display = native.glfwGetEGLDisplay();
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                else => unreachable,
            };
            return @ptrCast(*anyopaque, display);
        }

        /// Returns the `EGLContext` of the specified window.
        ///
        /// Possible errors include glfw.Error.NotInitalized and glfw.Error.NoWindowContext.
        ///
        /// thread_safety This function may be called from any thread. Access is not synchronized.
        pub fn getEGLContext(window: Window) error{NoWindowContext}!*anyopaque {
            internal_debug.assertInitialized();
            const context = native.glfwGetEGLContext(@ptrCast(*native.GLFWwindow, window.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                Error.NoWindowContext => |e| @errSetCast(error{NoWindowContext}, e),
                else => unreachable,
            };
            return @ptrCast(*anyopaque, context);
        }

        /// Returns the `EGLSurface` of the specified window.
        ///
        /// Possible errors include glfw.Error.NotInitalized and glfw.Error.NoWindowContext.
        ///
        /// thread_safety This function may be called from any thread. Access is not synchronized.
        pub fn getEGLSurface(window: Window) error{NoWindowContext}!*anyopaque {
            internal_debug.assertInitialized();
            const surface = native.glfwGetEGLSurface(@ptrCast(*native.GLFWwindow, window.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                Error.NoWindowContext => |e| @errSetCast(error{NoWindowContext}, e),
                else => unreachable,
            };
            return @ptrCast(*anyopaque, surface);
        }

        pub const OSMesaColorBuffer = struct {
            width: c_int,
            height: c_int,
            format: c_int,
            buffer: *anyopaque,
        };

        /// Retrieves the color buffer associated with the specified window.
        ///
        /// Possible errors include glfw.Error.NotInitalized, glfw.Error.NoWindowContext
        /// and glfw.Error.PlatformError.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getOSMesaColorBuffer(window: Window) error{ PlatformError, NoWindowContext }!OSMesaColorBuffer {
            internal_debug.assertInitialized();
            var buf: OSMesaColorBuffer = undefined;
            _ = native.glfwGetOSMesaColorBuffer(@ptrCast(*native.GLFWwindow, window.handle), &buf.width, &buf.height, &buf.format, &buf.buffer);
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                Error.PlatformError, Error.NoWindowContext => |e| @errSetCast(error{ PlatformError, NoWindowContext }, e),
                else => unreachable,
            };
            return buf;
        }

        pub const OSMesaDepthBuffer = struct {
            width: c_int,
            height: c_int,
            bytes_per_value: c_int,
            buffer: *anyopaque,
        };

        /// Retrieves the depth buffer associated with the specified window.
        ///
        /// Possible errors include glfw.Error.NotInitalized, glfw.Error.NoWindowContext
        /// and glfw.Error.PlatformError.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getOSMesaDepthBuffer(window: Window) error{ PlatformError, NoWindowContext }!OSMesaDepthBuffer {
            internal_debug.assertInitialized();
            var buf: OSMesaDepthBuffer = undefined;
            _ = native.glfwGetOSMesaDepthBuffer(@ptrCast(*native.GLFWwindow, window.handle), &buf.width, &buf.height, &buf.bytes_per_value, &buf.buffer);
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                Error.PlatformError, Error.NoWindowContext => |e| @errSetCast(error{ PlatformError, NoWindowContext }, e),
                else => unreachable,
            };
            return buf;
        }

        /// Returns the 'OSMesaContext' of the specified window.
        ///
        /// Possible errors include glfw.Error.NotInitalized and glfw.Error.NoWindowContext.
        ///
        /// thread_safety: This function may be called from any thread. Access is not synchronized.
        pub fn getOSMesaContext(window: Window) error{NoWindowContext}!*anyopaque {
            internal_debug.assertInitialized();
            const context = native.glfwGetOSMesa(@ptrCast(*native.GLFWwindow, window.handle));
            getError() catch |err| return switch (err) {
                Error.NotInitialized => unreachable,
                Error.NoWindowContext => |e| @errSetCast(error{NoWindowContext}, e),
                else => unreachable,
            };
            return @ptrCast(*anyopaque, context);
        }
    };
}
