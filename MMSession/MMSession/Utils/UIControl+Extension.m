// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "UIControl+Extension.h"
#import <objc/runtime.h>

@implementation UIControl (Extension)
+ (void)load {
    Method a = class_getInstanceMethod(self, @selector(sendAction:to:forEvent:));
    Method b = class_getInstanceMethod(self, @selector(_sendAction:to:forEvent:));
    method_exchangeImplementations(a, b);
}

- (void)_sendAction:(SEL)action
                 to:(id)target
           forEvent:(UIEvent *)event {
    if ([self isKindOfClass:UIButton.class]) {
        [self _shake:(UIButton *)self];
    }
    [self _sendAction:action to:target forEvent:event];
}

-(void)_shake:(UIButton *)button {
    CAKeyframeAnimation* animation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    animation.duration = 0.5;

    NSMutableArray *values = [NSMutableArray array];
    [values addObject:[NSValue valueWithCATransform3D:CATransform3DMakeScale(0.1, 0.1, 1.0)]];
    [values addObject:[NSValue valueWithCATransform3D:CATransform3DMakeScale(1.2, 1.2, 1.0)]];
    [values addObject:[NSValue valueWithCATransform3D:CATransform3DMakeScale(0.9, 0.9, 1.0)]];
    [values addObject:[NSValue valueWithCATransform3D:CATransform3DMakeScale(1.0, 1.0, 1.0)]];
    animation.values = values;
    [button.layer addAnimation:animation forKey:nil];
}
@end
