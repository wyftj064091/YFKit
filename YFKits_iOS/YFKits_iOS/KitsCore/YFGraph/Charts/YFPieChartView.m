//
//  YFPieChartView.m
//  Cashier
//
//  Created by Yifeng Wu on 13-10-28.
//  Copyright (c) 2013年 Alipay. All rights reserved.
//

#import "YFPieChartView.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

#define   DEGREES_TO_RADIANS(degrees)  ((M_PI * (degrees))/ 180)

@interface YFPieChartView()

@property (nonatomic, strong) CALayer * backgroundRing;

@property (nonatomic, strong) CALayer * highlightRing;

@property (nonatomic, strong) CAShapeLayer * internalBackgroundRing;

@property (nonatomic, strong) CAShapeLayer * internalHighlightRing;

@end

@implementation YFPieChartView
@synthesize backgroundColor = _backgroundColor;
@synthesize highLightColor = _highLightColor;
- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    if (![_backgroundColor isEqual:backgroundColor]) {
        _backgroundColor = backgroundColor;
        self.internalBackgroundRing.strokeColor = self.backgroundColor.CGColor;
    }
}

- (void)setHighLightColor:(UIColor *)highLightColor
{
    if (![_highLightColor isEqual:highLightColor]) {
        _highLightColor = highLightColor;
        self.internalHighlightRing.strokeColor = self.highLightColor.CGColor;
    }
}

- (CAShapeLayer *)_generateRingLayerWithColor:(UIColor *)color angle:(CGFloat)degree radius:(CGFloat)radius animated:(BOOL)animated
{
    CAShapeLayer *circle = [CAShapeLayer layer];
    circle.frame = CGRectMake(0.0f, 0.0f, radius * 2, radius * 2);
    UIBezierPath * bezierPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds)) radius:radius startAngle:DEGREES_TO_RADIANS(-90.0f) endAngle:DEGREES_TO_RADIANS(degree - 90.0f) clockwise:YES];
    circle.path = bezierPath.CGPath;
    // Configure the apperence of the circle
    circle.fillColor = [UIColor clearColor].CGColor;
    circle.strokeColor = color.CGColor;
    circle.lineWidth = 40.0f;
    
    circle.shadowOffset = CGSizeMake(2.0f, 3.0f);
    circle.shadowOpacity = 0.3f;
    
    if (animated) {
        // Configure animation
        CABasicAnimation *drawAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        drawAnimation.duration            = 0.7; // "animate over 10 seconds or so.."
        drawAnimation.repeatCount         = 1.0;  // Animate only once..
        drawAnimation.removedOnCompletion = NO;   // Remain stroked after the animation..
        
        // Animate from no part of the stroke being drawn to the entire stroke being drawn
        drawAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
        drawAnimation.toValue   = [NSNumber numberWithFloat:1.0f];
        
        // Experiment with timing to get the appearence to look the way you want
        drawAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        
        // Add the animation to the circle
        [circle addAnimation:drawAnimation forKey:@"drawCircleAnimation"];
    }
    
    return circle;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundRing = [CALayer layer];
        self.backgroundRing.frame = self.bounds;
        self.backgroundRing.backgroundColor = [[UIColor clearColor] CGColor];
        self.internalBackgroundRing = [self _generateRingLayerWithColor:self.backgroundColor angle:360 radius:105.0f animated:NO];
        [self.backgroundRing addSublayer:self.internalBackgroundRing];
        [self.layer addSublayer:self.backgroundRing];
        
        self.highlightRing = [CALayer layer];
        self.highlightRing.frame = self.bounds;
        self.highlightRing.backgroundColor = [[UIColor clearColor] CGColor];
        [self.layer addSublayer:self.highlightRing];
    }
    return self;
}

- (void)setPercentage:(CGFloat)percentage animated:(BOOL)animated
{
    [self.highlightRing addSublayer:[self _generateRingLayerWithColor:self.highLightColor angle:360 * percentage radius:115.0f animated:animated]];
}

@end
