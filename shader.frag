#version 330
precision mediump float;

in vec2 UV;
out vec4 color;
uniform sampler2D texSampler;

void main() {
   //color = vec4(0.0, 1.0, 0.0, 1.0);
   color = texture(texSampler, UV).rgba;
}