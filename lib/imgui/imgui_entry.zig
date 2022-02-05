pub const VertexShaderSrc = @embedFile("shader.vert");
pub const FragmentShaderSrc = @embedFile("shader.frag");
pub usingnamespace @cImport({
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", "1");
    @cInclude("cimgui.h");
});

