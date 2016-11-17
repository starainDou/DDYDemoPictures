//
//  ViewController.m
//  VideoRecordDemo
//
//  Created by RainDou on 16/8/15.
//  Copyright © 2016年 RainDou 634778311. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MediaPlayer/MediaPlayer.h>
#import "VideoRecordView.h"

@interface ViewController ()


@end

@implementation ViewController

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];


    [self.view addSubview:[VideoRecordView shareInstance]];
    [VideoRecordView shareInstance].rootVC = self;
    [[VideoRecordView shareInstance] setMaxRecordCount:3]; 


}


- (void)viewDidLoad {
    [super viewDidLoad];
    
  
    // Do any additional setup after loading the view, typically from a nib.
}



@end
