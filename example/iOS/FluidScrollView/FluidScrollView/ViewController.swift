//
//  Created by ktiays on 2023/9/3.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

import UIKit
import SnapKit
import Combine
import SwiftUI

class ViewController: UIViewController {
    
    private lazy var fluidScrollView: FluidScrollView = .init()
    private var cancellables: Set<AnyCancellable> = .init()
    
    private var contentView: UIView!
    private var isContentViewLayout: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGroupedBackground
        
        self.title = "Fluid Scroll View"
        self.navigationController?.navigationBar.prefersLargeTitles = false
        
        contentView = ContentView().makeUIView()
        fluidScrollView.addSubview(contentView)
        
        fluidScrollView.alwaysBounceVertical = true
        fluidScrollView.addScrollObserver(self)
        view.addSubview(fluidScrollView)
        fluidScrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        NotificationCenter.default.publisher(for: NSNotification.Name.fsvScollViewWillScrollToTop).sink { [unowned self] _ in
            fluidScrollView.scrollToTop()
        }.store(in: &cancellables)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        if !isContentViewLayout {
            let contentViewSize = contentView.sizeThatFits(.init(width: view.bounds.width, height: .infinity))
            contentView.frame = .init(origin: .zero, size: .init(width: view.bounds.width, height: contentViewSize.height))
            fluidScrollView.contentSize = .init(width: 1, height: contentViewSize.height)
            isContentViewLayout = true
        }
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
