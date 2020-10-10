//
//  CardStaticView.swift
//  PoseNet
//
//  Created by andyccc on 2020/10/14.
//  Copyright © 2020 tensorflow. All rights reserved.
//

import UIKit
import Masonry

class CardStaticView: UIView {
    
    var titleLabel : UILabel!
    
    var playTitleLabel : UILabel!
    var playCountLabel : UILabel!

    var historyTitleLabel : UILabel!
    var historyCountLabel : UILabel!

    var costTitleLabel : UILabel!
    var costCountLabel : UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupSubViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

    func setupSubViews() {
//        let frame = self.bounds
        
        
        self.setTitleLabel()
        self.setPlayLabel()
        self.setHistoryLabel()
        self.setCostLabel()
        self.setConstraints()
        
    }
    
    func setTitleLabel()  {
        titleLabel = UILabel()
        self.addSubview(titleLabel)
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = UIColor.black
        titleLabel.text = "帕梅拉有氧操"
        
    }
    
    func setPlayLabel() {
        playTitleLabel = UILabel()
        self.addSubview(playTitleLabel)

        playTitleLabel.font = UIFont.systemFont(ofSize: 14)
        playTitleLabel.textColor = UIColor.darkGray
        playTitleLabel.text = "累计播放"
       
        
        playCountLabel = UILabel()
        self.addSubview(playCountLabel)
        
        playCountLabel.textColor = UIColor.black
        playCountLabel.text = "0/5"
        playCountLabel.font = UIFont.boldSystemFont(ofSize: 15)
        
    }
    
    
    func setHistoryLabel() {
        historyTitleLabel = UILabel()
        self.addSubview(historyTitleLabel)

        historyTitleLabel.font = UIFont.systemFont(ofSize: 14)
        historyTitleLabel.textColor = UIColor.darkGray
        historyTitleLabel.text = "历史记录"

        historyCountLabel = UILabel()
        self.addSubview(historyCountLabel)
        
        historyCountLabel.textColor = UIColor.black
        historyCountLabel.text = "2.7"
        historyCountLabel.font = UIFont.boldSystemFont(ofSize: 15)
        
    }
    
    
    
    
    func setCostLabel() {
        costTitleLabel = UILabel()
        self.addSubview(costTitleLabel)

        costTitleLabel.font = UIFont.systemFont(ofSize: 14)
        costTitleLabel.textColor = UIColor.darkGray
        costTitleLabel.text = "累计消耗千卡"
        
        costCountLabel = UILabel()
        self.addSubview(costCountLabel)
        
        costCountLabel.textColor = UIColor.black
        costCountLabel.text = "0"
        costCountLabel.font = UIFont.boldSystemFont(ofSize: 15)
        

    }
    
    
    func setConstraints() {
        titleLabel.mas_makeConstraints { (make) in
            make!.top.offset()(10)
            make!.left.offset()(10)
            make!.width.equalTo()(16 * 20)
            make!.height.equalTo()(20)
        }
        
        
        playTitleLabel.mas_makeConstraints { (make) in
            make!.top.equalTo()(titleLabel.mas_bottom)?.offset()(10)
            make!.left.equalTo()(titleLabel)
            make!.width.equalTo()(4 * 16)
            make!.height.equalTo()(16)
        }

        playCountLabel.mas_makeConstraints { (make) in
            make!.top.equalTo()(playTitleLabel.mas_bottom)?.offset()(5)
            make!.left.equalTo()(playTitleLabel)
            make!.width.equalTo()(playTitleLabel)
            make!.height.equalTo()(16)
        }

        
        historyTitleLabel.mas_makeConstraints { (make) in
            make!.top.equalTo()(playTitleLabel)
            make!.left.equalTo()(playTitleLabel.mas_right)?.offset()(30)
            make!.width.equalTo()(4 * 16)
            make!.height.equalTo()(16)
        }
        

        historyCountLabel.mas_makeConstraints { (make) in
            make!.top.equalTo()(playCountLabel)
            make!.left.equalTo()(historyTitleLabel)
            make!.width.equalTo()(historyTitleLabel)
            make!.height.equalTo()(16)
        }

        
        costTitleLabel.mas_makeConstraints { (make) in
            make!.top.equalTo()(playTitleLabel)
            make!.left.equalTo()(historyTitleLabel.mas_right)?.offset()(30)
            make!.width.equalTo()(6 * 16)
            make!.height.equalTo()(16)
        }

        costCountLabel.mas_makeConstraints { (make) in
            make!.top.equalTo()(playCountLabel)
            make!.left.equalTo()(costTitleLabel)
            make!.width.equalTo()(costTitleLabel)
            make!.height.equalTo()(16)
        }
    
    }
    
}
