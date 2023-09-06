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
    
    private var isNavigationBarEffectVisible: Bool = false

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
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
        }
        
        NotificationCenter.default.publisher(for: NSNotification.Name.fsvScollViewWillScrollToTop).sink { [unowned self] _ in
            fluidScrollView.scrollsToTop {
                
            }
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
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        _updateNavigatonBarEffect(visible: isNavigationBarEffectVisible, animated: false)
    }
    
    private func updateNavigationBarEffect(visible: Bool, animated: Bool = false) {
        if visible == isNavigationBarEffectVisible { return }
        _updateNavigatonBarEffect(visible: visible, animated: animated)
        isNavigationBarEffectVisible = visible
    }
    
    private func _updateNavigatonBarEffect(visible: Bool, animated: Bool) {
        guard let navigationBar = self.navigationController?.navigationBar else { return }
        guard let barBackground = navigationBar.subviews.first else { return }
        if !barBackground.isKind(of: NSClassFromString("_UIBarBackground")!) { return }
        
        var viewsNeedChangeAlpha: [UIView] = []
        for subview in barBackground.subviews {
            if subview.isKind(of: NSClassFromString("_UIBarBackgroundShadowView")!) {
                if let imageView = subview.subviews.first as? UIImageView {
                    viewsNeedChangeAlpha.append(imageView)
                }
            } else {
                viewsNeedChangeAlpha.append(subview)
            }
        }
        
        let alpha: CGFloat = visible ? 1 : 0
        if animated {
            UIView.animate(withDuration: 0.4) {
                viewsNeedChangeAlpha.forEach {
                    $0.alpha = alpha
                }
            }
        } else {
            viewsNeedChangeAlpha.forEach {
                $0.alpha = alpha
            }
        }
    }

}

extension ViewController: FSVScrollViewScrollObserver {
    func observeScrollViewDidScroll(_ scrollView: FluidScrollView) {
        let offsetY = scrollView.contentOffset.y
        let minOffsetY = scrollView.minimumContentOffset.y
        updateNavigationBarEffect(visible: offsetY > minOffsetY)
    }
}
