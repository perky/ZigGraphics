pub const Uint = u32;
pub const Int = i32;
pub const Enum = u32;
pub const Sizei = u32;
pub const Float = f32;
pub const Char = u8;
pub const Bool = u8;
pub const String = [*c]const Char;
pub const Strings = [*c]const String;
pub const VoidPtr = *const anyopaque;

pub const Functions = struct {
    pub extern fn glCreateShader(Enum) Uint;
    pub extern fn glShaderSource(Uint, Sizei, Strings, [*c]Int) void;
    pub extern fn glCompileShader(Uint) void;
    pub extern fn glCreateProgram() Uint;
    pub extern fn glAttachShader(Uint, Uint) void;
    pub extern fn glLinkProgram(Uint) void;
    pub extern fn glGetShaderiv(Uint, Enum, [*c]Int) void;
    pub extern fn glGetShaderInfoLog(Uint, Sizei, [*c]Sizei, String) void;
    pub extern fn glGetProgramiv(Uint, Enum, [*c]Int) void;
    pub extern fn glGetProgramInfoLog(Uint, Sizei, [*c]Sizei, String) void;
    pub extern fn glGetString(Enum) String;
    pub extern fn glGenBuffers(Sizei, [*c]const Uint) void;
    pub extern fn glBindBuffer(Enum, Uint) void;
    pub extern fn glBufferData(Enum, Sizei, VoidPtr, Enum) void;
    pub extern fn glEnableVertexAttribArray(Uint) void;
    pub extern fn glDisableVertexAttribArray(Uint) void;
    pub extern fn glVertexAttribPointer(Uint, Int, Enum, Bool, Sizei, ?VoidPtr) void; 
    pub extern fn glDrawArrays(Enum, Int, Sizei) void;
    pub extern fn glUseProgram(Uint) void;
    pub extern fn glGenVertexArrays(Sizei, [*c]const Uint) void;
    pub extern fn glBindVertexArray(Uint) void;
    pub extern fn glGetUniformLocation(Uint, String) Int;
    pub extern fn glUniformMatrix4fv(Int, Sizei, Bool, [*c]const Float) void;
};
