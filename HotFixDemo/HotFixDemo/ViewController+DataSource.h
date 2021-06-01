//
//  ViewController+DataSource.h
//  CommonTest
//
//  Created by zzyong on 2021/3/22.
//

#import "ViewController.h"

NS_ASSUME_NONNULL_BEGIN

@class VCModel;

@interface ViewController ()

@property (nonatomic, strong) NSArray<VCModel *> *testList;

@end

@interface ViewController (DataSource)

- (void)setupTestList;

@end


NS_ASSUME_NONNULL_END
