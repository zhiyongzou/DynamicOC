//
//  ViewController.h
//  HotFixDemo
//
//  Created by zzyong on 2020/6/11.
//  Copyright © 2020 zzyong. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

void sayHello(id self, SEL _cmd);

- (void)myMethodA;

- (void)myMethodB;

- (void)myMethodC;

- (void)myMethodD;

- (void)myEmptyMethod;

- (void)dy_hookMethodWithHookMap:(NSDictionary *)hookMap;

@end

