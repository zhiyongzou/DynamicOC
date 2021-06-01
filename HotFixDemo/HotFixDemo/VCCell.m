//
//  VCCell.m
//  HotFixDemo
//
//  Created by zzyong on 2021/3/22.
//

#import "VCCell.h"
#import "VCModel.h"

@implementation VCCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.textLabel.adjustsFontSizeToFitWidth = YES;
    }
    return self;
}

- (void)setModel:(VCModel *)model {
    _model = model;
    
    self.textLabel.text = model.title;
}

@end
