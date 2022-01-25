#include <stdio.h>
#include <stdlib.h>
#define STB_IMAGE_IMPLEMENTATION
#define STBI_NO_SIMD
#define STBI_NO_HDR
#define STBI_NO_TGA

#ifdef PLATFORM_WEB
void* my_memset(void* data, unsigned char value, size_t bytes)
{
    char* cdata = (char*)data;
    for (size_t i = 0; i < bytes; i++) {
        cdata[i] = value;
    }
    return data;
}
void* my_realloc_sized(void* ptr, size_t oldsize, size_t newsize)
{
    void* newptr = malloc(newsize);
    char* old_data = (char*)ptr;
    char* new_data = (char*)newptr;
    if (newsize >= oldsize) {
        for (size_t i = 0; i < oldsize; i++) {
            new_data[i] = old_data[i];
        }   
    } else {
        for (size_t i = 0; i < newsize; i++) {
            new_data[i] = old_data[i];
        }
    }
    return newptr;
}
void my_none() {}
#define STBI_MEMSET(p, val, num) my_memset(p, val, num)
#define STBI_MALLOC(s) malloc(s)
#define STBI_FREE(ptr) free(ptr)
#define STBI_REALLOC(ptr, newsize) my_none()
#define STBI_REALLOC_SIZED(ptr, oldsize, newsize) my_realloc_sized(ptr, oldsize, newsize)
#endif

#include "stb_image.h"

// #undef STBI_MEMSET
// #undef STBI_MALLOC
// #undef STBI_FREE
// #undef STBI_REALLOC
// #undef STBI_REALLOC_SIZED