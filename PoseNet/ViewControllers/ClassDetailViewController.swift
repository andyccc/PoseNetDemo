//
//  ClassDetailViewController.swift
//  PoseNet
//
//  Created by andyccc on 2020/10/14.
//  Copyright © 2020 tensorflow. All rights reserved.
//

import UIKit
import Masonry

class ClassDetailViewController: BaseViewController {

    var startBtn : UIButton!
    var imageView: UIImageView!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = "全身激活练习"
        
        startBtn = UIButton()
        startBtn.backgroundColor = UIColor.init(hexString: "#36C2AF")
        startBtn.setTitle("开始训练", for: UIControl.State.normal)
        startBtn.addTarget(self, action: #selector(startTrans), for: UIControl.Event.touchUpInside)
        startBtn.setTitleColor(UIColor.white, for: UIControl.State.normal)
        self.view.addSubview(startBtn)
        
        imageView = UIImageView()
        imageView.image = UIImage(named: "cover_image")
        self.view.addSubview(imageView)

        
        
        
        
        
        
        
        
        
        startBtn.mas_makeConstraints { (make) in
            make!.width.equalTo()(self.view)
            make!.height.equalTo()(60)
            make!.bottom.mas_equalTo()(self.view.mas_bottom)
        }
        
        imageView.mas_makeConstraints { (make) in
            make!.width.mas_equalTo()(self.view)
            make!.height.mas_equalTo()(self.view.mas_width)
            make!.top.equalTo()(64)
            
        }
        
        
        

    }
    
    
    @objc func startTrans()  {
        let vc = PlayVideoViewController()
        self.navigationController?.present(vc, animated: true, completion: {

        })
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
