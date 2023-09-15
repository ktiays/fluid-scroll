//
//  Created by ktiays on 2023/9/4.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

#import <algorithm>

#include "CGPointMath.h"

CGPoint CGPointOne = CGPointMake(1, 1);

CGPoint CGPointClamp(const CGPoint point, CGPoint min, const CGPoint max) {
    min.x = std::min(min.x, max.x);
    min.y = std::min(min.y, max.y);
    return CGPointMake(
        std::max(min.x, std::min(point.x, max.x)),
        std::max(min.y, std::min(point.y, max.y))
    );
}
