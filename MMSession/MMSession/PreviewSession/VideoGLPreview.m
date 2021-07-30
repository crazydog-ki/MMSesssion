// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "VideoGLPreview.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

// Uniform index.
enum {
    UNIFORM_Y,
    UNIFORM_UV,
    UNIFORM_RGBA,
    UNIFORM_ISYUV,
    UNIFORM_LUMA_THRESHOLD,
    UNIFORM_CHROMA_THRESHOLD,
    UNIFORM_ROTATION_ANGLE,
    UNIFORM_COLOR_CONVERSION_MATRIX,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// BT.601
static const GLfloat kColorConversion601[] = {
    1.164,  1.164, 1.164,
    0.0,   -0.392, 2.017,
    1.596, -0.813, 0.0,
};

// BT.709
static const GLfloat kColorConversion709[] = {
    1.164,  1.164, 1.164,
    0.0,   -0.213, 2.112,
    1.793, -0.533, 0.0,
};

@interface VideoGLPreview () {
    const GLfloat *_preferredConversion;
}
@property (nonatomic) CAEAGLLayer *rendLayer;
@property (nonatomic) EAGLContext *context;
@property (nonatomic) GLuint renderBuffer;
@property (nonatomic) GLuint frameBuffer;
@property (nonatomic) GLuint program;

@property (nonatomic) CVOpenGLESTextureCacheRef videoTextureCache;
@property (nonatomic) CVOpenGLESTextureRef lumaTexture;
@property (nonatomic) CVOpenGLESTextureRef chreomaTexture;
@property (nonatomic) CVOpenGLESTextureRef rgbaTexture;
@end

@implementation VideoGLPreview

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (void)setupGLEnv {
    [self _setupLayer];
    [self _setupContext];
    [self _setupRenderBufferAndFrameBuffer];
    [self _setViewPort];
    [self _compileAndLinkShader];
    [self _setShaderParams];
    [self _configCoreVideoParams];
}

- (void)processVideoBuffer:(CMSampleBufferRef)sampleBuffer {
    BOOL renderYUV = _config.renderYUV;
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferRetain(pixelBuffer);
    if (renderYUV) {
        [self _rendYUVPixbuffer:pixelBuffer];
    } else {
        [self _rendRGBPixbuffer:pixelBuffer];
    }
    CVPixelBufferRelease(pixelBuffer);
}

#pragma mark - Private
- (void)_setupLayer {
    self.rendLayer = (CAEAGLLayer *)self.layer;
    self.rendLayer.opaque = YES;
    self.rendLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: @(NO),
                                              kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8};
}

- (void)_setupContext {
    self.context = [[EAGLContext alloc] initWithAPI: kEAGLRenderingAPIOpenGLES2];
    if (![EAGLContext setCurrentContext:self.context]) {
        NSLog(@"[yjx] set current context failed");
    }
}

- (void)_setupRenderBufferAndFrameBuffer {
    if (self.renderBuffer) {
        glDeleteRenderbuffers(1, &_renderBuffer);
        self.renderBuffer = 0;
    }
    
    if (self.frameBuffer) {
        glDeleteFramebuffers(1, &_frameBuffer);
        self.frameBuffer = 0;
    }
    
    GLuint renderBuffer, frameBuffer;
    glGenRenderbuffers(1, &renderBuffer);
    self.renderBuffer = renderBuffer;
    glBindRenderbuffer(GL_RENDERBUFFER, self.renderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.rendLayer];
    
    glGenFramebuffers(1, &frameBuffer);
    self.frameBuffer = frameBuffer;
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, self.renderBuffer);
}

- (void)_setViewPort {
    glViewport(0, 0, _config.presentRect.size.width, _config.presentRect.size.height);
}

- (void)_compileAndLinkShader {
    NSString *vertFile = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    NSString *fragFile = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    
    GLuint vertSahder, fragShader;
    GLuint program = glCreateProgram();
    [self _compileShader:&vertSahder type:GL_VERTEX_SHADER file:vertFile];
    [self _compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragFile];
    
    glAttachShader(program, vertSahder);
    glAttachShader(program, fragShader);
    
    glDeleteShader(vertSahder);
    glDeleteShader(fragShader);
    
    glLinkProgram(program);
    self.program = program;
    
    GLint linkSuccess;
    glGetProgramiv(self.program, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(self.program, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"[yjx] gl link program failed: %@", messageString);
        return;
    } else {
        NSLog(@"[yjx] gl link program success");
        glUseProgram(self.program);
    }
}

- (void)_compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file {
    NSString *content = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
    const GLchar *source = (GLchar *)[content UTF8String];
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
}

- (void)_setShaderParams {
    uniforms[UNIFORM_Y] = glGetUniformLocation(self.program, "SamplerY");
    uniforms[UNIFORM_UV] = glGetUniformLocation(self.program, "SamplerUV");
    uniforms[UNIFORM_RGBA] = glGetUniformLocation(self.program, "SamplerRGBA");
    uniforms[UNIFORM_LUMA_THRESHOLD] = glGetUniformLocation(self.program, "lumaThreshold");
    uniforms[UNIFORM_CHROMA_THRESHOLD] = glGetUniformLocation(self.program, "chromaThreshold");
    uniforms[UNIFORM_ROTATION_ANGLE] = glGetUniformLocation(self.program, "preferredRotation");
    uniforms[UNIFORM_COLOR_CONVERSION_MATRIX] = glGetUniformLocation(self.program, "colorConversionMatrix");
    uniforms[UNIFORM_ISYUV] = glGetUniformLocation(self.program, "isYUV");
    
    glUniform1i(uniforms[UNIFORM_Y], 0);
    glUniform1i(uniforms[UNIFORM_UV], 1);
    glUniform1i(uniforms[UNIFORM_RGBA], 2);
    glUniform1f(uniforms[UNIFORM_LUMA_THRESHOLD], 1.0);
    glUniform1f(uniforms[UNIFORM_CHROMA_THRESHOLD], 1.0);
}

- (void)_configCoreVideoParams {
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, self.context, NULL, &_videoTextureCache);
    if (err != noErr) {
        NSLog(@"[yjx] OpenGLESTextureCacheCreate error: %d", err);
        return;
    }
}

- (void)_cleanUpTextures {
    if (_lumaTexture) {
        CFRelease(_lumaTexture);
        _lumaTexture = NULL;
    }
    
    if (_chreomaTexture) {
        CFRelease(_chreomaTexture);
        _chreomaTexture = NULL;
    }
    
    if (_rgbaTexture) {
        CFRelease(_rgbaTexture);
        _rgbaTexture = NULL;
    }
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
}

- (void)_rendYUVPixbuffer:(CVPixelBufferRef)buffer {
    CVReturn err;
    if (buffer == NULL) {
        return;
    }
    
    int frameWidth = (int)CVPixelBufferGetWidth(buffer);
    int frameHeight = (int)CVPixelBufferGetHeight(buffer);
    
    if (!_videoTextureCache) {
        NSLog(@"[yjx] No Video texture cache");
        return;
    }
    
    [self _cleanUpTextures];
    
    // Y平面
    glActiveTexture(GL_TEXTURE0);
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _videoTextureCache,
                                                       buffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_RED_EXT,
                                                       frameWidth,
                                                       frameHeight,
                                                       GL_RED_EXT,
                                                       GL_UNSIGNED_BYTE,
                                                       0,
                                                       &_lumaTexture);
    if (err) {
        NSLog(@"[yjx] CVOpenGLESTextureCacheCreateTextureFromImage for Y plane error: %d", err);
    }
    glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // UV平面
    glActiveTexture(GL_TEXTURE1);
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _videoTextureCache,
                                                       buffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_RG_EXT,
                                                       frameWidth / 2,
                                                       frameHeight / 2,
                                                       GL_RG_EXT,
                                                       GL_UNSIGNED_BYTE,
                                                       1,
                                                       &_chreomaTexture);
    if (err) {
        NSLog(@"[yjx] CVOpenGLESTextureCacheCreateTextureFromImage for UV plane error: %d", err);
    }
    glBindTexture(CVOpenGLESTextureGetTarget(_chreomaTexture), CVOpenGLESTextureGetName(_chreomaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // 颜色转换矩阵
    CFTypeRef colorAttachments = CVBufferGetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, NULL);
    if (colorAttachments == kCVImageBufferYCbCrMatrix_ITU_R_601_4) {
        _preferredConversion = kColorConversion601;
    } else {
        _preferredConversion = kColorConversion709;
    }
    glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
    glUniform1f(uniforms[UNIFORM_ROTATION_ANGLE], _config.rotation);
    glUniform1f(uniforms[UNIFORM_ISYUV], YES);
    glClearColor(1.0, 1.0, 0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // 顶点坐标+纹理坐标
    GLfloat attrArr[] = {
        -1.0f, -1.0f, -1.0f,   0.0f, 1.0f,
         1.0f, -1.0f, -1.0f,   1.0f, 1.0f,
        -1.0f,  1.0f, -1.0f,   0.0f, 0.0f,
         1.0f,  1.0f, -1.0f,   1.0f, 0.0f,
    };
    
    GLuint attaBuffer;
    glGenBuffers(1, &attaBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, attaBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(attrArr), &attrArr, GL_DYNAMIC_DRAW);
    
    GLuint position = glGetAttribLocation(self.program, "position");
    GLuint textCoordinate = glGetAttribLocation(self.program, "texCoord");
    glVertexAttribPointer(position, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, NULL);
    glEnableVertexAttribArray(position);
    
    glVertexAttribPointer(textCoordinate, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, (float *)NULL + 3);
    glEnableVertexAttribArray(textCoordinate);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)_rendRGBPixbuffer:(CVPixelBufferRef)buffer {
    CVReturn err;
    if (buffer == NULL) {
        return;
    }
    
    int frameWidth = (int)CVPixelBufferGetWidth(buffer);
    int frameHeight= (int)CVPixelBufferGetHeight(buffer);
    
    if (!_videoTextureCache) {
        NSLog(@"[yjx] no Video texture cache");
        return;
    }
    
    [self _cleanUpTextures];
    
    glActiveTexture(GL_TEXTURE2);
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _videoTextureCache,
                                                       buffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_RGBA,
                                                       frameWidth,
                                                       frameHeight,
                                                       GL_RGBA,
                                                       GL_UNSIGNED_BYTE,
                                                       0,
                                                       &_rgbaTexture);
    if (err) {
        NSLog(@"[yjx] CVOpenGLESTextureCacheCreateTextureFromImage for RGBA error: %d", err);
    }
    
    glBindTexture(CVOpenGLESTextureGetTarget(_rgbaTexture), CVOpenGLESTextureGetName(_rgbaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glUniform1f(uniforms[UNIFORM_ISYUV], NO);
    glUniform1f(uniforms[UNIFORM_ROTATION_ANGLE], _config.rotation);
    glClearColor(1.0, 1.0, 0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);

    // 顶点坐标+纹理坐标
    GLfloat attrArr[] = {
        -1.0f, -1.0f, -1.0f,   0.0f, 1.0f,
         1.0f, -1.0f, -1.0f,   1.0f, 1.0f,
        -1.0f,  1.0f, -1.0f,   0.0f, 0.0f,
         1.0f,  1.0f, -1.0f,   1.0f, 0.0f,
    };
    
    GLuint attaBuffer;
    glGenBuffers(1, &attaBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, attaBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(attrArr), &attrArr, GL_DYNAMIC_DRAW);
    
    GLuint position = glGetAttribLocation(self.program, "position");
    GLuint textCoordinate = glGetAttribLocation(self.program, "texCoord");
    glVertexAttribPointer(position, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, NULL);
    glEnableVertexAttribArray(position);
    
    glVertexAttribPointer(textCoordinate, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, (float *)NULL + 3);
    glEnableVertexAttribArray(textCoordinate);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

@end