//
//  VideoRecordView.h
//  VideoRecordDemo
//
//  Created by RainDou on 16/8/15.
//  Copyright © 2016年 RainDou 634778311. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
extern NSString *const VideoRecordPathKey;

@interface VideoRecordView : UIView
+(instancetype)shareInstance;
/**
 * 因为需要实时显示处理过的视频流，需要自定义一个layer层来显示，如果不需要实时显示处理后的视频流，用系统的AVCaptureVideoPreviewLayer 即可
 */
@property (nonatomic, strong) CALayer *previewVideoLayer;

@property (nonatomic, strong) UIViewController *rootVC;
/**
 *  最大录制视频段数，不要太大， 默认录制2段
 */
@property (nonatomic, assign) NSInteger maxRecordCount;

@end
