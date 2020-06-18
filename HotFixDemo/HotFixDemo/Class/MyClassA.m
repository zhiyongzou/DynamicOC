//
//  MyClassA.m
//  HotFixDemo
//
//  Created by zzyong on 2020/6/15.
//  Copyright © 2020 zzyong. All rights reserved.
//

#import "MyClassA.h"

@implementation MyClassA

- (void)commonMethod
{
    
}

+ (BOOL)resolveClassMethod:(SEL)sel
{
    BOOL isResolve = [super resolveClassMethod:sel];
    NSLog(@"%s %d", __func__, isResolve);
    return isResolve;
}

+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    BOOL isResolve = [super resolveInstanceMethod:sel];
    NSLog(@"%s %d", __func__, isResolve);
    return isResolve;
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    id target = [super forwardingTargetForSelector:aSelector];
    NSLog(@"%s %@", __func__, target);
    return target;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];
    NSLog(@"%s %@", __func__, signature);
    
    if (signature == nil) {
        signature = [self methodSignatureForSelector:@selector(commonMethod)];
    }
    
    return signature;
}

- (void)doesNotRecognizeSelector:(SEL)aSelector
{
    NSLog(@"%s %@", __func__, NSStringFromSelector(aSelector));
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"%s %@", __func__, anInvocation);
}

@end
