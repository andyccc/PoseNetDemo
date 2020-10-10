//
//  PlayVideoViewController.swift
//  PoseNet
//
//  Created by andyccc on 2020/10/13.
//  Copyright © 2020 tensorflow. All rights reserved.
//

import UIKit
import AVFoundation
import os
import Masonry

class PlayVideoViewController: BaseViewController {
    
    private var _player :AVPlayer!
    private var _playerLayer :AVPlayerLayer!
    
    private  var overlayView: OverlayView!
    private  var previewView: PreviewView!
    
    
    // Minimum score to render the result.
    private let minimumScore: Float = 0.5

    
    // Relative location of `overlayView` to `previewView`.
    private var overlayViewFrame: CGRect?

    private var previewViewFrame: CGRect?
    // Handles all data preprocessing and makes calls to run inference.
    private var modelDataHandler: ModelDataHandler?

    
    
    private lazy var cameraCapture = CameraFeedManager(previewView: previewView)


    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.isHidden = false
        
        do {
          modelDataHandler = try ModelDataHandler()
        } catch let error {
          fatalError(error.localizedDescription)
        }
        
        
        let urlStr = "https://www.apple.com/105/media/us/iphone-x/2017/01df5b43-28e4-4848-bf20-490c34a926a7/films/feature/iphone-x-feature-tpl-cc-us-20170912_1280x720h.mp4"
        let url = NSURL.init(string: urlStr)
        let playItem = AVPlayerItem.init(url: url! as URL)

        _player = AVPlayer.init(playerItem: playItem)
        
        
        _playerLayer = AVPlayerLayer.init(player: _player)
        
        _playerLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill //视频填充模式
        
        self.view.layer.addSublayer(_playerLayer)
        _player.seek(to: CMTimeMake(value: 0, timescale: 1))
        _player.play()
        
        
        
        previewView = PreviewView.init()
        self.view.addSubview(previewView)
        
        previewView.mas_makeConstraints { (make) in
            make?.width.equalTo()(120)
            make?.height.equalTo()(160)
            make?.right.offset()(-20)
            make?.top.offset()(20)
        }
        
        
        overlayView = OverlayView.init()
        overlayView.isOpaque = false
        overlayView.clearsContextBeforeDrawing = true

        previewView.addSubview(overlayView)
        overlayView.mas_makeConstraints { (make) in
//            make?.width.mas_equalTo()(previewView)
//            make?.height.mas_equalTo()(previewView)
            make?.width.equalTo()(previewView.mas_width)
            make?.height.equalTo()(previewView.mas_height)
        }
        
//        cameraCapture.videoOrientation = AVCaptureVideoOrientation(ui:self.interfaceOrientation)
//        previewView.previewLayer.connection?.videoOrientation = cameraCapture.videoOrientation ?? .portrait

        cameraCapture.delegate = self

        
        
        let label  = UILabel.init(frame: CGRect(x: 50, y: 50, width: 50, height: 50))
        label.text = "test"
        label.textColor = UIColor.red
        overlayView .addSubview(label)
        
        
        //延时 0.5s 执行
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+0.5) {
            self._playerLayer.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)

            //此时处于主队列中
            self.cameraCapture.rotateVideo(interfaceOrientation: .landscapeRight)

        }
        
        
        

        // Do any additional setup after loading the view.
    }
    

    override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)

      cameraCapture.checkCameraConfigurationAndStartSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
      cameraCapture.stopSession()
    }

    
    override func viewDidLayoutSubviews() {
        previewView.layoutIfNeeded()
      overlayViewFrame = overlayView.frame
      previewViewFrame = previewView.frame
    }

    
    override var shouldAutorotate: Bool
    {
        return true
    }
    
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask
    {
        return .landscapeRight
    }
    
    
//
//    //是否支持旋转
//    - (BOOL)shouldAutorotate
//    {
//        return NO;
//    }
//
//    //支持的方向
//    - (UIInterfaceOrientationMask)supportedInterfaceOrientations
//    {
//        return UIInterfaceOrientationMaskPortrait;
//    }
//
//    //与上以及plist中的support相关的对应
//    - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
//    {
//        return (toInterfaceOrientation == UIInterfaceOrientationPortrait);
//    }
}



// MARK: - CameraFeedManagerDelegate Methods
extension PlayVideoViewController: CameraFeedManagerDelegate {
  func cameraFeedManager(_ manager: CameraFeedManager, didOutput pixelBuffer: CVPixelBuffer) {
    runModel(on: pixelBuffer)
  }

  // MARK: Session Handling Alerts
  func cameraFeedManagerDidEncounterSessionRunTimeError(_ manager: CameraFeedManager) {
    // Handles session run time error by updating the UI and providing a button if session can be
    // manually resumed.
    
//    self.resumeButton.isHidden = false
  }

  func cameraFeedManager(
    _ manager: CameraFeedManager, sessionWasInterrupted canResumeManually: Bool
  ) {
    // Updates the UI when session is interupted.
//    if canResumeManually {
//      self.resumeButton.isHidden = false
//    } else {
//      self.cameraUnavailableLabel.isHidden = false
//    }
  }

  func cameraFeedManagerDidEndSessionInterruption(_ manager: CameraFeedManager) {
    // Updates UI once session interruption has ended.
//    self.cameraUnavailableLabel.isHidden = true
//    self.resumeButton.isHidden = true
  }

  func presentVideoConfigurationErrorAlert(_ manager: CameraFeedManager) {
    let alertController = UIAlertController(
      title: "Confirguration Failed", message: "Configuration of camera has failed.",
      preferredStyle: .alert)
    let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
    alertController.addAction(okAction)

    present(alertController, animated: true, completion: nil)
  }

  func presentCameraPermissionsDeniedAlert(_ manager: CameraFeedManager) {
    let alertController = UIAlertController(
      title: "Camera Permissions Denied",
      message:
        "Camera permissions have been denied for this app. You can change this by going to Settings",
      preferredStyle: .alert)

    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
    let settingsAction = UIAlertAction(title: "Settings", style: .default) { action in
      if let url = URL.init(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      }
    }

    alertController.addAction(cancelAction)
    alertController.addAction(settingsAction)

    present(alertController, animated: true, completion: nil)
  }

  @objc func runModel(on pixelBuffer: CVPixelBuffer) {
    
    
    guard let overlayViewFrame = overlayViewFrame, let previewViewFrame = previewViewFrame
    else {
      return
    }
    // To put `overlayView` area as model input, transform `overlayViewFrame` following transform
    // from `previewView` to `pixelBuffer`. `previewView` area is transformed to fit in
    // `pixelBuffer`, because `pixelBuffer` as a camera output is resized to fill `previewView`.
    // https://developer.apple.com/documentation/avfoundation/avlayervideogravity/1385607-resizeaspectfill
    let modelInputRange = overlayViewFrame.applying(
      previewViewFrame.size.transformKeepAspect(toFitIn: pixelBuffer.size))

    // Run PoseNet model.
    guard
      let (result, times) = self.modelDataHandler?.runPoseNet(
        on: pixelBuffer,
        from: modelInputRange,
        to: overlayViewFrame.size)
    else {
      os_log("Cannot get inference result.", type: .error)
      return
    }

    // Udpate `inferencedData` to render data in `tableView`.
//    inferencedData = InferencedData(score: result.score, times: times)

    // Draw result.
    DispatchQueue.main.async {
//      self.tableView.reloadData()
      // If score is too low, clear result remaining in the overlayView.
      if result.score < self.minimumScore {
        self.clearResult()
        return
      }
      self.drawResult(of: result)
    }
    
    
    
  }

  func drawResult(of result: Result) {
    self.overlayView.dots = result.dots
    self.overlayView.lines = result.lines
    self.overlayView.setNeedsDisplay()
  }

  func clearResult() {
    self.overlayView.clear()
    self.overlayView.setNeedsDisplay()
  }
}

extension AVCaptureVideoOrientation {
    var uiInterfaceOrientation: UIInterfaceOrientation {
        get {
            switch self {
                case .landscapeLeft:        return .landscapeLeft
                case .landscapeRight:       return .landscapeRight
                case .portrait:             return .portrait
                case .portraitUpsideDown:   return .portraitUpsideDown
            }
        }
    }
    
    init(ui:UIInterfaceOrientation) {
        switch ui {
            case .landscapeRight:       self = .landscapeRight
            case .landscapeLeft:        self = .landscapeLeft
            case .portrait:             self = .portrait
            case .portraitUpsideDown:   self = .portraitUpsideDown
            default:                    self = .portrait
        }
    }
}
