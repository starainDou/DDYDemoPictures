//
//  EditVideoViewController.m
//  VideoRecordDemo
//
//  Created by RainDou on 16/8/15.
//  Copyright © 2016年 RainDou 634778311. All rights reserved.
//

#import "EditVideoViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "UIDragButton.h"
#import "VideoRecordView.h"
#import <AssetsLibrary/AssetsLibrary.h>
@interface EditVideoViewController ()<UIDragButtonDelegate>
{
    NSMutableArray *video_urls;

    NSMutableArray *upButtons;
    
    UIButton *editButton;
    
    UILabel *tipLabel;

}
@end

@implementation EditVideoViewController
-(void)setVideoUrls:(NSMutableArray *)_arr {
    video_urls = _arr;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    //UIBarButtonItem *backBarItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(backViewController:)];
    //self.navigationItem.leftBarButtonItem = backBarItem;
    upButtons = [NSMutableArray array];
    
    int x = 20;
    int y = 80;
    for (int i=0; i<[video_urls count]; i++) {
        NSDictionary *dic = [video_urls objectAtIndex:i];
        
        UIImage *videoImage = [self getImage:[dic objectForKey:VideoRecordPathKey]];
        if(videoImage){
            UIDragButton *button1 = [[UIDragButton alloc] initWithFrame:CGRectMake(x, y, 80, 80) andImage:videoImage inView:self.view];
            [upButtons addObject:button1];
        }
        x += 100;
        
        if((i+1)%3==0 && i>0){
            x = 20;
            y += 100;
        }
    }
    
    for ( int i = 0; i < [upButtons count]; i++) {
        UIDragButton *button = [upButtons objectAtIndex:i];
        [button setLocation:up];
        [button setDelegate:self];
        [button setTag:i];
        [self.view addSubview:button];
    }
    tipLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    tipLabel.frame = CGRectMake(0, 0, ScreenWidth, 40);
    tipLabel.center = CGPointMake(ScreenWidth /2, (ScreenHeight - 80)/2);
    tipLabel.textColor = [UIColor darkGrayColor];
    tipLabel.text = @"长按视频可进行拖动排序";
    tipLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:tipLabel];
    editButton = [UIButton buttonWithType:UIButtonTypeCustom];
    editButton.frame = CGRectMake(0, 0, ScreenWidth / 2, 40);
    editButton.center = CGPointMake(ScreenWidth / 2, ScreenHeight / 2);
    [editButton setTitle:@"生  成  视  频" forState:UIControlStateNormal];
    editButton.backgroundColor = [UIColor blueColor];
    [editButton addTarget:self action:@selector(toVideo:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:editButton];
    // Do any additional setup after loading the view.
}

#pragma mark - 设置按钮的frame

- (void)checkLocationOfOthersWithButton:(UIDragButton *)shakingButton
{
    switch (shakingButton.location) {
        case up:
        {
            int indexOfShakingButton = 0;
            for ( int i = 0; i < [upButtons count]; i++) {
                if (((UIDragButton *)[upButtons objectAtIndex:i]).tag == shakingButton.tag) {
                    indexOfShakingButton = i;
                    break;
                }
            }
            for (int i = 0; i < [upButtons count]; i++) {
                UIDragButton *button = (UIDragButton *)[upButtons objectAtIndex:i];
                if (button.tag != shakingButton.tag){
                    if (CGRectIntersectsRect(shakingButton.frame, button.frame)) {
                        [upButtons exchangeObjectAtIndex:i withObjectAtIndex:indexOfShakingButton];
                        
                        [video_urls exchangeObjectAtIndex:i withObjectAtIndex:indexOfShakingButton];
                        
                        [self setUpButtonsFrameWithAnimate:YES withoutShakingButton:shakingButton];
                        break;
                    }
                }
            }
            
            break;
        }
        default:
            break;
    }
}

- (void)setUpButtonsFrameWithAnimate:(BOOL)_bool withoutShakingButton:(UIDragButton *)shakingButton
{
    NSInteger count = [upButtons count];
    if (shakingButton != nil) {
        if (_bool) {
            [UIView animateWithDuration:0.4 animations:^{
                for (int y = 0; y <= count / 3; y++) {
                    for (int x = 0; x < 3; x++) {
                        int i = 3 * y + x;
                        if (i < count) {
                            UIDragButton *button = (UIDragButton *)[upButtons objectAtIndex:i];
                            if (button.tag != shakingButton.tag) {
                                [button setFrame:CGRectMake(20 + x * 100, 80 + y * 100, 80, 80)];
                            }
                            [button setLastCenter:CGPointMake(20 + x * 100 + 50, 80 + y * 100 + 50)];
                        }
                    }
                }
            }];
        }else{
            for (int y = 0; y <= count / 3; y++) {
                for (int x = 0; x < 3; x++) {
                    int i = 3 * y + x;
                    if (i < count) {
                        UIDragButton *button = (UIDragButton *)[upButtons objectAtIndex:i];
                        if (button.tag != shakingButton.tag) {
                            [button setFrame:CGRectMake(20 + x * 100, 80 + y * 100, 80, 80)];
                        }
                        [button setLastCenter:CGPointMake(20 + x * 100 + 50, 80 + y * 100 + 50)];
                    }
                }
            }
        }
        
    }else{
        if (_bool) {
            [UIView animateWithDuration:0.4 animations:^{
                for (int y = 0; y <= count / 3; y++) {
                    for (int x = 0; x < 3; x++) {
                        int i = 3 * y + x;
                        if (i < count) {
                            UIDragButton *button = (UIDragButton *)[upButtons objectAtIndex:i];
                            [button setFrame:CGRectMake(20 + x * 100, 80 + y * 100, 80, 80)];
                            [button setLastCenter:CGPointMake(20 + x * 100 + 50, 80 + y * 100 + 50)];
                        }
                    }
                }
            }];
        }else{
            for (int y = 0; y <= count / 3; y++) {
                for (int x = 0; x < 3; x++) {
                    int i = 3 * y + x;
                    if (i < count) {
                        UIDragButton *button = (UIDragButton *)[upButtons objectAtIndex:i];
                        [button setFrame:CGRectMake(20 + x * 100, 80 + y * 100, 80, 80)];
                        [button setLastCenter:CGPointMake(20 + x * 100 + 50, 80 + y * 100 + 50)];
                    }
                }
            }
        }
    }
}

#pragma mark - UIDragButton Delegate

- (void)removeShakingButton:(UIDragButton *)button fromUpButtons:(BOOL)_bool
{
    if (_bool) {
        if ([upButtons containsObject:button]) {
            [upButtons removeObject:button];
        }
    }
}

- (void)arrangeUpButtonsWithButton:(UIDragButton *)button andAdd:(BOOL)_bool
{
    if (_bool) {
        if (![upButtons containsObject:button]) {
            [upButtons addObject:button];
        }
    }
    
    if (upButtons.count <= 0) return;
    [self setUpButtonsFrameWithAnimate:YES withoutShakingButton:nil];
}

- (void)arrangeDownButtonsWithButton:(UIDragButton *)button andAdd:(BOOL)_bool
{
    if (!_bool) {
        
        [upButtons addObject:button];
    }
    
}

-(UIImage *)getImage:(NSURL *)videoURL
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    gen.appliesPreferredTrackTransform = YES;
    CMTime time = CMTimeMakeWithSeconds(1.0, 600);
    NSError *error = nil;
    CMTime actualTime;
    CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];
    UIImage *thumb = [[UIImage alloc] initWithCGImage:image];
    CGImageRelease(image);
    return thumb;
    
}


-(void)toVideo:(id)sender{
    
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition
                                                        addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    for (NSInteger k=video_urls.count-1;k>=0;k--) {
        NSDictionary *dic = [video_urls objectAtIndex:k];
        NSURL *videoUrl = [dic objectForKey:VideoRecordPathKey];
        
        AVURLAsset* videoAsset = [[AVURLAsset alloc] initWithURL:videoUrl options:nil];
        [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration)
                                       ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                                        atTime:kCMTimeZero error:nil];
        [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:kCMTimeZero error:nil];
        
    }
    
    AVAssetExportSession* _assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                                          presetName:AVAssetExportPresetPassthrough];
    NSString* videoName = @"export.mp4";
    NSString *exportPath = [NSTemporaryDirectory() stringByAppendingPathComponent:videoName];
    NSURL    *exportUrl = [NSURL fileURLWithPath:exportPath];
    
    _assetExport.outputURL = exportUrl;
    _assetExport.outputFileType = AVFileTypeQuickTimeMovie;
    
    _assetExport.shouldOptimizeForNetworkUse = YES;
    [_assetExport exportAsynchronouslyWithCompletionHandler:^
     {
         ALAssetsLibrary *_assetLibrary = [[ALAssetsLibrary alloc] init];
         
         [_assetLibrary writeVideoAtPathToSavedPhotosAlbum:exportUrl completionBlock:^(NSURL *assetURL, NSError *error1) {
             if(!error1){
                 
                 
                 
                 NSFileManager *fileManager = [NSFileManager defaultManager];
                 if([fileManager fileExistsAtPath:exportPath]){
                     [fileManager removeItemAtPath:exportPath error:nil];
                 }
                 
                 for (int k=0;k<[video_urls count];k++) {
                     NSDictionary *dic = [video_urls objectAtIndex:k];
                     NSURL *videoUrl = [dic objectForKey:VideoRecordPathKey];
                     if([fileManager fileExistsAtPath:[videoUrl path]]){
                         [fileManager removeItemAtPath:[videoUrl path] error:nil];
                     }
                 }
                 dispatch_async(dispatch_get_main_queue(), ^{
                     UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"成功!" message: @"保存到相机胶卷."
                                                                    delegate:nil
                                                           cancelButtonTitle:nil
                                                           otherButtonTitles:@"确定", nil];
                     [alert show];
                 });
               
                 
                 self.editBlock();
           
                [self backViewController:nil];

             }else{
                 
             }
         }];
     }];
    
}

-(void)backViewController:(id)sender{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
