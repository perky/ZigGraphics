#version 330
precision mediump float;

in vec2 UV;
in vec4 VCol;
out vec4 frag_color;
uniform sampler2D texSampler;

void main() {
   frag_color = texture(texSampler, UV).rgba * VCol;
   //frag_color = texture(texSampler, UV).rgba;
   //frag_color = vec4(1.0, 1.0, 1.0, 1.0);
}