//
//  VCModel.h
//  CommonTest
//
//  Created by zzyong on 2021/3/22.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ClickAction)(void);

@interface VCModel : NSObject

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) ClickAction action;

@end

NS_ASSUME_NONNULL_END
