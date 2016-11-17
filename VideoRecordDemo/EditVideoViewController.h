//
//  EditVideoViewController.h
//  VideoRecordDemo
//
//  Created by RainDou on 16/8/15.
//  Copyright © 2016年 RainDou 634778311. All rights reserved.
//

#import <UIKit/UIKit.h>
typedef void(^SaveSuccessBlock)(void);

@interface EditVideoViewController : UIViewController

@property (nonatomic,copy) SaveSuccessBlock editBlock;

- (void)setVideoUrls:(NSMutableArray *)_arr;
@end
