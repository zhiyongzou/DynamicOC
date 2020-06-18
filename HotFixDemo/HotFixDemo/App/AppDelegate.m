//
//  AppDelegate.m
//  HotFixDemo
//
//  Created by zzyong on 2020/6/11.
//  Copyright © 2020 zzyong. All rights reserved.
//

#import "AppDelegate.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "MyClassA.h"
#import <Aspects.h>
#import "MyClassB.h"
#import "OCDynamic.h"
#import "MyClassC.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

void sayHello(id self, SEL _cmd)
{
    NSLog(@"%@ %s", self, __func__);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self addNewClassPair];
    
    Class MyObject = NSClassFromString(@"MyObject");
    NSObject *myObj = [[MyObject alloc] init];
    [myObj performSelector:@selector(sayHello)];
    
    [self methodReplace];
    [self methodExchange];
    [self forwardInvocationTest];
//    [self releaseAdvance];
    [self memoryLeakA];
    [self memoryLeakB];
//    [self hookMyClassCMethod];
    
    [self dy_hookMethodWithHookMap:@{
                                        @"cls": @"MyClassC",
                                        @"sel": @"sayHelloTo:",
                                        @"parameters": @[@"Lili"]
                                   }];
    // 测试 MyClassC
    [[MyClassC new] sayHelloTo:@"jack"];
    
    [self dy_hookMethodWithHookMap:@{
                                        @"cls": @"MyClassC",
                                        @"sel": @"className",
                                        @"returnValue": @"CustomName",
                                        @"customMethods": @[@"self.customMethod"]
                                   }];
    // 测试 MyClassC
    NSLog(@"%@", [[MyClassC new] className]);
    
    return YES;
}

- (void)dy_hookMethodWithHookMap:(NSDictionary *)hookMap
{
    Class cls = NSClassFromString([hookMap objectForKey:@"cls"]);
    SEL sel = NSSelectorFromString([hookMap objectForKey:@"sel"]);
    NSArray *parameters = [hookMap objectForKey:@"parameters"];
    NSArray<NSString *> *customMethods = [hookMap objectForKey:@"customMethods"];
    
    [cls dy_hookSelector:sel withBlock:^(id  _Nonnull self, NSInvocation * _Nonnull originalInvocation) {
        NSLog(@"Fix me here!");
        
        [customMethods enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSArray<NSString *> *targets = [obj componentsSeparatedByString:@"."];
            
            id target = nil;
            if ([targets.firstObject isEqualToString:@"self"]) {
                target = self;
            }
            
            SEL sel = NSSelectorFromString(targets.lastObject);
            NSMethodSignature *targetSig = [[target class] instanceMethodSignatureForSelector:sel];
            
            NSInvocation *customInvocation = [NSInvocation invocationWithMethodSignature:targetSig];
            customInvocation.target = target;
            customInvocation.selector = sel;
            [customInvocation invoke];
            
            target = nil;
        }];
        
        [parameters enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [originalInvocation setArgument:&obj atIndex:idx + 2];
        }];
        
        [originalInvocation invoke];
        
        id returnValue = [hookMap objectForKey:@"returnValue"];
        if (returnValue) {
            [originalInvocation setReturnValue:&returnValue];
        }
    }];
}

- (void)hookMyClassCMethod
{
    [MyClassC dy_hookSelector:@selector(sayHelloTo:) withBlock:^(id  _Nonnull self, NSInvocation * _Nonnull originalInvocation) {
        __weak id value = nil;
        [originalInvocation getArgument:&value atIndex:2];
        NSLog(@"%@ %@", NSStringFromSelector(originalInvocation.selector), value);
    }];
    
    // 测试 MyClassB
    [[MyClassC new] sayHelloTo:@"jack"];
}

- (void)memoryLeakA
{
    NSMethodSignature *signature = [NSObject methodSignatureForSelector:@selector(new)];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = MyClassA.class;
    invocation.selector = @selector(new);
    [invocation invoke];
}

- (void)memoryLeakB
{
    [MyClassB performSelector:@selector(new)];
}

- (void)releaseAdvance
{
    [NSClassFromString(@"__NSArrayM") aspect_hookSelector:@selector(insertObject:atIndex:) withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> info){
        
        id value = nil;
        [info.originalInvocation getArgument:&value atIndex:2];
        if (value) {
            [info.originalInvocation invoke];
        }
    } error:NULL];
}

- (void)forwardInvocationTest
{
    [[MyClassA new] performSelector:@selector(sayHello)];
}

- (void)addNewClassPair
{
    Class myCls = objc_allocateClassPair([NSObject class], "MyObject", 0);
    objc_registerClassPair(myCls);
    [self addNewMethodWithClass:myCls];
}

- (void)addNewMethodWithClass:(Class)targetClass
{
    class_addMethod(targetClass, @selector(sayHello), (IMP)sayHello, "v@:");
}

- (void)methodReplace
{
    Method methodA = class_getInstanceMethod(self.class, @selector(myMethodA));
    IMP impA = method_getImplementation(methodA);
    class_replaceMethod(self.class, @selector(myMethodC), impA, method_getTypeEncoding(methodA));
    
    // print: myMethodA
    [self myMethodC];
}

- (void)methodExchange
{
    Method methodA = class_getInstanceMethod(self.class, @selector(myMethodA));
    Method methodB = class_getInstanceMethod(self.class, @selector(myMethodB));
    method_exchangeImplementations(methodA, methodB);
    
    // print: myMethodB
    [self myMethodA];
    
    // print: myMethodA
    [self myMethodB];
}

- (void)myMethodA
{
    NSLog(@"myMethodA");
}

- (void)myMethodB
{
    NSLog(@"myMethodB");
}

- (void)myMethodC
{
    NSLog(@"myMethodC");
}

#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
