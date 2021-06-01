//
//  ViewController+DataSource.m
//  HotFixDemo
//
//  Created by zzyong on 2021/3/22.
//


#import <Aspects.h>
#import "VCModel.h"
#import "MyClassA.h"
#import "MyClassB.h"
#import "MyClassC.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "ViewController+DataSource.h"

@implementation ViewController (DataSource)

- (void)setupTestList {
    
    __weak typeof(self) weakSelf = self;
    NSMutableArray *list = [NSMutableArray array];
    
    VCModel *model1 = [VCModel new];
    model1.title = @"动态创建类：MyObject";
    model1.action = ^{
        if (objc_getClass("MyObject") != NULL) {
            NSLog(@"MyObject 已存在");
            return;
        }
        Class myCls = objc_allocateClassPair([NSObject class], "MyObject", 0);
        objc_registerClassPair(myCls);
        
        // 增加 sayHello 方法
        class_addMethod(myCls, @selector(sayHello), (IMP)sayHello, "v@:");
        
        NSLog(@"MyObject 动态创建成功");
    };
    [list addObject:model1];
    
    VCModel *model2 = [VCModel new];
    model2.title = @"调用 MyObject sayHello 方法  ";
    model2.action = ^{
        Class MyObject = NSClassFromString(@"MyObject");
        if (MyObject == NULL) {
            NSLog(@"MyObject 类不存在");
            return;
        }
        NSObject *myObj = [[MyObject alloc] init];
        [myObj performSelector:@selector(sayHello)];
    };
    [list addObject:model2];
    
    VCModel *model3 = [VCModel new];
    model3.title = @"myMethodC 实现替换成 myMethodD";
    model3.action = ^{
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            Method methodD = class_getInstanceMethod(weakSelf.class, @selector(myMethodD));
            IMP impD = method_getImplementation(methodD);
            class_replaceMethod(weakSelf.class, @selector(myMethodC), impD, method_getTypeEncoding(methodD));
            NSLog(@"myMethodC 已替换为 myMethodD");
        });
    };
    [list addObject:model3];
    
    VCModel *model4 = [VCModel new];
    model4.title = @"调用 myMethodC";
    model4.action = ^{
        // print: myMethodA
        [weakSelf myMethodC];
    };
    [list addObject:model4];
    
    VCModel *model5 = [VCModel new];
    model5.title = @"myMethodA 和 myMethodB 方法交换 ";
    model5.action = ^{
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            Method methodA = class_getInstanceMethod(weakSelf.class, @selector(myMethodA));
            Method methodB = class_getInstanceMethod(weakSelf.class, @selector(myMethodB));
            method_exchangeImplementations(methodA, methodB);
            NSLog(@"myMethodA myMethodB 方法已交换");
        });
    };
    [list addObject:model5];
    
    VCModel *model6 = [VCModel new];
    model6.title = @"调用 myMethodA";
    model6.action = ^{
        // print: myMethodB
        [weakSelf myMethodA];
    };
    [list addObject:model6];
    
    VCModel *model7 = [VCModel new];
    model7.title = @"调用 myMethodB";
    model7.action = ^{
        // print: myMethodA
        [weakSelf myMethodB];
    };
    [list addObject:model7];
    
    VCModel *model8 = [VCModel new];
    model8.title = @"forwardInvocation 测试";
    model8.action = ^{
        [[MyClassA new] performSelector:@selector(sayHello)];
    };
    [list addObject:model8];

    VCModel *model9 = [VCModel new];
    model9.title = @"[Fix] myEmptyMethod 替换为空实现";
    model9.action = ^{
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [weakSelf dy_hookMethodWithHookMap:@{
                @"cls": @"ViewController",
                @"sel": @"myEmptyMethod",
                @"isReplcedEmpty": @(YES)
            }];
        });
    };
    [list addObject:model9];

    VCModel *model10 = [VCModel new];
    model10.title = @"调用 myEmptyMethod";
    model10.action = ^{
        [weakSelf myEmptyMethod];
    };
    [list addObject:model10];

    VCModel *model11 = [VCModel new];
    model11.title = @"[Fix] sayHelloTo: 方法参数修改";
    model11.action = ^{
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [weakSelf dy_hookMethodWithHookMap:@{
                @"cls": @"MyClassC",
                @"sel": @"sayHelloTo:",
                @"parameters": @[@"Lili"]
            }];
        });
    };
    [list addObject:model11];

    VCModel *model12 = [VCModel new];
    model12.title = @"调用 sayHello: 方法";
    model12.action = ^{
        // 测试 MyClassC
        [[MyClassC new] sayHelloTo:@"jack"];
    };
    [list addObject:model12];

    VCModel *model13 = [VCModel new];
    model13.title = @"[Fix] className 方法返回值修改";
    model13.action = ^{
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [weakSelf dy_hookMethodWithHookMap:@{
                @"cls": @"MyClassC",
                @"sel": @"className",
                @"returnValue": @"Return value had change"
            }];
        });
    };
    [list addObject:model13];
    
    VCModel *model14 = [VCModel new];
    model14.title = @"调用 className 方法";
    model14.action = ^{
        // 测试 MyClassC
        NSLog(@"%@", [[MyClassC new] className]);
    };
    [list addObject:model14];
    
    VCModel *model15 = [VCModel new];
    model15.title = @"[Fix] myMethod 调用前调用 dynamicCallMethod";
    model15.action = ^{
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [weakSelf dy_hookMethodWithHookMap:@{
                @"cls": @"MyClassC",
                @"sel": @"myMethod",
                @"customMethods": @[@"self.dynamicCallMethod"]
            }];
        });
    };
    [list addObject:model15];
    
    VCModel *model16 = [VCModel new];
    model16.title = @"调用 myMethod 方法";
    model16.action = ^{
        // 测试 MyClassC
        [[MyClassC new] myMethod];
    };
    [list addObject:model16];
    
    VCModel *model17 = [VCModel new];
    model17.title = @"NSInvocation 修改方法参数 EXC_BAD_ACCESS";
    model17.action = ^{
        [NSClassFromString(@"__NSArrayM") aspect_hookSelector:@selector(insertObject:atIndex:) withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> info){
            
            id value = nil;
            [info.originalInvocation getArgument:&value atIndex:2];
            if (value) {
                [info.originalInvocation invoke];
            }
        } error:NULL];
    };
    [list addObject:model17];
    
    VCModel *model18 = [VCModel new];
    model18.title = @"NSInvocation 内存泄漏";
    model18.action = ^{
        {
            NSMethodSignature *signature = [NSObject methodSignatureForSelector:@selector(new)];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            invocation.target = MyClassA.class;
            invocation.selector = @selector(new);
            [invocation invoke];
        }
    };
    [list addObject:model18];
    
    VCModel *model19 = [VCModel new];
    model19.title = @"performSelector 内存泄漏";
    model19.action = ^{
        {
            [MyClassB performSelector:@selector(new)];
        }
    };
    [list addObject:model19];
    
    self.testList = list;
}

@end
