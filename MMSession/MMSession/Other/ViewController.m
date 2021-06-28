// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "ViewController.h"
#import "CameraSession.h"

@interface ViewController ()

@property (nonatomic, strong) CameraSession *camera;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.camera = [[CameraSession alloc] initWithConfig:nil];
    [self.camera startCapture];
    // Do any additional setup after loading the view.
}


@end
