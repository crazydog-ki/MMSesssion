// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

attribute vec4 position;
attribute vec2 texCoord;
uniform float preferredRotation;

varying vec2 texCoordVarying;

void main() {
	mat4 rotationMatrix = mat4(cos(preferredRotation), -sin(preferredRotation), 0.0, 0.0,
                               sin(preferredRotation),  cos(preferredRotation), 0.0, 0.0,
                                                  0.0,					   0.0, 1.0, 0.0,
                                                  0.0,					   0.0, 0.0, 1.0);
	gl_Position = position * rotationMatrix;
    // gl_Position = position;
	texCoordVarying = texCoord;
}

