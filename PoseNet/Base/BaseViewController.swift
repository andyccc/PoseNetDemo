//
//  BaseViewController.swift
//  PoseNet
//
//  Created by andyccc on 2020/10/13.
//  Copyright © 2020 tensorflow. All rights reserved.
//

import UIKit

class BaseViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.white
    
    }
    
    
    override var shouldAutorotate: Bool
    {
        return false
    }

    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask
    {
        return .portrait
    }
    
   
    
}
