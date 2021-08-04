// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

varying highp vec2 texCoordVarying;
precision highp float;

uniform float lumaThreshold;
uniform float chromaThreshold;
uniform bool isYUV;
uniform sampler2D SamplerY;
uniform sampler2D SamplerUV;
uniform sampler2D SamplerRGBA;
uniform mat3 colorConversionMatrix;

void main() {
    highp vec3 yuv;
    highp vec3 rgb;
    highp float r, g, b;

    if (isYUV) {
        yuv.x = (texture2D(SamplerY, texCoordVarying).r - (16.0/255.0))*lumaThreshold;
        yuv.yz = (texture2D(SamplerUV, texCoordVarying).ra - vec2(0.5, 0.5))*chromaThreshold;
        rgb = colorConversionMatrix * yuv;
        gl_FragColor = vec4(rgb, 1);
    } else {
        r = texture2D(SamplerRGBA, texCoordVarying).b;
        g = texture2D(SamplerRGBA, texCoordVarying).g;
        b = texture2D(SamplerRGBA, texCoordVarying).r;
        gl_FragColor = vec4(r, g, b, 1);
    }

}
