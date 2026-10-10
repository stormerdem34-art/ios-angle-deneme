#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>

#include <EGL/egl.h>
#include <GLES3/gl3.h>

#include <cmath>

@interface MetalGorunum : UIView
@end

@implementation MetalGorunum

+ (Class)layerClass
{
    return [CAMetalLayer class];
}

@end

static GLuint GolgelendiriciDerle(GLenum tur, const char* kaynak)
{
    GLuint g = glCreateShader(tur);
    glShaderSource(g, 1, &kaynak, nullptr);
    glCompileShader(g);
    GLint tamam = 0;
    glGetShaderiv(g, GL_COMPILE_STATUS, &tamam);
    if (!tamam) {
        char kayit[1024] = { 0 };
        glGetShaderInfoLog(g, sizeof(kayit) - 1, nullptr, kayit);
        NSLog(@"golgelendirici hatasi: %s", kayit);
    }
    return g;
}

static const char* const c_koseKodu =
    "#version 300 es\n"
    "layout(location = 0) in vec2 aKonum;\n"
    "layout(location = 1) in vec3 aRenk;\n"
    "uniform float uAci;\n"
    "uniform vec2 uOlcek;\n"
    "uniform vec2 uKayma;\n"
    "out vec3 vRenk;\n"
    "void main() {\n"
    "    float c = cos(uAci), s = sin(uAci);\n"
    "    vec2 p = vec2(c * aKonum.x - s * aKonum.y, s * aKonum.x + c * aKonum.y);\n"
    "    gl_Position = vec4(p * uOlcek + uKayma, 0.0, 1.0);\n"
    "    vRenk = aRenk;\n"
    "}\n";

static const char* const c_parcaKodu =
    "#version 300 es\n"
    "precision mediump float;\n"
    "in vec3 vRenk;\n"
    "out vec4 renk;\n"
    "void main() { renk = vec4(vRenk, 1.0); }\n";

@interface DenemeDenetleyici : UIViewController
@end

@implementation DenemeDenetleyici {
    MetalGorunum* _gorunum;
    UILabel* _bilgi;
    CADisplayLink* _baglanti;
    EGLDisplay _egl;
    EGLSurface _yuzey;
    EGLContext _baglam;
    GLuint _program;
    GLint _uAci;
    GLint _uOlcek;
    GLint _uKayma;
    GLuint _vao[2];
    GLuint _vbo[2];
    CFTimeInterval _baslangic;
    CFTimeInterval _sayacBas;
    int _kareSayac;
    double _fps;
    double _enUzunMs;
    CFTimeInterval _oncekiKare;
    int _hedefHz;
    BOOL _hazir;
    NSString* _isleyici;
    NSString* _surum;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    _hedefHz = (int)UIScreen.mainScreen.maximumFramesPerSecond;
    _gorunum = [[MetalGorunum alloc] initWithFrame:self.view.bounds];
    _gorunum.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _gorunum.contentScaleFactor = UIScreen.mainScreen.nativeScale;
    _gorunum.layer.contentsScale = UIScreen.mainScreen.nativeScale;
    [self.view addSubview:_gorunum];

    _bilgi = [[UILabel alloc] initWithFrame:CGRectZero];
    _bilgi.numberOfLines = 0;
    _bilgi.textColor = UIColor.whiteColor;
    _bilgi.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightMedium];
    _bilgi.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    _bilgi.layer.cornerRadius = 10;
    _bilgi.layer.masksToBounds = YES;
    [self.view addSubview:_bilgi];

    UITapGestureRecognizer* dokunma = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dokunuldu)];
    [self.view addGestureRecognizer:dokunma];

    NSNotificationCenter* m = NSNotificationCenter.defaultCenter;
    [m addObserver:self selector:@selector(durdur) name:UIApplicationWillResignActiveNotification object:nil];
    [m addObserver:self selector:@selector(surdur) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGRect s = self.view.safeAreaLayoutGuide.layoutFrame;
    CGSize boyut = [_bilgi sizeThatFits:CGSizeMake(s.size.width * 0.6, s.size.height)];
    _bilgi.frame = CGRectMake(s.origin.x + 12, s.origin.y + 12, boyut.width + 24, boyut.height + 16);
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (!_hazir) {
        _hazir = [self eglKur];
        if (!_hazir) {
            _bilgi.text = @"  ANGLE baslatilamadi  ";
            [self.view setNeedsLayout];
            return;
        }
        _baslangic = CACurrentMediaTime();
        _sayacBas = _baslangic;
        _oncekiKare = _baslangic;
    }
    [self surdur];
}

- (BOOL)eglKur
{
    _egl = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (_egl == EGL_NO_DISPLAY || !eglInitialize(_egl, nullptr, nullptr)) return NO;
    const EGLint nitelik[] = {
        EGL_RENDERABLE_TYPE, 0x40,
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8,
        EGL_DEPTH_SIZE, 0,
        EGL_NONE
    };
    EGLConfig ayar = nullptr;
    EGLint sayi = 0;
    if (!eglChooseConfig(_egl, nitelik, &ayar, 1, &sayi) || sayi < 1) return NO;
    const EGLint baglamNitelik[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    _baglam = eglCreateContext(_egl, ayar, EGL_NO_CONTEXT, baglamNitelik);
    if (_baglam == EGL_NO_CONTEXT) return NO;
    _yuzey = eglCreateWindowSurface(_egl, ayar, (__bridge EGLNativeWindowType)_gorunum.layer, nullptr);
    if (_yuzey == EGL_NO_SURFACE) return NO;
    if (!eglMakeCurrent(_egl, _yuzey, _yuzey, _baglam)) return NO;
    eglSwapInterval(_egl, 1);

    _isleyici = [NSString stringWithUTF8String:(const char*)glGetString(GL_RENDERER)];
    _surum = [NSString stringWithUTF8String:(const char*)glGetString(GL_VERSION)];
    NSLog(@"GL: %@ / %@", _isleyici, _surum);

    _program = glCreateProgram();
    glAttachShader(_program, GolgelendiriciDerle(GL_VERTEX_SHADER, c_koseKodu));
    glAttachShader(_program, GolgelendiriciDerle(GL_FRAGMENT_SHADER, c_parcaKodu));
    glLinkProgram(_program);
    _uAci = glGetUniformLocation(_program, "uAci");
    _uOlcek = glGetUniformLocation(_program, "uOlcek");
    _uKayma = glGetUniformLocation(_program, "uKayma");

    const float ucgen[] = {
        0.0f, 0.62f, 0.96f, 0.72f, 0.36f,
        -0.54f, -0.31f, 0.89f, 0.29f, 0.24f,
        0.54f, -0.31f, 0.23f, 0.56f, 0.94f,
    };
    const float kare[] = {
        -0.05f, -1.0f, 1.0f, 1.0f, 1.0f,
        0.05f, -1.0f, 1.0f, 1.0f, 1.0f,
        0.05f, 1.0f, 1.0f, 1.0f, 1.0f,
        -0.05f, -1.0f, 1.0f, 1.0f, 1.0f,
        0.05f, 1.0f, 1.0f, 1.0f, 1.0f,
        -0.05f, 1.0f, 1.0f, 1.0f, 1.0f,
    };
    glGenVertexArrays(2, _vao);
    glGenBuffers(2, _vbo);
    const float* veriler[2] = { ucgen, kare };
    const GLsizeiptr boyutlar[2] = { sizeof(ucgen), sizeof(kare) };
    for (int i = 0; i < 2; ++i) {
        glBindVertexArray(_vao[i]);
        glBindBuffer(GL_ARRAY_BUFFER, _vbo[i]);
        glBufferData(GL_ARRAY_BUFFER, boyutlar[i], veriler[i], GL_STATIC_DRAW);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (const void*)0);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (const void*)(2 * sizeof(float)));
    }
    glBindVertexArray(0);
    return YES;
}

- (void)hiziUygula
{
    if (!_baglanti) return;
    if (@available(iOS 15.0, *)) {
        float en = (float)_hedefHz;
        _baglanti.preferredFrameRateRange = CAFrameRateRangeMake(en >= 100.0f ? 80.0f : en, en, en);
    } else {
        _baglanti.preferredFramesPerSecond = _hedefHz;
    }
}

- (void)surdur
{
    if (!_hazir || _baglanti) return;
    _baglanti = [CADisplayLink displayLinkWithTarget:self selector:@selector(kare:)];
    [self hiziUygula];
    [_baglanti addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    _sayacBas = CACurrentMediaTime();
    _oncekiKare = _sayacBas;
    _kareSayac = 0;
    _enUzunMs = 0;
}

- (void)durdur
{
    [_baglanti invalidate];
    _baglanti = nil;
}

- (void)dokunuldu
{
    int enCok = (int)UIScreen.mainScreen.maximumFramesPerSecond;
    _hedefHz = _hedefHz >= enCok ? 60 : enCok;
    [self hiziUygula];
    _sayacBas = CACurrentMediaTime();
    _kareSayac = 0;
    _enUzunMs = 0;
}

- (NSString*)isiDurumu
{
    switch (NSProcessInfo.processInfo.thermalState) {
    case NSProcessInfoThermalStateNominal: return @"normal";
    case NSProcessInfoThermalStateFair: return @"ılık";
    case NSProcessInfoThermalStateSerious: return @"sıcak";
    case NSProcessInfoThermalStateCritical: return @"kritik";
    }
    return @"?";
}

- (void)kare:(CADisplayLink*)baglanti
{
    CFTimeInterval simdi = CACurrentMediaTime();
    double fark = (simdi - _oncekiKare) * 1000.0;
    _oncekiKare = simdi;
    if (_kareSayac > 0 && fark > _enUzunMs) _enUzunMs = fark;

    EGLint en = 0, boy = 0;
    eglQuerySurface(_egl, _yuzey, EGL_WIDTH, &en);
    eglQuerySurface(_egl, _yuzey, EGL_HEIGHT, &boy);
    glViewport(0, 0, en, boy);

    double t = simdi - _baslangic;
    glClearColor(0.04f + 0.03f * (float)sin(t * 0.7), 0.06f, 0.10f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(_program);
    float oran = boy > 0 ? (float)boy / (float)en : 1.0f;
    glUniform2f(_uOlcek, 0.8f * oran, 0.8f);
    glUniform2f(_uKayma, 0.0f, 0.0f);
    glUniform1f(_uAci, (float)(t * 1.6));
    glBindVertexArray(_vao[0]);
    glDrawArrays(GL_TRIANGLES, 0, 3);

    double x = fmod(t * 0.9, 2.0);
    x = x < 1.0 ? x : 2.0 - x;
    glUniform2f(_uOlcek, oran, 1.0f);
    glUniform2f(_uKayma, (float)(x * 1.8 - 0.9), 0.0f);
    glUniform1f(_uAci, 0.0f);
    glBindVertexArray(_vao[1]);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindVertexArray(0);

    eglSwapBuffers(_egl, _yuzey);

    ++_kareSayac;
    double gecen = simdi - _sayacBas;
    if (gecen >= 0.5) {
        _fps = _kareSayac / gecen;
        _bilgi.text = [NSString stringWithFormat:
                           @"MSP2 iPhone denemesi (ANGLE → Metal)\n"
                           @"GL: %@\n"
                           @"Sürüm: %@\n"
                           @"Ekran: en çok %d Hz, hedef %d\n"
                           @"Ölçülen: %.1f FPS (en uzun kare %.1f ms)\n"
                           @"Çizim: %dx%d piksel\n"
                           @"Isı durumu: %@\n"
                           @"Dokun: 60 ↔ %d Hz",
                           _isleyici, _surum, (int)UIScreen.mainScreen.maximumFramesPerSecond, _hedefHz,
                           _fps, _enUzunMs, (int)en, (int)boy, [self isiDurumu],
                           (int)UIScreen.mainScreen.maximumFramesPerSecond];
        [self.view setNeedsLayout];
        _sayacBas = simdi;
        _kareSayac = 0;
        _enUzunMs = 0;
    }
}

@end

@interface SahneTemsilcisi : UIResponder <UIWindowSceneDelegate>
@property (strong, nonatomic) UIWindow* window;
@end

@implementation SahneTemsilcisi

- (void)scene:(UIScene*)scene willConnectToSession:(UISceneSession*)session options:(UISceneConnectionOptions*)options
{
    if (![scene isKindOfClass:[UIWindowScene class]]) return;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene*)scene];
    self.window.rootViewController = [[DenemeDenetleyici alloc] init];
    [self.window makeKeyAndVisible];
}

@end

@interface UygulamaTemsilcisi : UIResponder <UIApplicationDelegate>
@end

@implementation UygulamaTemsilcisi

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)options
{
    application.idleTimerDisabled = YES;
    return YES;
}

- (UISceneConfiguration*)application:(UIApplication*)application configurationForConnectingSceneSession:(UISceneSession*)session options:(UISceneConnectionOptions*)options
{
    UISceneConfiguration* y = [[UISceneConfiguration alloc] initWithName:@"Default" sessionRole:session.role];
    y.delegateClass = [SahneTemsilcisi class];
    return y;
}

@end

int main(int argc, char* argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([UygulamaTemsilcisi class]));
    }
}
