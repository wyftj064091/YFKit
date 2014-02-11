//
//  YFCancellAbleProtocol.h
//  YFKits_iOS
//
//  Created by Yifeng Wu on 13-8-13.
//  Copyright (c) 2013年 YifengWu. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol YFCancelableProtocol <NSObject>

@property (nonatomic, assign, readonly) BOOL cancel;

@optional
- (void)cancel;
@end

