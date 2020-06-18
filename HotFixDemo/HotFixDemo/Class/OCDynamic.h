//
//  OCDynamic.h
//  HotFixDemo
//
//  Created by zzyong on 2020/6/17.
//  Copyright © 2020 zzyong. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (OCDynamic)

+ (void)dy_hookSelector:(SEL)selector withBlock:(void(^)(id self, NSInvocation *originalInvocation))block;

@end

NS_ASSUME_NONNULL_END
