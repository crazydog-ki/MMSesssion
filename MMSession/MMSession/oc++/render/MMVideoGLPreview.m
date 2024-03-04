// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMVideoGLPreview.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

/// Uniform index
enum {
    UNIFORM_Y,
    UNIFORM_UV,
    UNIFORM_RGBA,
    UNIFORM_ISYUV,
    UNIFORM_VERTEX_COORD,
    UNIFORM_FRAGMENT_COORD,
    UNIFORM_LUMA_THRESHOLD,
    UNIFORM_CHROMA_THRESHOLD,
    UNIFORM_ROTATION_ANGLE,
    UNIFORM_COLOR_CONVERSION_MATRIX,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

/// BT.601
static const GLfloat kColorConversion601[] = {
    1.164,  1.164, 1.164,
    0.0,   -0.392, 2.017,
    1.596, -0.813, 0.0,
};

/// BT.709
static const GLfloat kColorConversion709[] = {
    1.164,  1.164, 1.164,
    0.0,   -0.213, 2.112,
    1.793, -0.533, 0.0,
};

@interface MMVideoGLPreview () {
    const GLfloat *_preferredConversion;
}

@property (nonatomic, strong) MMVideoPreviewConfig *config;
@property (nonatomic) CAEAGLLayer *rendLayer;
@property (nonatomic) EAGLContext *context;
@property (nonatomic) GLuint renderBuffer;
@property (nonatomic) GLuint frameBuffer;
@property (nonatomic) GLuint program;

@property (nonatomic) CVOpenGLESTextureCacheRef videoTextureCache;
@property (nonatomic) CVOpenGLESTextureRef lumaTexture;
@property (nonatomic) CVOpenGLESTextureRef chromaTexture;
@property (nonatomic) CVOpenGLESTextureRef rgbaTexture;

@property (nonatomic, assign) double videoPts;
@end

@implementation MMVideoGLPreview
- (instancetype)initWithConfig:(MMVideoPreviewConfig *)config {
    if (self = [super init]) {
        _videoPts = 0.0f;
        _config = config;
    }
    return self;
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (void)setupGLEnv {
    [self _setupLayerAndContext];
    [self _setupRenderBufferAndFrameBuffer];
    [self _setViewPort];
    [self _compileAndLinkShader];
    [self _setShaderParams];
}

- (void)dealloc {
    [self _destoryRenderAndFrameBuffer];
    [self _cleanUpTextures];
}

- (void)processPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) return;
    BOOL renderYUV = _config.renderYUV;
    CVPixelBufferRetain(pixelBuffer);
    
    if (renderYUV) {
        [self _rendYUVPixbuffer:pixelBuffer];
    } else {
        [self _rendRGBPixbuffer:pixelBuffer];
    }
    CVPixelBufferRelease(pixelBuffer);
}

- (double)getPts {
    return self.videoPts;
}

#pragma mark - Private
- (void)_setupLayerAndContext {
    self.rendLayer = (CAEAGLLayer *)self.layer;
    self.rendLayer.opaque = YES;
    self.rendLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: @(NO),
                                              kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8};
    self.layer.contentsScale = UIScreen.mainScreen.scale;
    
    self.context = [[EAGLContext alloc] initWithAPI: kEAGLRenderingAPIOpenGLES3];
    if (![EAGLContext setCurrentContext:self.context]) {
        NSLog(@"[mm] set current context failed");
    }
}

- (void)_setupRenderBufferAndFrameBuffer {
    [self _destoryRenderAndFrameBuffer];
    
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.rendLayer];
    
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
}

- (void)_setViewPort {
    glViewport(0, 0, _config.presentRect.size.width*UIScreen.mainScreen.scale, _config.presentRect.size.height*UIScreen.mainScreen.scale);
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
        NSLog(@"[mm] gl link program failed: %@", messageString);
        return;
    } else {
        NSLog(@"[mm] gl link program success");
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
    uniforms[UNIFORM_VERTEX_COORD] = glGetAttribLocation(self.program, "position");
    uniforms[UNIFORM_FRAGMENT_COORD] = glGetAttribLocation(self.program, "texCoord");
    
    uniforms[UNIFORM_ROTATION_ANGLE] = glGetUniformLocation(self.program, "preferredRotation");
    uniforms[UNIFORM_COLOR_CONVERSION_MATRIX] = glGetUniformLocation(self.program, "colorConversionMatrix");
    uniforms[UNIFORM_ISYUV] = glGetUniformLocation(self.program, "isYUV");
    
    glUniform1i(uniforms[UNIFORM_Y], 0);
    glUniform1i(uniforms[UNIFORM_UV], 1);
    glUniform1i(uniforms[UNIFORM_RGBA], 2);
    glUniform1f(uniforms[UNIFORM_LUMA_THRESHOLD], 1.0);
    glUniform1f(uniforms[UNIFORM_CHROMA_THRESHOLD], 1.0);
    
    /// 顶点坐标+纹理坐标
    GLfloat attrArr[] = {
        -1.0f, -1.0f, -1.0f,   0.0f, 1.0f,
         1.0f, -1.0f, -1.0f,   1.0f, 1.0f,
        -1.0f,  1.0f, -1.0f,   0.0f, 0.0f,
         1.0f,  1.0f, -1.0f,   1.0f, 0.0f,
    };

    // 使用VBO的方式upload顶点数据
    GLuint attaBuffer;
    glGenBuffers(1, &attaBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, attaBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(attrArr), &attrArr, GL_DYNAMIC_DRAW);
    
    GLuint vertex_coord = uniforms[UNIFORM_VERTEX_COORD];
    glVertexAttribPointer(vertex_coord, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat)*5, NULL); //向shader发送顶点坐标
    glEnableVertexAttribArray(vertex_coord); //激活
    
    GLuint frag_coord = uniforms[UNIFORM_FRAGMENT_COORD];
    glVertexAttribPointer(frag_coord, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat)*5, (float *)NULL+3); //向shader发送坐标
    glEnableVertexAttribArray(frag_coord); //激活
}

- (void)_cleanUpTextures {
    if (_lumaTexture) {
        CFRelease(_lumaTexture);
        _lumaTexture = NULL;
    }
    
    if (_chromaTexture) {
        CFRelease(_chromaTexture);
        _chromaTexture = NULL;
    }
    
    if (_rgbaTexture) {
        CFRelease(_rgbaTexture);
        _rgbaTexture = NULL;
    }
    
    if (_videoTextureCache) {
        CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
    }
}

- (void)_destoryRenderAndFrameBuffer {
    if (_renderBuffer) {
        glDeleteRenderbuffers(1, &_renderBuffer);
        _renderBuffer = 0;
    }
    
    if (_frameBuffer) {
        glDeleteFramebuffers(1, &_frameBuffer);
        _frameBuffer = 0;
    }
}

- (void)_rendYUVPixbuffer:(CVPixelBufferRef)buffer {
    if (_context != [EAGLContext currentContext]) {
        NSLog(@"[mm] reset gl context");
        [EAGLContext setCurrentContext:_context];
    }
    
    CVReturn err;
    if (buffer == NULL) {
        return;
    }
    [self _cleanUpTextures];
    if (!_videoTextureCache) {
        /*高效地将CVPixelBufferRef对象转换为CVOpenGLESTextureRef对象，直接被OpenGL ES使用.*/
        err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, self.context, NULL, &_videoTextureCache);
    }
    
    int frameWidth = (int)CVPixelBufferGetWidth(buffer);
    int frameHeight = (int)CVPixelBufferGetHeight(buffer);
    /// Y平面
    glActiveTexture(GL_TEXTURE0); //指定当前活动的纹理单元
    /*该函数提供一种高效的方式实现CVPixelBufferRef到CVOpenGLESTextureRef的转化，避免数据复制的开销。
      注意：传入的PixelBuffer必须支持IOSurface.*/
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _videoTextureCache,
                                                       buffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_LUMINANCE,
                                                       frameWidth,
                                                       frameHeight,
                                                       GL_LUMINANCE,
                                                       GL_UNSIGNED_BYTE,
                                                       0, //0 Plane
                                                       &_lumaTexture);
    //将一个已经创建的纹理绑定到当前活动的纹理单元
    glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    /// UV平面
    glActiveTexture(GL_TEXTURE1);
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _videoTextureCache,
                                                       buffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_LUMINANCE_ALPHA,
                                                       frameWidth / 2,
                                                       frameHeight / 2,
                                                       GL_LUMINANCE_ALPHA,
                                                       GL_UNSIGNED_BYTE,
                                                       1, //1 Plane
                                                       &_chromaTexture);
    glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture), CVOpenGLESTextureGetName(_chromaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glClearColor(1.0, 1.0, 0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    /// 颜色转换矩阵
    CFTypeRef colorAttachments = CVBufferGetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, NULL);
    if (colorAttachments == kCVImageBufferYCbCrMatrix_ITU_R_601_4) {
        _preferredConversion = kColorConversion601;
    } else {
        _preferredConversion = kColorConversion709;
    }
    glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
    glUniform1f(uniforms[UNIFORM_ROTATION_ANGLE], _config.rotation);
    glUniform1f(uniforms[UNIFORM_ISYUV], YES);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)_rendRGBPixbuffer:(CVPixelBufferRef)buffer {
    if (_context != [EAGLContext currentContext]) {
        NSLog(@"[mm] reset gl context");
        [EAGLContext setCurrentContext:_context];
    }
    
    CVReturn err;
    if (buffer == NULL) {
        return;
    }
    [self _cleanUpTextures];
    if (!_videoTextureCache) {
        err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, self.context, NULL, &_videoTextureCache);
    }
    
    int frameWidth = (int)CVPixelBufferGetWidth(buffer);
    int frameHeight= (int)CVPixelBufferGetHeight(buffer);
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
    
    glBindTexture(CVOpenGLESTextureGetTarget(_rgbaTexture), CVOpenGLESTextureGetName(_rgbaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glClearColor(1.0, 1.0, 0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);

    glUniform1f(uniforms[UNIFORM_ROTATION_ANGLE], _config.rotation);
    glUniform1f(uniforms[UNIFORM_ISYUV], NO);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}
@end
