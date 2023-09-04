//
//  Created by ktiays on 2023/9/4.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

#include "CGPointMath.h"

CGPoint CGPointAdd(const CGPoint lhs, const CGPoint rhs) {
    return CGPointMake(lhs.x + rhs.x, lhs.y + rhs.y);
}

CGPoint CGPointSub(const CGPoint lhs, const CGPoint rhs) {
    return CGPointMake(lhs.x - rhs.x, lhs.y - rhs.y);
}

CGPoint CGPointMul(const CGPoint lhs, const CGFloat rhs) {
    return CGPointMake(lhs.x * rhs, lhs.y * rhs);
}

CGPoint CGPointDiv(const CGPoint lhs, const CGFloat rhs) {
    return CGPointMake(lhs.x / rhs, lhs.y / rhs);
}
