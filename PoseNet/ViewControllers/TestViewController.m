//
//  RecordingVideoBoard_iPhone.m
//  STC
//
//  Created by ty on 15/6/11.
//  Copyright (c) 2015年 andyccc. All rights reserved.
//

#import "RecordingVideoBoard_iPhone.h"
#import "YSRecordEngine.h"
#import <CoreMotion/CoreMotion.h>
#import "UIAlertController+Block.h"
#import "WBStatusHelper.h"
#import "VedioObject.h"

#define COUNT_DUR_TIMER_INTERVAL 0.05
#define MAX_VIDEO_DUR 10.0f
#define ACTIVITYMAX_VIDEO_DUR 60.0f //2017.4.20 活动视频时长 活动页面进入发布动态页面时使用
#define ACTIVITYCOUNT_DUR_TIMER_INTERVAL 0.10
#pragma mark -


@interface RecordingVideoBoard_iPhone () <YSRecordEngineDelegate>
{
    BeeUIProgressView *progressView;
    BeeUILabel *cancelLabel;
    UIButton *backBut;
    UIView *overlyView;

    UIButton *cameraBtn;
    CGFloat maxRecordTime;
    NSString *videoPath;

    UIButton *cameraChangeBtn;
    CGAffineTransform lastTransform;
    CGAffineTransform nowTransform;


    AVPlayer *_player;
    AVPlayerLayer *_playerLayer;
}

@property (strong, nonatomic) UIImageView *focusRectView; //聚焦框
@property (strong, nonatomic) CMMotionManager *motionManager;

@property (assign, nonatomic) CGFloat currentVideoDur;
@property (assign, nonatomic) NSURL *currentFileURL;
@property (strong, nonatomic) YSRecordEngine *recordEngine;
@property (assign, nonatomic) BOOL allowRecord;      //允许录制
@property (assign, nonatomic) CGFloat totalVideoDur; //2017.4.20添加 总时长

@property (nonatomic, strong) UIButton *okBtn;
@property (nonatomic, strong) UIButton *delBtn;


@end


@implementation RecordingVideoBoard_iPhone

DEF_NOTIFICATION(RECORDINGVIDEO_COMPLETE) //自定义录制视频

DEF_SIGNAL(RecordingVideoComplete) //录制视频完成

//DEF_SIGNAL(Video_image)//视频图片得到

- (void)load
{
    //    videoPath = [CommonUtil getTemporaryFilePathWithSuffix:@".mp4"];
    NSString *newfilename = STR_FORMAT(@"%@-%f", [[NSUUID UUID] UUIDString], [[NSDate date] timeIntervalSince1970]);
    NSString *filename = STR_FORMAT(@"%@.mp4", [[newfilename MD5] lowercaseString]);
    videoPath = GetBatchCachePath(filename);
    NSLog(@"videoPath:%@", videoPath);
    self.allowRecord = YES;
    self.autoSaveToAlbum = YES;
    self.showPreview = NO;
    [self startMotionManager];

    [self observeNotification:BeeUIApplication.STATE_CHANGED];
}

- (void)unload
{
    [self unobserveNotification:BeeUIApplication.STATE_CHANGED];

    if ([UIApplication sharedApplication].idleTimerDisabled) {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
    }

    if (_recordEngine) {
        [_recordEngine shutdown];
        _recordEngine = nil;
    }
    if (_motionManager) {
        [_motionManager stopDeviceMotionUpdates];
        _motionManager = nil;
    }

    if (_focusRectView) {
        _focusRectView.image = nil;
        [_focusRectView removeFromSuperview];
        _focusRectView = nil;
    }

    if (_recordingCompleteBlock) {
        _recordingCompleteBlock = nil;
    }
}

#pragma mark Signal

ON_CREATE_VIEWS(signal)
{
    self.view.backgroundColor = [UIColor colorWithString:@"#1A1A1A"];
}

ON_LAYOUT_VIEWS(signal)
{
}

ON_DID_APPEAR(signal)
{
    if (!IS_IPHONE_X) {
        self.statusBarHidden = YES;
        [self.stack setNeedsStatusBarAppearanceUpdate];
    }
}

ON_WILL_APPEAR(signal)
{
    [self setNavigationBarShown:NO];

//self.parentView = bee.ui.appBoard.parentView;

#if !TARGET_IPHONE_SIMULATOR

    //检查权限 摄像头
    [PermissionScope requestCamera:^(BOOL granted) {
        if (!granted) {
            [self showUnauthorizedAlert];
        } else {
            //检查权限 麦克风
            [PermissionScope requestMicrophone:^(BOOL granted) {
                if (!granted) {
                    [self showUnauthorizedAlert];
                } else {
                    [self startControl];
                }
            } showUnauthorizedAlert:NO];
        }
    } showUnauthorizedAlert:NO];

#else
    [self layoutViews];
#endif
}

- (void)showUnauthorizedAlert
{
    [UIAlertController showAlertInViewController:self withTitle:FORMAT(@"请在iPhone的“设置-隐私”选项中，允许%@访问你的摄像头和麦克风", APP_DISPLAY_NAME) message:nil cancelButtonTitle:@"确定" destructiveButtonTitle:nil otherButtonTitles:nil tapBlock:^(UIAlertController *_Nonnull controller, UIAlertAction *_Nonnull action, NSInteger buttonIndex) {
        if (buttonIndex == 0) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }];
}

- (void)startControl
{
    [self createView];
    [self.recordEngine startUp];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CGPoint touchPoint = CGPointMake(SCREEN_WIDTH / 2.0, SCREEN_WIDTH / 2.0);
        [self showFocusRectAtPoint:touchPoint];
        [self focusInPoint:touchPoint];
    });
}

ON_WILL_DISAPPEAR(signal)
{
    if (_recordEngine) {
        [_recordEngine shutdown];
    }
    if (_motionManager) {
        [_motionManager stopDeviceMotionUpdates];
    }
}

#pragma mark - 前后台切换
ON_NOTIFICATION3(BeeUIApplication, STATE_CHANGED, notification)
{
    NSString *type = notification.object;
    if (type) {
        if ( //[type isEqualToString:@"3"]
            //||
            [type isEqualToString:@"0"]) {
            [self dismissTips];
            [self dismissViewControllerAnimated:NO completion:nil];
        }
    }
}

#pragma mark -

- (void)createView
{
    //2017.4.20 添加如果是活动页面跳转发布动态页面发布视频 视频时长1分钟
    if (self.isActivity) {
        maxRecordTime = ACTIVITYMAX_VIDEO_DUR;
    } else {
        maxRecordTime = self.maxVideoTime ? self.maxVideoTime : MAX_VIDEO_DUR;
    }

    if (!_recordEngine) {
        CGRect frame = CGRectMake(0, IS_IPHONE_X ? APP_STATUS_BAR_HEIGHT : 0, ScreenWidth, ScreenWidth);
        AVCaptureVideoPreviewLayer *previewLayer = [self.recordEngine previewLayer];
        previewLayer.frame = frame;
        [self.view.layer insertSublayer:previewLayer atIndex:0];
    }

    [self layoutViews];


    //    UIView *testView = [[UIView alloc] initWithFrame:CGRectMake(0, 300, ScreenWidth, ScreenWidth)];
    //    testView.backgroundColor = [UIColor redColor];
    //    [self.view addSubview:testView];
}

- (void)layoutViews
{
    /**
     *  自定义拍摄背景view
     */
    overlyView = [[UIView alloc] initWithFrame:CGRectMake(0, ScreenWidth + (IS_IPHONE_X ? APP_STATUS_BAR_HEIGHT : 0), ScreenHeight, ScreenHeight - ScreenWidth)];
    [overlyView setBackgroundColor:self.view.backgroundColor];
    [self.view addSubview:overlyView];

    /**
     *  上移取消
     */
    cancelLabel = [[BeeUILabel alloc] initWithFrame:CGRectMake((ScreenWidth - 50) / 2, ScreenHeight - 290, 55, 16)];
    cancelLabel.backgroundColor = [RGBACOLOR(144, 139, 131, 0.4) colorWithAlphaComponent:0.6];
    cancelLabel.textColor = [UIColor whiteColor];
    cancelLabel.text = @"↑上移取消";
    cancelLabel.font = Font_Sys(10);
    cancelLabel.alpha = 0;
    if (IS_IPHONE_X) {
        [overlyView addSubview:cancelLabel];
    } else {
        [self.view addSubview:cancelLabel];
    }

    /**
     *  进度条
     */
    progressView = [[BeeUIProgressView alloc] initWithFrame:CGRectMake(0, 0, ScreenWidth, 2)];
    [progressView setProgress:0.0 animated:YES];
    progressView.trackTintColor = [UIColor clearColor];
    progressView.progressTintColor = RGBCOLOR(255, 158, 5);
    progressView.progressViewStyle = UIProgressViewStyleDefault;
    [overlyView addSubview:progressView];


    /**
     *  拍摄按钮
     */
    UIImage *camerdefImage = [EXUIImage imageNamed:@"btn_send_video_def@2x.png"];
    UIImage *camerpreImage = [EXUIImage imageNamed:@"btn_send_video_pre@2x.png"];
    CGRect cameraBtnFrame = CGRectMake((ScreenWidth - UIValue(145)) / 2.0, (ScreenHeight - ScreenWidth - UIValue(145)) / 2.0, UIValue(145), UIValue(145));
    cameraBtn = [[UIButton alloc] initWithFrame:cameraBtnFrame];
    [cameraBtn setImage:camerpreImage forState:UIControlStateNormal];
    [cameraBtn setImage:camerdefImage forState:UIControlStateHighlighted];

#if !TARGET_IPHONE_SIMULATOR

    [cameraBtn addTarget:self action:@selector(startRecord) forControlEvents:UIControlEventTouchDown];
    [cameraBtn addTarget:self action:@selector(cancelRecord) forControlEvents:UIControlEventTouchUpOutside];
    [cameraBtn addTarget:self action:@selector(stopRecord) forControlEvents:UIControlEventTouchUpInside];

    [cameraBtn addTarget:self action:@selector(resumRecord) forControlEvents:UIControlEventTouchDragEnter];
    [cameraBtn addTarget:self action:@selector(resumRecord2) forControlEvents:UIControlEventTouchDragExit];
#endif

    [overlyView addSubview:cameraBtn];

    /**
     *  返回按钮 2017.4.28
     */
    backBut = [[UIButton alloc] initWithFrame:CGRectMake((cameraBtn.left - UIValue(44)) / 2, ScreenWidth, UIValue(44), UIValue(44))];
    backBut.centerY = cameraBtn.centerY;
    [backBut setTitle:@"取消" forState:UIControlStateNormal];
    [backBut setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    backBut.titleLabel.font = Font(14);
    [backBut addTarget:self action:@selector(gotoBack) forControlEvents:UIControlEventTouchDown];
    [overlyView addSubview:backBut];

    /**
     *  对焦框
     */
    UIImageView *focusRectView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    focusRectView.image = [EXUIImage imageNamed:@"touch_focus_not.png"];
    focusRectView.alpha = 0;
    _focusRectView = focusRectView;
    [self.view addSubview:_focusRectView];

#if !TARGET_IPHONE_SIMULATOR
    //    @2x
    CGFloat cameraChangeBtnY = (44 - 27) / 2.0;
    CGRect cameraChangeBtnFrame = CGRectMake(ScreenWidth - 25 - cameraChangeBtnY, cameraChangeBtnY + (IS_IPHONE_X ? APP_STATUS_BAR_HEIGHT : 0), 27, 25);
    cameraChangeBtn = [[UIButton alloc] initWithFrame:cameraChangeBtnFrame];
    [cameraChangeBtn setBackgroundImage:[EXUIImage imageNamed:@"camera_switch"] forState:UIControlStateNormal];
    [cameraChangeBtn addTarget:self action:@selector(cameraChangeAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cameraChangeBtn];

    if (IS_IPHONE_4_OR_LESS) {
        cancelLabel.top = ScreenWidth - cancelLabel.height * 1.5;
        cancelLabel.layer.cornerRadius = 2;
        cancelLabel.clipsToBounds = YES;
        [self.view bringSubviewToFront:cancelLabel];
    } else if (IS_IPHONE_X) {
        cancelLabel.centerY = cameraBtn.top / 2.0;
        [overlyView bringSubviewToFront:cancelLabel];
    }
#endif
}

- (void)gotoBack
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -
/**
*  在真机关闭屏幕旋转功能时如何去判断屏幕方向
*/
- (void)startMotionManager
{
    if (!_motionManager) {
        _motionManager = [[CMMotionManager alloc] init];
    }
    _motionManager.deviceMotionUpdateInterval = 1 / 15.0;
    if (_motionManager.deviceMotionAvailable) {
        NSLog(@"Device Motion Available");
        @weakify(self);
        [_motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue]
                                            withHandler:^(CMDeviceMotion *motion, NSError *error) {
                                                @normalize(self);
                                                [self performSelectorOnMainThread:@selector(handleDeviceMotion:) withObject:motion waitUntilDone:YES];
                                            }];
    } else {
        NSLog(@"No device motion on device.");
        [self setMotionManager:nil];
    }
}

- (void)handleDeviceMotion:(CMDeviceMotion *)deviceMotion
{
    double x = deviceMotion.gravity.x;
    double y = deviceMotion.gravity.y;
    if (fabs(y) >= fabs(x)) {
        if (y >= 0) {
            // UIDeviceOrientationPortraitUpsideDown;
            [self orientationDidChange:UIDeviceOrientationPortraitUpsideDown];
        } else {
            // UIDeviceOrientationPortrait;
            [self orientationDidChange:UIDeviceOrientationPortrait];
        }
    } else {
        if (x >= 0) {
            // UIDeviceOrientationLandscapeRight;
            [self orientationDidChange:UIDeviceOrientationLandscapeRight];

        } else {
            // UIDeviceOrientationLandscapeLeft;
            [self orientationDidChange:UIDeviceOrientationLandscapeLeft];
        }
    }
}

#pragma mark -
//开始录制
- (void)startRecord
{
    //静止自动锁屏
    [UIApplication sharedApplication].idleTimerDisabled = YES;

    if (self.allowRecord) {
        if (!CGAffineTransformEqualToTransform(lastTransform, nowTransform)) {
            lastTransform = nowTransform;
            [self.recordEngine updateVideoTransform:lastTransform];
        }

        cancelLabel.alpha = 1.0;
        //        if (self.recordEngine.isCapturing) {
        //            [self.recordEngine resumeCapture];
        //        }else {
        [self.recordEngine startCapture];
        //        }
    }
}

- (void)resumRecord
{ //滑入
    cancelLabel.text = @"↑上移取消";
    cancelLabel.textColor = [UIColor whiteColor];
}

- (void)resumRecord2
{ //滑出
    cancelLabel.text = @"松开取消";
    cancelLabel.textColor = [UIColor colorWithString:CHILD_MAIN_COLOR];
}

//取消录制
- (void)cancelRecord
{
    cancelLabel.alpha = 0.0;
    cancelLabel.text = @"↑上移取消";
    cancelLabel.textColor = [UIColor whiteColor];


    if (self.allowRecord) {
        if (self.recordEngine.isCapturing) {
            [self.recordEngine pauseCapture];
        }

        [self.recordEngine pauseCapture];
        [self.recordEngine prepareStartCapture];
        progressView.progress = 0;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.allowRecord = YES;
        });
    }


    //    [self.recordEngine pauseCapture];
    //    [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
    //    [self dismissViewControllerAnimated: YES completion:nil];
}

- (void)stopRecord
{
    cancelLabel.alpha = 0.0;

    if (self.allowRecord) {
        self.currentVideoDur = self.recordEngine.currentRecordTime;

        [self endRecord];
        self.allowRecord = NO;
    }
}

//结束录制
- (void)endRecord
{
    BOOL safeStop = NO;
    //先停掉
    if (self.allowRecord) {
        if (self.recordEngine.isCapturing) {
            [self.recordEngine pauseCapture];
            safeStop = YES;
        }
        //        else {
        //            //[self.recordEngine resumeCapture];
        //        }
    }

    //检查长度
    if (self.currentVideoDur < 1.0) {
        [self.recordEngine prepareStartCapture];
        [progressView setProgress:0 animated:YES];
        [UIAlertController showAlertInViewController:self withTitle:@"提示" message:@"内容过短" cancelButtonTitle:@"好的" destructiveButtonTitle:nil otherButtonTitles:nil tapBlock:^(UIAlertController *_Nonnull controller, UIAlertAction *_Nonnull action, NSInteger buttonIndex){
        }];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.allowRecord = YES;
        });
    } else {
        if (safeStop) { //正常停止的
            @weakify(self);
            [self.recordEngine stopCaptureHandler:^(UIImage *movieImage, NSString *path) {
                @normalize(self);
                [self startToPlay:path image:movieImage];

            }];
        }
    }
}

- (void)startToPlay:(NSString *)path image:(UIImage *)image
{
    if (path) {
        if (!self.showPreview) {
            [self ok];
            return;
        }

        _playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        _playerLayer.frame = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_WIDTH);
        _playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill; //视频填充模式
        [self.view.layer addSublayer:_playerLayer];
        [self.player seekToTime:CMTimeMake(0, 1)];
        [self.player play];
        [self.recordEngine shutdown];


        backBut.hidden = YES;
        cameraBtn.hidden = YES;
        progressView.hidden = YES;
        self.okBtn.hidden = NO;
        self.delBtn.hidden = NO;


    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)ok
{
    [self fininshRecord:[NSURL fileURLWithPath:videoPath]];
}

- (void)del
{
    backBut.hidden = NO;
    cameraBtn.hidden = NO;
    progressView.hidden = NO;
    progressView.progress = 0;
    self.okBtn.hidden = YES;
    self.delBtn.hidden = YES;

    //播放器停止
    if (_player) {
        [_player pause];
        [self removePlayerObserver];
        _player = nil;
        [_playerLayer removeFromSuperlayer];
        _playerLayer = nil;
    }

    [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
    [self.recordEngine startUp];
    self.allowRecord = YES;
}

- (void)fininshRecord:(NSURL *)outputFileURL
{
    if (_recordingCompleteBlock) {
        _recordingCompleteBlock(outputFileURL);
        return;
    }

    NSLog(@"%@", outputFileURL);
    VedioObject *vd = [VedioObject new];
    vd.time = STR_FORMAT(@"%d", (int)self.currentVideoDur);
    vd.path = [outputFileURL path];

    self.fromBoard = self;
    [self recordingVideoFinish:outputFileURL vedioData:vd];
}


- (void)dismissViewController
{
    [self dismissTips];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)cameraChangeAction
{
    if (self.allowRecord) {
        [self.recordEngine changeCameraInputDeviceisFront:!self.recordEngine.isFrontCameraInput];
    }
}

#pragma mark - Touch Event对焦
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint touchPoint = [touch locationInView:self.view]; //previewLayer 的 superLayer所在的view
    if (CGRectContainsPoint([self.recordEngine previewLayer].frame, touchPoint)) {
        if (touchPoint.y < overlyView.top) { //season alter 2017-7-17 让点击录制视频按钮范围内 不要出现对焦效果
            [self showFocusRectAtPoint:touchPoint];
            [self focusInPoint:touchPoint];
        }
    }
}

- (void)showFocusRectAtPoint:(CGPoint)point
{
    _focusRectView.alpha = 1.0;
    _focusRectView.center = point;
    _focusRectView.transform = CGAffineTransformMakeScale(1.5f, 1.5f);
    [UIView animateWithDuration:0.2f animations:^{
        _focusRectView.transform = CGAffineTransformMakeScale(1.0, 1.0);
    } completion:^(BOOL finished) {
        CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
        animation.values = @[ @0.5f, @1.0, @0.5f, @1.0, @0.5f, @1.0 ];
        animation.duration = 0.5f;
        [_focusRectView.layer addAnimation:animation forKey:@"opacity"];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3f animations:^{
                _focusRectView.alpha = 0;
            }];
        });
    }];
}

//对焦
- (void)focusInPoint:(CGPoint)touchPoint
{
#if !TARGET_IPHONE_SIMULATOR
    CGPoint devicePoint = [self convertToPointOfInterestFromViewCoordinates:touchPoint];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
#endif
}

- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates
{
#if !TARGET_IPHONE_SIMULATOR
    AVCaptureVideoPreviewLayer *videoPreviewLayer = [self.recordEngine previewLayer]; //需要按照项目实际情况修改
    CGSize frameSize = videoPreviewLayer.bounds.size;
    if ([[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResize]) {
        return CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        CGPoint pointOfInterest = CGPointMake(.5f, .5f);
        for (AVCaptureInputPort *port in [self.recordEngine.videoInput ports]) { //需要按照项目实际情况修改，必须是正在使用的videoInput
            if ([port mediaType] == AVMediaTypeVideo) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;

                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;

                if ([[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspect]) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if (point.x >= blackBar && point.x <= blackBar + x2) {
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if (point.y >= blackBar && point.y <= blackBar + y2) {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if ([[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                    }
                }

                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
        return pointOfInterest;
    }
#endif

    return CGPointMake(.5f, .5f);
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    //    NSLog(@"focus point: %f %f", point.x, point.y);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AVCaptureDevice *device = [self.recordEngine.videoInput device];
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            if ([device isFocusPointOfInterestSupported]) {
                [device setFocusPointOfInterest:point];
            }

            if ([device isFocusModeSupported:focusMode]) {
                [device setFocusMode:focusMode];
            }

            if ([device isExposurePointOfInterestSupported]) {
                [device setExposurePointOfInterest:point];
            }

            if ([device isExposureModeSupported:exposureMode]) {
                [device setExposureMode:exposureMode];
            }

            [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
            [device unlockForConfiguration];
        } else {
            NSLog(@"对焦错误:%@", error);
        }
    });
}

#pragma mark - set、get方法
- (YSRecordEngine *)recordEngine
{
    if (!_recordEngine) {
        _recordEngine = [[YSRecordEngine alloc] init];
        _recordEngine.delegate = self;
        _recordEngine.videoPath = videoPath;
        _recordEngine.maxRecordTime = maxRecordTime;
        _recordEngine.maxWidth = 640; //720
        _recordEngine.maxHeight = 640;
        _recordEngine.bitsPerPixel = 3.0;
        _recordEngine.autoSaveToAlbum = _autoSaveToAlbum;
    }
    return _recordEngine;
}

#pragma mark - YSRecordEngineDelegate
- (void)recordProgress:(CGFloat)progress
{
    if (!self.allowRecord) {
        return;
    }

    self.currentVideoDur = self.recordEngine.currentRecordTime;
    [progressView setProgress:progress animated:YES];
    if (progress >= 1) {
        [self endRecord];
        self.allowRecord = NO;
    }
}


#pragma mark -


#pragma mark------------notification-------------
- (void)orientationDidChange:(UIDeviceOrientation)orientation
{
    //    [_captureManager.previewLayer.connection setVideoOrientation:(AVCaptureVideoOrientation)[UIDevice currentDevice].orientation];
    if (!cameraChangeBtn) {
        return;
    }

    CGAffineTransform transform = CGAffineTransformMakeRotation(0);
    CGAffineTransform transform1 = CGAffineTransformMakeRotation(0);
    switch (orientation) {
        case UIDeviceOrientationPortrait: //1
        {
            transform = CGAffineTransformMakeRotation(0);
            break;
        }
        case UIDeviceOrientationPortraitUpsideDown: //2
        {
            transform = CGAffineTransformMakeRotation(M_PI);
            break;
        }
        case UIDeviceOrientationLandscapeLeft: //3
        {
            transform = CGAffineTransformMakeRotation(M_PI_2);
            transform1 = CGAffineTransformMakeRotation(-M_PI_2);
            break;
        }
        case UIDeviceOrientationLandscapeRight: //4
        {
            transform = CGAffineTransformMakeRotation(-M_PI_2);
            transform1 = CGAffineTransformMakeRotation(M_PI_2);
            break;
        }
    }

    nowTransform = transform1;

    [UIView animateWithDuration:0.3f animations:^{
        cameraChangeBtn.transform = transform;
    }];
}

//- (BOOL)prefersStatusBarHidden{
//    return YES;
//}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationFade;
}
#pragma mark -

- (AVPlayer *)player
{
    if (!_player) {
        NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
        _player = [AVPlayer playerWithURL:videoURL];
        [self addPlayerObserver];
    }
    return _player;
}


- (void)addPlayerObserver
{
    //给AVPlayerItem添加播放完成通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem];
}

- (void)removePlayerObserver
{
    @try {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    } @catch (NSException *exception) {
        NSLog(@"removePlayerObserver exception:%@", exception);
    }
}

- (void)playbackFinished:(NSNotification *)notification
{
    NSLog(@"视频播放完成.");
    // 播放完成后重复播放
    // 跳到最新的时间点开始播放
    [self.player seekToTime:CMTimeMake(0, 1)];
    [self.player play];
}

- (UIButton *)okBtn
{
    if (!_okBtn) {
        UIButton *btn = [[UIButton alloc] init];
        btn.width = btn.height = UI(47.5); // 47.5
        btn.centerY = backBut.centerY;
        btn.centerX = ScreenWidth / 4.0 * 3;
        [btn setBackgroundImage:[EXUIImage imageNamed:@"record_complete"] forState:UIControlStateNormal];
        //        [btn setImage:[EXUIImage imageNamed:@"record_complete"] forState:UIControlStateNormal];

        [btn addTarget:self action:@selector(ok) forControlEvents:UIControlEventTouchUpInside];
        [overlyView addSubview:btn];
        _okBtn = btn;
    }
    return _okBtn;
}

- (UIButton *)delBtn
{
    if (!_delBtn) {
        UIButton *btn = [[UIButton alloc] init];
        btn.width = btn.height = UI(47.5);
        btn.centerY = backBut.centerY;
        btn.centerX = ScreenWidth / 4.0;
        [btn setBackgroundImage:[EXUIImage imageNamed:@"record_delete"] forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(del) forControlEvents:UIControlEventTouchUpInside];
        [overlyView addSubview:btn];
        _delBtn = btn;
    }
    return _delBtn;
}

@end
