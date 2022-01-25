# Zig Graphics
A Zig library for creating OpenGL applications for both Desktop (windows, linux & mac) and web (WebAssembly with WebGL2).

## Building
If you have zig 0.9.x installed then simply call `zig build`.

The build command will make an executable for your host platform and a web version to the `docs` directory.
You can cross-compile to other platforms with the command `zig build -Dtarget=CPU-OS-ABI` with the CPU-OS-ABI triplet of your choice. 
Call `zig targets` for a list of available compilation targets on your host platform.