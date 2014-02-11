//
//  YFPieChartView.h
//  Cashier
//
//  Created by Yifeng Wu on 13-10-28.
//  Copyright (c) 2013年 Alipay. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface YFPieChartView : UIView

@property (nonatomic, assign) CGFloat percentage;

@property (nonatomic, strong) UIColor * highLightColor;

@property (nonatomic, strong) UIColor * backgroundColor;

- (void)setPercentage:(CGFloat)percentage animated:(BOOL)animated;
@end
