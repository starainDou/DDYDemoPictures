//
//  VideoRecordView.m
//  VideoRecordDemo
//
//  Created by RainDou on 16/8/15.
//  Copyright © 2016年 RainDou 634778311. All rights reserved.
//

#import "VideoRecordView.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "EditVideoViewController.h" 
#import <GLKit/GLKit.h>

typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

NSString * const VideoRecordPathKey = @"VideoRecordPathKey";

@interface VideoRecordView ()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate,AVCaptureMetadataOutputObjectsDelegate>
{
    AVCaptureSession *captureSession;
    
    AVCaptureDeviceInput *captureDeviceInput;
    AVCaptureDeviceInput *audioDeviceInput;
    
    AVCaptureVideoDataOutput *videoDataOutput;
    AVCaptureAudioDataOutput *audioDataOutput;
    AVCaptureMetadataOutput  *metaDataOutput;
    
    AVCaptureConnection *videoConnection;
    AVCaptureConnection *audioConnection;
    
    CMFormatDescriptionRef audioFormatDescription;
    
    CIFilter *filter;
    
    dispatch_queue_t videoDataOutputQueue;
    GLKView *preViewLayer;
    
    UIButton *recordButton;
    UIButton *doneButton;
    UIView *toolBarView;
    
    UIView *navgationView;
    UIButton *toggleButton;
    
    UIView *preBackView;
    UIImageView *focusCursor;
    UILabel *tipLabel;
    
    
    AVAssetWriter *assetWriter;
    AVAssetWriterInput *assertWriteVideoInput;
    AVAssetWriterInput *assertWriteAudioInput;
    
    AVAssetWriterInputPixelBufferAdaptor *assetWriterPixelBufferInput;
    NSURL *outputURL;
    CMVideoDimensions currentVideoDimensions;
    CMTime currentSampleTime;
    int videoIndex;
    NSMutableArray *audioMixParams;
    NSMutableArray *videoUrls;
    
    
    EAGLContext  *eaglContext;
    BOOL isRecording;
    
    AVMetadataFaceObject *faceObject;
}
@property (nonatomic, strong)    CIContext *context;
@property (nonatomic, strong)    NSURL *mixURL;
@property (nonatomic, strong)    NSURL *theEndVideoURL;
@end


@implementation VideoRecordView

+(instancetype)shareInstance {
    static VideoRecordView *singleTon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleTon = [[VideoRecordView alloc] init];
    });
    return singleTon;
}
-(instancetype)init {
    self = [super init];
    if (self) {
        self.frame = CGRectMake(0, 0, ScreenWidth, ScreenHeight);
        videoUrls = [NSMutableArray array];
        _maxRecordCount = 2;
        [self initVideoCaptureView];
        [self setCaptureSession];
        

    }
    return self;
}
- (CIContext *)context {
    if (!_context) {
        NSDictionary *options = @{kCIContextWorkingColorSpace:[NSNull null]};
        
        _context = [CIContext contextWithEAGLContext:eaglContext options:options];
    }
    return _context;
}
-(void)setMaxRecordCount:(NSInteger)maxRecordCount {
    _maxRecordCount = maxRecordCount;
    tipLabel.text = [NSString stringWithFormat:@"点击右侧对号按钮，结束当前录制，最多可录制%ld段视频",maxRecordCount];
}
-(void)setCaptureSession {
    captureSession = [[AVCaptureSession alloc] init];
    [captureSession beginConfiguration];
    if ([captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    }
    AVCaptureDevice *captureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    
    CMTime frameDuration = CMTimeMake(3, 10);
    NSArray *supportedFrameRateRanges = [captureDevice.activeFormat videoSupportedFrameRateRanges];
    BOOL frameRateSupported = NO;
    
    for (AVFrameRateRange *range in supportedFrameRateRanges) {
        NSLog(@"%@",range);
        if (CMTIME_COMPARE_INLINE(frameDuration, >=, range.minFrameDuration) &&
            CMTIME_COMPARE_INLINE(frameDuration, <=, range.maxFrameDuration)) {
            frameRateSupported = YES;
        }
    }
    if (!captureDevice) {
        NSLog(@"获取后置摄像头失败");
        return;
    }
    
    AVCaptureDevice *audioDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    NSError *error;
    captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    if (error) {
        NSLog(@"获取视频输入失败:%@",error);
        return;
    }
    
    audioDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:&error];
    if (error) {
        NSLog(@"获取音频输入失败:%@",error);
        return;
    }
    
    if ([captureSession canAddInput:captureDeviceInput]) {
        [captureSession addInput:captureDeviceInput];
        [captureSession addInput:audioDeviceInput];
    }
    
    videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    metaDataOutput = [[AVCaptureMetadataOutput alloc] init];
    NSLog(@"%@", [metaDataOutput availableMetadataObjectTypes]);

    
    
    videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
   
    videoDataOutput.videoSettings = [NSDictionary dictionaryWithObject:@(kCVPixelFormatType_32BGRA) forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
    [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    
    if ([captureSession canAddOutput:videoDataOutput]) {
        [captureSession addOutput:videoDataOutput];
        [captureSession addOutput:audioDataOutput];
        [captureSession addOutput:metaDataOutput];
        metaDataOutput.metadataObjectTypes = @[AVMetadataObjectTypeFace];

    }
    [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    [audioDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    [metaDataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];

   
    filter = [CIFilter filterWithName:@"CIPhotoEffectChrome"];

    videoConnection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    
    audioConnection = [audioDataOutput connectionWithMediaType:AVMediaTypeAudio];
    
    [captureSession commitConfiguration];
    [captureSession startRunning];
}
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position {
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in cameras) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
  
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    @autoreleasepool {
        if (captureOutput == videoDataOutput) {
            CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            CMVideoFormatDescriptionRef formatDescription =  CMSampleBufferGetFormatDescription(sampleBuffer);
           
          
            
            currentVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
            currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
            __block  CIImage *outputImage =[CIImage imageWithCVPixelBuffer:imageBuffer];
            
            dispatch_async(videoDataOutputQueue, ^{
                [filter setValue:outputImage forKey:kCIInputImageKey];
                outputImage = filter.outputImage;
                if (faceObject != nil) {
                    outputImage = [self faceImage:outputImage faceObject:faceObject];
                }
                
                if (assetWriterPixelBufferInput && assetWriterPixelBufferInput.assetWriterInput.readyForMoreMediaData) {
                    CVPixelBufferRef outputBuffer;
                    
                    CVPixelBufferPoolCreatePixelBuffer(nil, assetWriterPixelBufferInput.pixelBufferPool, &outputBuffer);
                    [self.context render:outputImage toCVPixelBuffer:outputBuffer bounds:outputImage.extent colorSpace:nil];
                    [assetWriterPixelBufferInput appendPixelBuffer:outputBuffer withPresentationTime:currentSampleTime];
                    CVPixelBufferRelease(outputBuffer);
                }
                
                
                //[preViewLayer bindDrawable];
                //[self.context drawImage:outputImage inRect:outputImage.extent fromRect:outputImage.extent];
                __block CGImageRef cgImage = [self.context createCGImage:outputImage fromRect:outputImage.extent];
                dispatch_sync(dispatch_get_main_queue(), ^{
                    //[preViewLayer display];
                    _previewVideoLayer.contents =  (__bridge id)cgImage;
                    CGImageRelease(cgImage);
                    
                });
                
            });
            
        } else {
            audioFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
            if (assertWriteAudioInput && assertWriteAudioInput.readyForMoreMediaData) {
                if ( assetWriter.status == AVAssetWriterStatusUnknown ) {
                    
                    if ([assetWriter startWriting]) {
                        CMTime startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                        [assetWriter startSessionAtSourceTime:startTime];
                        NSLog(@"asset writer started writing with status (%ld)", assetWriter.status);
                    } else {
                        NSLog(@"asset writer error when starting to write (%@)", [assetWriter error]);
                    }
                    
                }
                if ( assetWriter.status == AVAssetWriterStatusFailed ) {
                    NSLog(@"asset writer failure, (%@)", assetWriter.error.localizedDescription);
                    return;
                }
                if (assetWriter.status == AVAssetWriterStatusWriting) {
                    [assertWriteAudioInput appendSampleBuffer:sampleBuffer];
                }
                
            }
        }
        
    }
}
#pragma mark - 
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    if (metadataObjects.count > 0) {
        faceObject = (AVMetadataFaceObject *)metadataObjects.firstObject;
    } else {
        faceObject = nil;
    }
}
-(CIImage *)faceImage:(CIImage *)faceImage faceObject:(AVMetadataFaceObject *)faceDataObject {
    
    CIFilter *faceFilter = [CIFilter filterWithName:@"CIPixellate"];
    [faceFilter setValue:faceImage forKey:kCIInputImageKey];
    [faceFilter setValue:@(MAX(faceImage.extent.size.width, faceImage.extent.size.height)/60) forKey:kCIInputScaleKey];

    CIImage *fullPixellImage = faceFilter.outputImage;
    CIImage *maskImage ;
    CGRect faceBounds = faceDataObject.bounds;
    CGFloat centerX = faceImage.extent.size.width * (faceBounds.origin.x + faceBounds.size.width / 2);
    CGFloat centerY = faceImage.extent.size.height * (1 - faceBounds.origin.y - faceBounds.size.height / 2);
    CGFloat radius = faceBounds.size.width * faceImage.extent.size.width / 2;
    

    CIFilter *radialFilter = [CIFilter filterWithName:@"CIRadialGradient" withInputParameters:@{
    @"inputRadius0":[NSNumber numberWithFloat:radius],
    @"inputRadius1":[NSNumber numberWithFloat:radius + 1],
    @"inputColor0":[CIColor colorWithRed:0 green:1 blue:0 alpha:1],
        @"inputColor1":[CIColor colorWithRed:0 green:0 blue:0 alpha:0],
    kCIInputCenterKey:[CIVector vectorWithX:centerX Y:centerY]
    }];
    CIImage *radialGradientOutputImage = [radialFilter.outputImage imageByCroppingToRect:faceImage.extent];
    if (maskImage == nil) {
        maskImage = radialGradientOutputImage;
    } else {
        maskImage = [CIFilter filterWithName:@"CISourceOverCompositing" withInputParameters:@{kCIInputImageKey:radialGradientOutputImage,kCIInputBackgroundImageKey:maskImage}].outputImage;
    }
    
    CIFilter *blendFilter = [CIFilter filterWithName:@"CIBlendWithMask"];
    [blendFilter setValue:fullPixellImage forKey:kCIInputImageKey];
    [blendFilter setValue:faceImage forKey:kCIInputBackgroundImageKey];
    [blendFilter setValue:maskImage forKey:kCIInputMaskImageKey];
    return blendFilter.outputImage;
}
/**
 *
 */
-(void)initVideoCaptureView {
    toolBarView = [[UIView alloc] initWithFrame:CGRectMake(0, ScreenHeight - 100, ScreenWidth, 100)];
    toolBarView.backgroundColor = [UIColor cyanColor];
    [self addSubview:toolBarView];
    
    tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0,(ScreenWidth - 100) / 2,  100)];
    tipLabel.textColor = [UIColor whiteColor];
    tipLabel.text = @"点击右侧对号按钮，结束当前录制，最多可录制2段视频";
    tipLabel.textAlignment = NSTextAlignmentCenter;
    tipLabel.numberOfLines = 0;
    [toolBarView addSubview:tipLabel];
    
    recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    recordButton.frame = CGRectMake(0, 0, 72, 72);
    [recordButton setImage:[UIImage imageNamed:@"icon_facial_btn_take"] forState:UIControlStateNormal];
    [recordButton setBackgroundImage:[UIImage imageNamed:@"sc_btn_take"] forState:UIControlStateNormal];
    [recordButton addTarget:self action:@selector(startRecordVideo:) forControlEvents:UIControlEventTouchUpInside];
    recordButton.center = CGPointMake(ScreenWidth / 2, toolBarView.frame.size.height / 2);
    [toolBarView addSubview:recordButton];
    
    doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    doneButton.frame = CGRectMake(0, 0, 50, 50);
    [doneButton setImage:[UIImage imageNamed:@"btn_camera_done_a"] forState:UIControlStateNormal];
    doneButton.hidden = YES;
    [doneButton addTarget:self action:@selector(doneButtonClick:) forControlEvents:UIControlEventTouchUpInside];
     doneButton.center = CGPointMake(ScreenWidth  * 3 / 4, toolBarView.frame.size.height / 2);
    [toolBarView addSubview:doneButton];
    
    navgationView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ScreenWidth, 64)];
    navgationView.backgroundColor = [UIColor blackColor];
    [self addSubview:navgationView];
    
    toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    toggleButton.frame = CGRectMake((ScreenWidth - 40 ) / 2, 20, 40, 40);
    [toggleButton setImage:[UIImage imageNamed:@"btn_video_flip_camera"] forState:UIControlStateNormal];
    [toggleButton addTarget:self action:@selector(toggleButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [navgationView addSubview:toggleButton];
    
    preBackView = [[UIView alloc] initWithFrame:CGRectZero];
    preBackView.frame = CGRectMake(0, 64, ScreenWidth, ScreenHeight - 164);
    preBackView.layer.masksToBounds = YES;
    CGRect previewBounds = preBackView.layer.bounds;
    self.previewVideoLayer = [[CALayer alloc] init];
    self.previewVideoLayer.contentsGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewVideoLayer.bounds = previewBounds;
    self.previewVideoLayer.position = CGPointMake(CGRectGetMidX(previewBounds), CGRectGetMidY(previewBounds));
    self.previewVideoLayer.affineTransform  = CGAffineTransformMakeRotation(M_PI / 2.0);
    [preBackView.layer addSublayer:self.previewVideoLayer];
    [self addSubview:preBackView];
    eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    //preViewLayer = [[GLKView alloc] initWithFrame:CGRectMake(0, 0, ScreenWidth + 80 , ScreenHeight-200) context:eaglContext];
    //preViewLayer.transform = CGAffineTransformMakeRotation(M_PI / 2.0);
    //[preBackView addSubview:preViewLayer];
    
    focusCursor = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 76, 76)];
    focusCursor.image = [UIImage imageNamed:@"camera_focus_red"];
    focusCursor.alpha = 0;
    [preBackView addSubview:focusCursor];
    
    UITapGestureRecognizer *tapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
    [self addGestureRecognizer:tapGesture];

}
//开始录制
-(void)startRecordVideo:(UIButton *)sender {
    recordButton.hidden = YES;
    doneButton.hidden = NO;
    if (isRecording) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"正在录制中，请点击右侧对号按钮结束本段录制" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        return;
    }
    isRecording = YES;
    if (videoUrls.count ==_maxRecordCount) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:[NSString stringWithFormat:@"一次最多可录制%ld个视频，请点击√处理视频后在继续录制视频.",_maxRecordCount] delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        return;
    }
    videoIndex++;
    NSString *outputPath = [NSString stringWithFormat:@"%@video_%d.mov", NSTemporaryDirectory(), videoIndex];
    outputURL = [NSURL fileURLWithPath:outputPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:outputPath error:&error]) {
            NSLog(@"could not setup an output file");
            outputURL = nil;
            return;
        }
    }
 
    [self setAssertWriterVideoInput];
    [self setupAssetWriterAudioInput];
    [assetWriter startWriting];
    [assetWriter startSessionAtSourceTime:currentSampleTime];
}
//视频写入设置
-(void)setAssertWriterVideoInput {
    NSError *error;
    assetWriter = [[AVAssetWriter alloc] initWithURL:outputURL fileType:AVFileTypeQuickTimeMovie error:&error];
    NSDictionary *outputSetting = @{AVVideoCodecKey:AVVideoCodecH264,
                                    AVVideoWidthKey:@(currentVideoDimensions.width),
                                    AVVideoHeightKey:@(currentVideoDimensions.height)
                                    };
    assertWriteVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSetting];
    assertWriteVideoInput.expectsMediaDataInRealTime = YES;
    assertWriteVideoInput.transform = CGAffineTransformIdentity;
    
    
    NSDictionary *sourcePixelBufferAttributesDictionary = @{
                                                            (NSString *)kCVPixelBufferPixelFormatTypeKey :[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
                                                            (NSString *)kCVPixelBufferWidthKey:@(currentVideoDimensions.width),
                                                            (NSString *)kCVPixelBufferHeightKey:@(currentVideoDimensions.height),
                                                            (NSString *)kCVPixelFormatOpenGLESCompatibility:(NSNumber *)kCFBooleanTrue
                                                            };
    assetWriterPixelBufferInput = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:assertWriteVideoInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    if ([assetWriter canAddInput:assertWriteVideoInput]) {
        [assetWriter addInput:assertWriteVideoInput];
    }
}

//音频写入设置
-(BOOL)setupAssetWriterAudioInput {
    const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDescription);
    if (!asbd) {
        NSLog(@"audio stream description used with non-audio format description");
        return NO;
    }
    
    unsigned int channels = asbd->mChannelsPerFrame;//声道
    double sampleRate = asbd->mSampleRate;//采样频率
    int bitRate = 64000;
    
    NSLog(@"audio stream setup, channels (%d) sampleRate (%f)", channels, sampleRate);
    
    size_t aclSize = 0;
    const AudioChannelLayout *currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(audioFormatDescription, &aclSize);
    NSData *currentChannelLayoutData = ( currentChannelLayout && aclSize > 0 ) ? [NSData dataWithBytes:currentChannelLayout length:aclSize] : [NSData data];
    
    NSDictionary *audioCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithInt:kAudioFormatMPEG4AAC], AVFormatIDKey,
                                              [NSNumber numberWithUnsignedInt:channels], AVNumberOfChannelsKey,
                                              [NSNumber numberWithDouble:sampleRate], AVSampleRateKey,
                                              [NSNumber numberWithInt:bitRate], AVEncoderBitRateKey,
                                              currentChannelLayoutData, AVChannelLayoutKey, nil];
    
    if ([assetWriter canApplyOutputSettings:audioCompressionSettings forMediaType:AVMediaTypeAudio]) {
        assertWriteAudioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioCompressionSettings];
        assertWriteAudioInput.expectsMediaDataInRealTime = YES;
        NSLog(@"prepared audio-in with compression settings sampleRate (%f) channels (%d) bitRate (%d)", sampleRate, channels, bitRate);
        if ([assetWriter canAddInput:assertWriteAudioInput]) {
            [assetWriter addInput:assertWriteAudioInput];
        } else {
            NSLog(@"couldn't add asset writer audio input");
            return NO;
        }
    } else {
        NSLog(@"couldn't apply audio output settings");
        return NO;
    }
    
    return YES;

}
//切换摄像头
-(void)toggleButtonClick:(UIButton *)sender {
    AVCaptureDevice *currentDevice= [captureDeviceInput device];
    AVCaptureDevicePosition currentPosition = [currentDevice position];
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition=AVCaptureDevicePositionFront;
    if (currentPosition==AVCaptureDevicePositionUnspecified||currentPosition==AVCaptureDevicePositionFront) {
        toChangePosition=AVCaptureDevicePositionBack;
    }
    toChangeDevice=[self getCameraDeviceWithPosition:toChangePosition];
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        //captureDevice.subjectAreaChangeMonitoringEnabled = YES;
    }];
    NSError *error;
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:toChangeDevice error:&error];
    NSLog(@"获取设备失败%@",error.localizedDescription);
    
    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [captureSession beginConfiguration];
    //移除原有输入对象
    [captureSession removeInput:captureDeviceInput];
    //添加新的输入对象
    if ([captureSession canAddInput:toChangeDeviceInput]) {
        [captureSession addInput:toChangeDeviceInput];
        captureDeviceInput=toChangeDeviceInput;
    }
    //提交会话配置
    [captureSession commitConfiguration];
}

-(void)doneButtonClick:(UIButton *)sender {
    if (!isRecording) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"请点击录制按钮开始录制" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        return;
    }
    assetWriterPixelBufferInput = nil;
    assertWriteAudioInput = nil;
    [assetWriter finishWritingWithCompletionHandler:^{
        
        [self saveVideoToAlbum];
        [self addBackGroundMusic];
        
        
    }];
    recordButton.hidden = NO;
    doneButton.hidden = YES;
}

//保存到相册
-(void)saveVideoToAlbum {
    ALAssetsLibrary *assetLibary  = [[ALAssetsLibrary alloc] init];
    [assetLibary writeVideoAtPathToSavedPhotosAlbum:outputURL completionBlock:^(NSURL *assetURL, NSError *error) {
        NSFileManager *fileManager=[NSFileManager defaultManager];
        if([fileManager fileExistsAtPath:outputURL.path]){
            long long size=[fileManager attributesOfItemAtPath:outputURL.path error:nil].fileSize;
            NSLog(@"-------------%fMB",  size/1024.0/1024.0);
        }
        NSLog(@"--------%@",error);
    }];
}
#pragma mark - 添加背景音乐

- (void)addBackGroundMusic {
    AVMutableComposition *composition =[AVMutableComposition composition];
    audioMixParams =[NSMutableArray array];
    
    //录制的视频
   
    AVURLAsset *songAsset =[AVURLAsset URLAssetWithURL:outputURL options:nil];
    CMTime startTime =CMTimeMakeWithSeconds(0,songAsset.duration.timescale);
    CMTime trackDuration =songAsset.duration;
    
    //获取视频中的音频素材
    [self setUpAndAddAudioAtPath:outputURL toComposition:composition start:startTime dura:trackDuration offset:CMTimeMake(14*44100,44100)];
    
    //本地要插入的音乐
    NSString *bundleDirectory =[[NSBundle mainBundle]bundlePath];
    NSString *path = [bundleDirectory stringByAppendingPathComponent:@"music.mp3"];
    NSURL *assetURL2 =[NSURL fileURLWithPath:path];
    //获取设置完的本地音乐素材
    [self setUpAndAddAudioAtPath:assetURL2 toComposition:composition start:startTime dura:trackDuration offset:CMTimeMake(0,44100)];
    
    //创建一个可变的音频混合
    AVMutableAudioMix *audioMix =[AVMutableAudioMix audioMix];
    audioMix.inputParameters =[NSArray arrayWithArray:audioMixParams];//从数组里取出处理后的音频轨道参数
    NSLog(@"audioMix.inputParameters:::::%@",audioMix.inputParameters);
    //创建一个输出
    AVAssetExportSession *exporter =[[AVAssetExportSession alloc]
                                     initWithAsset:composition
                                     presetName:AVAssetExportPresetAppleM4A];
    exporter.audioMix = audioMix;
    exporter.outputFileType=@"com.apple.m4a-audio";
    NSString* fileName =[NSString stringWithFormat:@"%@_%d.mov",@"overMix",videoIndex];
    //输出路径
    NSString *exportFile =[NSString stringWithFormat:@"%@/%@",[self getLibarayPath], fileName];
    
    if([[NSFileManager defaultManager]fileExistsAtPath:exportFile]) {
        [[NSFileManager defaultManager]removeItemAtPath:exportFile error:nil];
    }
    NSLog(@"是否在主线程1%d",[NSThread isMainThread]);
    NSLog(@"输出路径===%@",exportFile);
    
    NSURL *exportURL =[NSURL fileURLWithPath:exportFile];
    exporter.outputURL = exportURL;
    self.mixURL =exportURL;
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        int exportStatus =(int)exporter.status;
        switch (exportStatus){
            case AVAssetExportSessionStatusFailed:{
                NSError *exportError = exporter.error;
                NSLog(@"错误，信息: %@", exportError);
                break;
            }
            case AVAssetExportSessionStatusCompleted:{
                NSLog(@"是否在主线程2%d",[NSThread isMainThread]);
                NSLog(@"成功");
                //最终混合
                [self theVideoWithMixMusic];
                break;
            }
        }
    }];
}
//最终音频和视频混合
-(void)theVideoWithMixMusic
{
    NSError *error =nil;
    NSFileManager *fileMgr =[NSFileManager defaultManager];
    NSString *documentsDirectory =[NSHomeDirectory()
                                   stringByAppendingPathComponent:@"Documents"];
    NSString *videoOutputPath =[documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"test_output_%d.mp4",videoIndex]];
    if ([fileMgr removeItemAtPath:videoOutputPath error:&error]!=YES) {
        NSLog(@"无法删除文件，错误信息：%@",[error localizedDescription]);
    }
    
    //声音来源路径（最终混合的音频）
    NSURL   *audio_inputFileUrl =self.mixURL;
    
    //视频来源路径
    NSURL   *video_inputFileUrl = outputURL;
    
    //最终合成输出路径
    NSString *outputFilePath =[documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"final_video_%d.mp4",videoIndex]];
    NSURL   *outputFileUrl = [NSURL fileURLWithPath:outputFilePath];
    
    if([[NSFileManager defaultManager]fileExistsAtPath:outputFilePath])
        [[NSFileManager defaultManager]removeItemAtPath:outputFilePath error:nil];
    
    CMTime nextClipStartTime =kCMTimeZero;
    
    //创建可变的音频视频组合
    AVMutableComposition* mixComposition =[AVMutableComposition composition];
    
    //视频采集
    AVURLAsset* videoAsset =[[AVURLAsset alloc]initWithURL:video_inputFileUrl options:nil];
    CMTimeRange video_timeRange =CMTimeRangeMake(kCMTimeZero,videoAsset.duration);
    AVMutableCompositionTrack*a_compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [a_compositionVideoTrack insertTimeRange:video_timeRange ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:nextClipStartTime error:nil];
    

    //声音采集
    AVURLAsset* audioAsset =[[AVURLAsset alloc]initWithURL:audio_inputFileUrl options:nil];
    CMTimeRange audio_timeRange =CMTimeRangeMake(kCMTimeZero,videoAsset.duration);//声音长度截取范围==视频长度
    AVMutableCompositionTrack*b_compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [b_compositionAudioTrack insertTimeRange:audio_timeRange ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio]objectAtIndex:0] atTime:nextClipStartTime error:nil];
    //添加水印
    AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, videoAsset.duration);
    
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    mainCompositionInst.frameDuration = CMTimeMake(1, 30);
    mainCompositionInst.renderSize = [[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize];
    
    AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]];
    UIImageOrientation videoAssetOrientation_  = UIImageOrientationUp;
    BOOL isVideoAssetPortrait_  = NO;
    CGAffineTransform videoTransform = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject].preferredTransform;
    if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {
        videoAssetOrientation_ = UIImageOrientationRight;
        isVideoAssetPortrait_ = YES;
    }
    if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
        videoAssetOrientation_ =  UIImageOrientationLeft;
        isVideoAssetPortrait_ = YES;
    }
    if (videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0) {
        videoAssetOrientation_ =  UIImageOrientationUp;
    }
    if (videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0) {
        videoAssetOrientation_ = UIImageOrientationDown;
    }
    [passThroughLayer setTransform:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject].preferredTransform atTime:kCMTimeZero];
    [passThroughLayer setOpacity:0.0 atTime:videoAsset.duration];
    

    mainInstruction.layerInstructions = @[passThroughLayer];
    mainCompositionInst.instructions = @[mainInstruction];
    [self addWaterMarkWithCompsotion:mainCompositionInst size:[[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize]];
    
    //创建一个输出
    AVAssetExportSession* _assetExport =[[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetMediumQuality];
    _assetExport.outputFileType =AVFileTypeQuickTimeMovie;
    _assetExport.outputURL =outputFileUrl;
    _assetExport.shouldOptimizeForNetworkUse=YES;
    self.theEndVideoURL=outputFileUrl;
    
    [_assetExport exportAsynchronouslyWithCompletionHandler:
     ^(void ) {
         //播放
         dispatch_async(dispatch_get_main_queue(), ^{
            // NSURL*url = [NSURL fileURLWithPath:outputFilePath];
             NSDictionary *videoDic = @{VideoRecordPathKey:outputFileUrl};
             [videoUrls addObject:videoDic];
             isRecording = NO;
             tipLabel.text = [NSString stringWithFormat:@"已录制%d段视频",videoIndex];
             if (videoUrls.count == _maxRecordCount) {
                 EditVideoViewController  *editVC = [[EditVideoViewController alloc] init];
                 [editVC setVideoUrls:videoUrls];
                 [_rootVC presentViewController:[[UINavigationController alloc] initWithRootViewController:editVC] animated:YES completion:nil];
                 editVC.editBlock = ^{
                     [videoUrls removeAllObjects];
                 };
             }
          
//             MPMoviePlayerViewController *theMovie =[[MPMoviePlayerViewController alloc] initWithContentURL:url];
//             [self presentMoviePlayerViewControllerAnimated:theMovie];
//             theMovie.moviePlayer.movieSourceType = MPMovieSourceTypeFile;
//             [theMovie.moviePlayer play];
         });
         
         ALAssetsLibrary *assetLibary  = [[ALAssetsLibrary alloc] init];
         [assetLibary writeVideoAtPathToSavedPhotosAlbum:outputFileUrl completionBlock:^(NSURL *assetURL, NSError *error) {
             NSLog(@"--------%@",error);
             //[self checkForAndDeleteFile];
         }];
     }
     ];
    NSLog(@"完成！输出路径==%@",outputFilePath);
}

//通过文件路径建立和添加音频素材
- (void)setUpAndAddAudioAtPath:(NSURL*)assetURL toComposition:(AVMutableComposition*)composition start:(CMTime)start dura:(CMTime)dura offset:(CMTime)offset{
    
    AVURLAsset *songAsset =[AVURLAsset URLAssetWithURL:assetURL options:nil];
    
    AVMutableCompositionTrack *track =[composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    AVAssetTrack *sourceAudioTrack =[[songAsset tracksWithMediaType:AVMediaTypeAudio]objectAtIndex:0];
    
    NSError *error =nil;
    BOOL ok =NO;
    
    CMTime startTime = start;
    CMTime trackDuration = dura;
    CMTimeRange tRange =CMTimeRangeMake(startTime,trackDuration);
    
    //设置音量
    //AVMutableAudioMixInputParameters（输入参数可变的音频混合）
    //audioMixInputParametersWithTrack（音频混音输入参数与轨道）
    AVMutableAudioMixInputParameters *trackMix =[AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:track];
    [trackMix setVolume:0.8f atTime:startTime];
    
    //素材加入数组
    [audioMixParams addObject:trackMix];
    
    //Insert audio into track  //offsetCMTimeMake(0, 44100)
    ok = [track insertTimeRange:tRange ofTrack:sourceAudioTrack atTime:kCMTimeInvalid error:&error];
}
-(void)addWaterMarkWithCompsotion:(AVMutableVideoComposition *)compostion size :(CGSize)size {
    // 1 - Set up the text layer
    CATextLayer *subtitle1Text = [[CATextLayer alloc] init];
    [subtitle1Text setFont:@"Helvetica-Bold"];
    [subtitle1Text setFontSize:36];
    [subtitle1Text setBounds:CGRectMake(0, 0, size.width , 100)];
    [subtitle1Text setString:@"豆豆原创，独此一家"];
    [subtitle1Text setAlignmentMode:kCAAlignmentCenter];
    [subtitle1Text setForegroundColor:[[UIColor redColor] CGColor]];
    
    // 2 - The usual overlay
    CALayer *overlayLayer = [CALayer layer];
    [overlayLayer addSublayer:subtitle1Text];
    overlayLayer.frame = CGRectMake(0, 0, size.width, size.height);
    //[overlayLayer setMasksToBounds:YES];
    
    CALayer *parentLayer = [CALayer layer];
    CALayer *videoLayer = [CALayer layer];
    parentLayer.frame = CGRectMake(0, 0, size.width, size.height);
    videoLayer.frame = CGRectMake(0, 0, size.width, size.height);
   // overlayLayer.position = CGPointMake(compostion.renderSize.width / 2, compostion.renderSize.height/4);
    
    [parentLayer addSublayer:videoLayer];
    [parentLayer addSublayer:overlayLayer];
    
    compostion.animationTool = [AVVideoCompositionCoreAnimationTool
                                videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
}
#pragma mark - 保存路径
-(NSString*)getLibarayPath
{
    NSFileManager *fileManager =[NSFileManager defaultManager];
    
    NSArray* paths =NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString* path = [paths objectAtIndex:0];
    
    NSString *movDirectory = [path stringByAppendingPathComponent:@"tmpMovMix"];
    
    [fileManager createDirectoryAtPath:movDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    return movDirectory;
    
}  


/**
 *  改变设备属性的统一操作方法
 *
 *  @param propertyChange 属性改变操作
 */
-(void)changeDeviceProperty:(PropertyChangeBlock)propertyChange{
    AVCaptureDevice *captureDevice= [captureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}
-(void)tapScreen:(UITapGestureRecognizer *)tapGesture{
    CGPoint point= [tapGesture locationInView:self];
    CGPoint cameraPoint = CGPointMake(point.x / preBackView.frame.size.width, point.y / preBackView.frame.size.height);
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}
/**
 *  设置聚焦光标位置
 *
 *  @param point 光标位置
 */
-(void)setFocusCursorWithPoint:(CGPoint)point{
    focusCursor.center=point;
    focusCursor.transform=CGAffineTransformMakeScale(1.5, 1.5);
    focusCursor.alpha=1.0;
    [UIView animateWithDuration:1.0 animations:^{
        focusCursor.transform=CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        focusCursor.alpha=0;
        
    }];
}
/**
 *  设置聚焦点
 *
 *  @param point 聚焦点
 */
-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}





@end
