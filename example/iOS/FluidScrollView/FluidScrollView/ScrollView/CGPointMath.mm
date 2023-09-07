//
//  Created by ktiays on 2023/9/4.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

#import <algorithm>

#include "CGPointMath.h"

CGPoint CGPointOne = CGPointMake(1, 1);

CGPoint CGPointClamp(const CGPoint point, const CGPoint min, const CGPoint max) {
    return CGPointMake(
        std::max(min.x, std::min(point.x, point.x)),
        std::max(min.y, std::min(point.y, point.y))
    );
}
