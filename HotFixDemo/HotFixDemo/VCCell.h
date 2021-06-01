//
//  VCCell.h
//  CommonTest
//
//  Created by zzyong on 2021/3/22.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class VCModel;

@interface VCCell : UITableViewCell

@property (nonatomic, strong) VCModel *model;

@end

NS_ASSUME_NONNULL_END
