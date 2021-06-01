//
//  MyClassC.m
//  HotFixDemo
//
//  Created by zzyong on 2020/6/17.
//  Copyright © 2020 zzyong. All rights reserved.
//

#import "MyClassC.h"

@implementation MyClassC

- (void)sayHelloTo:(NSString *)name
{
    NSLog(@"%s: %@", __func__, name);
}

- (NSString *)className
{
    return @"MyClassC";
}

- (void)myMethod
{
    NSLog(@"%s", __func__);
}

- (void)dynamicCallMethod {
    NSLog(@"%s Dynamic call", __func__);
}

@end
