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
    private var lastViewportSize: CGSize = .zero
    
    private var isNavigationBarEffectVisible: Bool = false
    private var cachedNavigationBarEffectViews: [UIView] = []

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
        
        updateCachedViews()
        
        NotificationCenter.default.publisher(for: NSNotification.Name.fsvScollViewWillScrollToTop).sink { [unowned self] _ in
            fluidScrollView.scrollsToTop { [unowned self] in
                updateViewsVisibility(visible: false, animated: true)
                isNavigationBarEffectVisible = false
            }
        }.store(in: &cancellables)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let viewportSize = view.bounds.size
        if lastViewportSize == viewportSize { return }
        lastViewportSize = viewportSize
        
        let safeArea = view.safeAreaInsets
        let horizontalInset = safeArea.left + safeArea.right
        let contentViewSize = contentView.sizeThatFits(.init(width: viewportSize.width - horizontalInset, height: .infinity))
        contentView.frame = .init(
            origin: .zero,
            size: .init(width: viewportSize.width - horizontalInset, height: contentViewSize.height)
        )
        fluidScrollView.contentSize = .init(width: floor(contentViewSize.width), height: floor(contentViewSize.height))
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateCachedViews()
        updateNavigationBarEffect()
    }
    
    private func updateViewsVisibility(visible: Bool, animated: Bool = false) {
        isNavigationBarEffectVisible = visible
        let alpha: CGFloat = visible ? 1 : 0
        if animated {
            UIView.animate(withDuration: 0.4) { [self] in
                cachedNavigationBarEffectViews.forEach {
                    $0.alpha = alpha
                }
            }
        } else {
            cachedNavigationBarEffectViews.forEach {
                $0.alpha = alpha
            }
        }
    }
    
    private func updateCachedViews() {
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
        cachedNavigationBarEffectViews = viewsNeedChangeAlpha
    }
    
    private func updateNavigationBarEffect() {
        let offsetY = fluidScrollView.contentOffset.y
        let minOffsetY = fluidScrollView.minimumContentOffset.y
        updateViewsVisibility(visible: offsetY > minOffsetY)
    }

}

extension ViewController: FSVScrollViewScrollObserver {
    func observeScrollViewDidScroll(_ scrollView: FluidScrollView) {
        updateNavigationBarEffect()
    }
}
