//typedef unsigned long long  ImU64;
//typedef void* ImFileHandle;
//void*         ImFileOpen(const char*, const char*);
//bool          ImFileClose(ImFileHandle);
//ImU64         ImFileGetSize(ImFileHandle);
//ImU64         ImFileRead(void*, ImU64, ImU64, ImFileHandle);
//ImU64         ImFileWrite(const void*, ImU64, ImU64, ImFileHandle);

const c_void = *anyopaque;
const ImFileHandle = c_void;
const const_c_void = *const anyopaque;

pub export fn ImFileOpen(_: [*c]const u8, _: [*c]const u8) ImFileHandle
{
    return @intToPtr(*anyopaque, 5);
}

pub export fn ImFileClose(_: ImFileHandle) bool
{
    return true;
}

pub export fn ImFileGetSize(_: ImFileHandle) u64
{
    return 0;
}

pub export fn ImFileRead(_: c_void, _: u64, _: u64, _: ImFileHandle) u64
{
    return 0;
}

pub export fn ImFileWrite(_: const_c_void, _: u64, _: u64, _: ImFileHandle) u64
{
    return 0;
}