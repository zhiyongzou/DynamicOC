//
//  ViewController.m
//  HotFixDemo
//
//  Created by zzyong on 2020/6/11.
//  Copyright © 2020 zzyong. All rights reserved.
//

#import "VCCell.h"
#import "VCModel.h"
#import "OCDynamic.h"
#import "ViewController.h"
#import "ViewController+DataSource.h"

@interface ViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupTestList];
    [self.view addSubview:self.tableView];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.tableView.frame = self.view.bounds;
}

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.backgroundColor = [UIColor whiteColor];
        _tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        _tableView.dataSource = self;
        _tableView.delegate = self;
        _tableView.rowHeight = 50;
        _tableView.estimatedSectionFooterHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.estimatedRowHeight = 0;
        [_tableView registerClass:[VCCell class] forCellReuseIdentifier:@"VCCell"];
    }
    return _tableView;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.testList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    VCModel *testModel = [self.testList objectAtIndex:indexPath.row];
    VCCell *cell = [tableView dequeueReusableCellWithIdentifier:@"VCCell" forIndexPath:indexPath];
    cell.model = testModel;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    VCModel *testModel = [self.testList objectAtIndex:indexPath.row];
    testModel.action();
}

#pragma mark - Public

- (void)myEmptyMethod {
    NSLog(@"%s", __func__);
}

void sayHello(id self, SEL _cmd) {
    NSLog(@"%@ %s", self, __func__);
}

- (void)myMethodA {
    NSLog(@"myMethodA");
}

- (void)myMethodB {
    NSLog(@"myMethodB");
}

- (void)myMethodC {
    NSLog(@"myMethodC");
}

- (void)myMethodD {
    NSLog(@"myMethodD");
}

- (void)dy_hookMethodWithHookMap:(NSDictionary *)hookMap {
    Class cls = NSClassFromString([hookMap objectForKey:@"cls"]);
    SEL sel = NSSelectorFromString([hookMap objectForKey:@"sel"]);
    NSArray *parameters = [hookMap objectForKey:@"parameters"];
    NSArray<NSString *> *customMethods = [hookMap objectForKey:@"customMethods"];
    
    [cls dy_hookSelector:sel withBlock:^(id  _Nonnull self, NSInvocation * _Nonnull originalInvocation) {
    
        if ([hookMap[@"isReplcedEmpty"] boolValue]) {
            NSLog(@"[%@ %@] replace into empty IMP", cls, NSStringFromSelector(sel));
            return;
        }
        
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

@end
