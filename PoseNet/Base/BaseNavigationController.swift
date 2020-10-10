//
//  BaseNavigationController.swift
//  PoseNet
//
//  Created by andyccc on 2020/10/13.
//  Copyright © 2020 tensorflow. All rights reserved.
//

import UIKit

class BaseNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    
    override var shouldAutorotate: Bool
    {
        return visibleViewController?.shouldAutorotate ?? false
    }

    
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask
    {
        return visibleViewController?.supportedInterfaceOrientations ?? .portrait
    }
    
   
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        viewControllerToPresent.modalPresentationStyle = .fullScreen
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }
    
//    open func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil)


}
