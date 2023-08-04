// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

varying highp vec2 texCoordVarying; //顶点坐标
precision highp float;

//亮度和色度阈值处理
uniform float lumaThreshold;
uniform float chromaThreshold;
//YUV颜色空间的Y、UV分量和RGBA的采样器
uniform sampler2D SamplerY;
uniform sampler2D SamplerUV;
uniform sampler2D SamplerRGBA;
//颜色转换矩阵
uniform mat3 colorConversionMatrix;
uniform bool isYUV;

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
        /*请注意，这里读取RGB的顺序是BGR，因为OpenGL中的纹理数据在内存中的存储顺序
          是从底部到顶部，从左到右的，所以在读取时，RGB顺序是反过来的.*/
        r = texture2D(SamplerRGBA, texCoordVarying).b;
        g = texture2D(SamplerRGBA, texCoordVarying).g;
        b = texture2D(SamplerRGBA, texCoordVarying).r;
        gl_FragColor = vec4(r, g, b, 1);
    }
}
