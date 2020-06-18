//
//  OCDynamic.m
//  HotFixDemo
//
//  Created by zzyong on 2020/6/17.
//  Copyright © 2020 zzyong. All rights reserved.
//

#import "OCDynamic.h"
#import <objc/runtime.h>
#import <objc/message.h>

typedef void(^OCDynamicBlock)(id self, NSInvocation *originalInvocation);

@implementation NSObject (OCDynamic)

+ (void)dy_hookSelector:(SEL)selector withBlock:(void(^)(id self, NSInvocation *originalInvocation))block
{
    // 保存回调 block
    [dynamicBlockMap() setObject:block forKey:NSStringFromSelector(selector)];
    
    // 1.获取目标方法的 IMP
    Method targetMethod = class_getInstanceMethod(self, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    
    // 2.新增一个目标方法的别名方法
    NSString *aliasSelString = [NSString stringWithFormat:@"oc_dynamic_%@", NSStringFromSelector(selector)];
    const char *typeEncoding = method_getTypeEncoding(targetMethod);
    BOOL isSuccessed = class_addMethod(self, NSSelectorFromString(aliasSelString), targetMethodIMP, typeEncoding);
    NSLog(@"%@ add method successfully: %d", aliasSelString, isSuccessed);
    
    // 3.将目标方法实现替换成 _objc_msgForward
    class_replaceMethod(self, selector, (IMP)_objc_msgForward, typeEncoding);
    
    // 4.将目标类的 forwardInvocation 替换为自定义 dy_forwardInvocation_center
    class_replaceMethod(self, @selector(forwardInvocation:), (IMP)dy_forwardInvocation_center, "v@:@");
}

static NSMutableDictionary<NSString *, OCDynamicBlock>* dynamicBlockMap(void)
{
    static NSMutableDictionary *_dynamicBlockMap;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _dynamicBlockMap = [NSMutableDictionary dictionary];
    });
    
    return _dynamicBlockMap;
}

static void dy_forwardInvocation_center(id self, SEL _cmd, NSInvocation *anInvocation)
{
    // 获取回调 block
    OCDynamicBlock targetBlock = [dynamicBlockMap() objectForKey:NSStringFromSelector(anInvocation.selector)];
    
    // 将 anInvocation 的 sel 设置为别名 sel
    NSString *aliasSelString = [NSString stringWithFormat:@"oc_dynamic_%@", NSStringFromSelector(anInvocation.selector)];
    anInvocation.selector = NSSelectorFromString(aliasSelString);
    
    // 调用回调 block
    targetBlock(self, anInvocation);
}

@end
