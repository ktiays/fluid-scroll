//
//  Created by ktiays on 2023/9/3.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

import UIKit
import SnapKit

class ViewController: UIViewController {
    
    private lazy var fluidScrollView: FluidScrollView = .init()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(fluidScrollView)
        fluidScrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

}
