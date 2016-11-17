//
//  UIDragButton.h
//  VideoRecordDemo
//
//  Created by RainDou on 16/8/15.
//  Copyright © 2016年 RainDou 634778311. All rights reserved.
//

#import <UIKit/UIKit.h>
typedef NS_ENUM(NSInteger,Location){
    up = 0,
    down = 1,
};

@class UIDragButton;

@protocol UIDragButtonDelegate <NSObject>

- (void)arrangeUpButtonsWithButton:(UIDragButton *)button andAdd:(BOOL)_bool;
- (void)arrangeDownButtonsWithButton:(UIDragButton *)button andAdd:(BOOL)_bool;
- (void)checkLocationOfOthersWithButton:(UIDragButton *)shakingButton;
- (void)removeShakingButton:(UIDragButton *)button fromUpButtons:(BOOL)_bool;

@end
@interface UIDragButton : UIButton
{
    UIView *superView;
    CGPoint lastPoint;
    NSTimer *timer;
}

@property (nonatomic, assign) Location location;
@property (nonatomic, assign) CGPoint lastCenter;
@property (nonatomic, assign) id<UIDragButtonDelegate> delegate;

- (id)initWithFrame:(CGRect)frame andImage:(UIImage *)image inView:(UIView *)view;
- (void)startShake;
- (void)stopShake;
@end
