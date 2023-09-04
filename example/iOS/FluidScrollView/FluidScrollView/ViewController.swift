//
//  Created by ktiays on 2023/9/3.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

import UIKit
import SnapKit
import Combine

class ViewController: UIViewController {
    
    private lazy var fluidScrollView: FluidScrollView = .init()
    private var cancellables: Set<AnyCancellable> = .init()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Fluid Scroll View"
        self.navigationController?.navigationBar.prefersLargeTitles = false
        
        view.addSubview(fluidScrollView)
        fluidScrollView.addScrollObserver(self)
        fluidScrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
//        let view = UIScrollView()
//        view.contentSize = .init(width: 1, height: 2000)
//        self.view.addSubview(view)
//        view.snp.makeConstraints { make in
//            make.edges.equalToSuperview()
//        }
        
        NotificationCenter.default.publisher(for: NSNotification.Name.fsvScollViewWillScrollToTop).sink { [unowned self] _ in
            fluidScrollView.scrollToTop()
        }.store(in: &cancellables)
    }
    
    private func updateNavigationBarEffect(visible: Bool, animated: Bool = false) {
        guard let navigationBar = self.navigationController?.navigationBar else { return }
        guard let barBackground = navigationBar.subviews.first else { return }
        if !barBackground.isKind(of: NSClassFromString("_UIBarBackground")!) { return }
    }

}

extension ViewController: FSVScrollViewScrollObserver {
    func observeScrollViewDidScroll(_ scrollView: FluidScrollView) {
        
    }
}
