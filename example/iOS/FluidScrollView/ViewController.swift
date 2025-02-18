// Copyright 2023 ktiays
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import SnapKit
import Combine
import SwiftUI

class ViewController: UIViewController {
    
    #if USE_SYSTEM_SCROLL_VIEW
    private lazy var scrollView: UIScrollView = .init()
    #else
    private lazy var scrollView: FluidScrollView = .init()
    #endif
    private var cancellables: Set<AnyCancellable> = .init()
    
    private var contentView: UIView!
    private var imagesHostView: UIView!
    #if USE_SYSTEM_SCROLL_VIEW
    private lazy var imagesView: UIScrollView = .init()
    #else
    private lazy var imagesView: FluidScrollView = .init()
    #endif
    private var lastViewportSize: CGSize = .zero
    
    private var isNavigationBarEffectVisible: Bool = false
    private var cachedNavigationBarEffectViews: [UIView] = []
    
    private let scrollConfiguration = ScrollConfiguration()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGroupedBackground
        
        self.title = "Fluid Scroll View"
        self.navigationController?.navigationBar.prefersLargeTitles = false
        self.navigationItem.rightBarButtonItem = .init(image: .init(systemName: "gearshape"), primaryAction: .init(handler: { [unowned self] _ in
            let settingsViewController = UIHostingController(rootView: SettingsView(configuration: scrollConfiguration))
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
        scrollView.addSubview(imagesView)
        
        contentView = ContentView().makeUIView()
        scrollView.addSubview(contentView)
        
        scrollView.alwaysBounceVertical = true
        #if USE_SYSTEM_SCROLL_VIEW
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        #else
        scrollView.addScrollObserver(self)
        #endif
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        updateCachedViews()
    
        #if !USE_SYSTEM_SCROLL_VIEW
        NotificationCenter.default.publisher(for: NSNotification.Name.fsvScollViewWillScrollToTop).sink { [unowned self] _ in
            scrollView.scrollsToTop { [unowned self] in
                updateViewsVisibility(visible: false, animated: true)
                isNavigationBarEffectVisible = false
            }
        }.store(in: &cancellables)
        scrollConfiguration.objectWillChange.sink { [unowned self] _ in
            scrollView.decelerationRate = .init(rawValue: scrollConfiguration.verticalDecelerationRate)
            scrollView.bounceResponse = scrollConfiguration.verticalBounceResponse
            imagesView.decelerationRate = .init(rawValue: scrollConfiguration.horizontalDecelerationRate)
            imagesView.bounceResponse = scrollConfiguration.horizontalBounceResponse
        }.store(in: &cancellables)
        #endif
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
        scrollView.contentSize = .init(
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
        let offsetY = scrollView.contentOffset.y
        let minOffsetY = scrollView.minimumContentOffset.y
        updateViewsVisibility(visible: offsetY > minOffsetY)
    }

}

#if USE_SYSTEM_SCROLL_VIEW
extension UIScrollView {
    var minimumContentOffset: CGPoint {
        .init(x: -adjustedContentInset.left, y: -adjustedContentInset.top)
    }
}
#else
extension ViewController: FSVScrollViewScrollObserver {
    func observeScrollViewDidScroll(_ scrollView: FluidScrollView) {
        updateNavigationBarEffect()
    }
}
#endif
