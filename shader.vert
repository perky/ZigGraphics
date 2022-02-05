#version 330

layout(location = 0) in vec3 vertexPos;
layout(location = 1) in vec2 vertexUv;
layout(location = 2) in vec4 vertexColor;

out vec2 UV;
out vec4 VCol;
uniform mat4 transform;

void main() {
    gl_Position = transform * vec4(vertexPos, 1);
    UV = vertexUv;
    VCol = vertexColor;
}