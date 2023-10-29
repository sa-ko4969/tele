#import "UIKitUtils.h"

#import <objc/runtime.h>

#if TARGET_IPHONE_SIMULATOR
UIKIT_EXTERN float UIAnimationDragCoefficient(); // UIKit private drag coeffient, use judiciously
#endif

@implementation UIView (AnimationUtils)

+ (double)animationDurationFactor
{
#if TARGET_IPHONE_SIMULATOR
    return (double)UIAnimationDragCoefficient();
#endif
    
    return 1.0f;
}

@end

@interface CASpringAnimation ()

@end

@implementation CASpringAnimation (AnimationUtils)

- (CGFloat)valueAt:(CGFloat)t {
    static dispatch_once_t onceToken;
    static float (*impl)(id, float) = NULL;
    static double (*dimpl)(id, double) = NULL;
    dispatch_once(&onceToken, ^{
        Method method = class_getInstanceMethod([CASpringAnimation class], NSSelectorFromString([@"_" stringByAppendingString:@"solveForInput:"]));
        if (method) {
            const char *encoding = method_getTypeEncoding(method);
            NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:encoding];
            const char *argType = [signature getArgumentTypeAtIndex:2];
            if (strncmp(argType, "f", 1) == 0) {
                impl = (float (*)(id, float))method_getImplementation(method);
            } else if (strncmp(argType, "d", 1) == 0) {
                dimpl = (double (*)(id, double))method_getImplementation(method);
            }
        }
    });
    if (impl) {
        float result = impl(self, (float)t);
        return (CGFloat)result;
    } else if (dimpl) {
        double result = dimpl(self, (double)t);
        return (CGFloat)result;
    }
    return t;
}

@end

CABasicAnimation * _Nonnull makeSpringAnimation(NSString * _Nonnull keyPath) {
    CASpringAnimation *springAnimation = [CASpringAnimation animationWithKeyPath:keyPath];
    springAnimation.mass = 3.0f;
    springAnimation.stiffness = 1000.0f;
    springAnimation.damping = 500.0f;
    springAnimation.duration = 0.5;
    springAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    return springAnimation;
}

CABasicAnimation * _Nonnull makeSpringBounceAnimation(NSString * _Nonnull keyPath, CGFloat initialVelocity, CGFloat damping) {
    CASpringAnimation *springAnimation = [CASpringAnimation animationWithKeyPath:keyPath];
    springAnimation.mass = 5.0f;
    springAnimation.stiffness = 900.0f;
    springAnimation.damping = damping;
    static bool canSetInitialVelocity = true;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        canSetInitialVelocity = [springAnimation respondsToSelector:@selector(setInitialVelocity:)];
    });
    if (canSetInitialVelocity) {
        springAnimation.initialVelocity = initialVelocity;
        springAnimation.duration = springAnimation.settlingDuration;
    } else {
        springAnimation.duration = 0.1;
    }
    springAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    return springAnimation;
}

CGFloat springAnimationValueAt(CABasicAnimation * _Nonnull animation, CGFloat t) {
    return [(CASpringAnimation *)animation valueAt:t];
}
