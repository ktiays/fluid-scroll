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
    private var imagesHostView: UIView!
    private lazy var imagesView: FluidScrollView = .init()
    private var lastViewportSize: CGSize = .zero
    
    private var isNavigationBarEffectVisible: Bool = false
    private var cachedNavigationBarEffectViews: [UIView] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGroupedBackground
        
        self.title = "Fluid Scroll View"
        self.navigationController?.navigationBar.prefersLargeTitles = false
        self.navigationItem.rightBarButtonItem = .init(image: .init(systemName: "gearshape"), primaryAction: .init(handler: { [unowned self] _ in
            let settingsViewController = UIHostingController(
                rootView: SettingsView.init(
                    horizontalDecelerationRateDidChange: { value in
                        
                    }, horizontalBounceResponseDidChange: { value in
                        
                    }, verticalDecelerationRateDidChange: { value in
                        
                    }, verticalBounceResponseDidChange: { value in
                        
                    }
                )
            )
            if let sheet = settingsViewController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
            self.present(settingsViewController, animated: true)
        }))
        
        imagesHostView = Group {
            HStack(spacing: 16) {
                ForEach(0..<10) { _ in
                    AsyncImage(url: .init(string: "https://picsum.photos/600/400")) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(uiColor: .quaternarySystemFill)
                    }
                    .frame(width: 180, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding()
            .ignoresSafeArea()
        }.makeUIView()
        imagesView.addSubview(imagesHostView)
        imagesView.alwaysBounceHorizontal = true
        fluidScrollView.addSubview(imagesView)
        
        contentView = ContentView().makeUIView()
        fluidScrollView.addSubview(contentView)
        
        fluidScrollView.alwaysBounceVertical = true
        fluidScrollView.addScrollObserver(self)
        view.addSubview(fluidScrollView)
        fluidScrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
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
        
        let imagesSize = imagesHostView.sizeThatFits(.init(width: .infinity, height: viewportSize.height))
        imagesHostView.frame = .init(origin: .zero, size: imagesSize)
        imagesView.frame = .init(origin: .zero, size: .init(width: viewportSize.width, height: imagesSize.height))
        imagesView.contentSize = .init(width: floor(imagesSize.width), height: floor(imagesSize.height))
        
        let contentViewSize = contentView.sizeThatFits(.init(width: viewportSize.width - horizontalInset, height: .infinity))
        contentView.frame = .init(
            origin: .init(x: safeArea.left, y: imagesSize.height),
            size: .init(width: viewportSize.width - horizontalInset, height: contentViewSize.height)
        )
        fluidScrollView.contentSize = .init(
            width: floor(contentViewSize.width), 
            height: floor(contentViewSize.height + imagesSize.height)
        )
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
