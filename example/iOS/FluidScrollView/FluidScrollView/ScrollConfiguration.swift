//
//  Created by ktiays on 2023/9/8.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

import Combine

class ScrollConfiguration: ObservableObject {
    @Published var horizontalDecelerationRate: CGFloat = UIScrollView.DecelerationRate.normal.rawValue
    @Published var verticalDecelerationRate: CGFloat = UIScrollView.DecelerationRate.normal.rawValue
    @Published var horizontalBounceResponse: CGFloat = 0.575
    @Published var verticalBounceResponse: CGFloat = 0.575
}
