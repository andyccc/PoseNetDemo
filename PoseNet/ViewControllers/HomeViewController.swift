//
//  HomeViewController.swift
//  PoseNet
//
//  Created by andyccc on 2020/10/13.
//  Copyright © 2020 tensorflow. All rights reserved.
//

import UIKit
import Masonry

class HomeViewController: BaseViewController {
    
    var bannerImageView :UIImageView!
    var staticView: CardStaticView!
    var classImageView :UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        self.navigationItem.title = "首页"
        
        
        
        bannerImageView = UIImageView()
        self.view.addSubview(bannerImageView)
//        bannerImageView.backgroundColor = UIColor.yellow
        bannerImageView.image = UIImage(named: "banner")
        
        
        staticView = CardStaticView()
        self.view.addSubview(staticView)
        
        
        classImageView = UIImageView()
        self.view.addSubview(classImageView)
        classImageView.backgroundColor = UIColor.yellow
        classImageView.image = UIImage(named: "class_info")
        classImageView.isUserInteractionEnabled = true
        let tgr:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(btnAction))
        classImageView.addGestureRecognizer(tgr)
        
        
        bannerImageView.mas_makeConstraints { (make) in
            make!.width.equalTo()(self.view)
            make!.height.equalTo()(200)
            make!.top.equalTo()(64)
        }
        
        staticView.mas_makeConstraints { (make) in
            make!.width.equalTo()(self.view)
            make!.height.equalTo()(100)
            make!.top.equalTo()(bannerImageView.mas_bottom)?.offset()(10)
        }
        
        classImageView.mas_makeConstraints { (make) in
            make!.width.equalTo()(self.view)
            make!.height.equalTo()(200)
            make!.top.equalTo()(staticView.mas_bottom)?.offset()(10)
        }
        
        
        
        
        
        
        
        
//        let btn = UIButton.init(frame: CGRect(x:100, y:100, width: 100, height: 100))
//        btn.setTitle("进入", for: UIControl.State.normal)
//        btn.setTitleColor(UIColor.red, for: UIControl.State.normal)
//        btn.addTarget(self, action: #selector(btnAction(_:)), for: UIControl.Event.touchUpInside)
//        self.view.addSubview(btn)
    }
    
    @objc func btnAction(_:UIButton) {
        
        let vc = ClassDetailViewController()
        self.navigationController?.pushViewController(vc, animated: true)

        
        
        
    }
    
    

}
