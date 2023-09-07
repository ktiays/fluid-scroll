//
//  Created by ktiays on 2023/9/4.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

#ifndef CGPointMath_h
#define CGPointMath_h

#import <UIKit/UIKit.h>

extern CGPoint CGPointOne;

inline CGPoint CGPointAdd(const CGPoint lhs, const CGPoint rhs) {
    return CGPointMake(lhs.x + rhs.x, lhs.y + rhs.y);
}

inline CGPoint CGPointSub(const CGPoint lhs, const CGPoint rhs) {
    return CGPointMake(lhs.x - rhs.x, lhs.y - rhs.y);
}

inline CGPoint CGPointMul(const CGPoint lhs, const CGFloat rhs) {
    return CGPointMake(lhs.x * rhs, lhs.y * rhs);
}

inline CGPoint CGPointMul(const CGPoint lhs, const CGPoint rhs) {
    return CGPointMake(lhs.x * rhs.x, lhs.y * rhs.y);
}

inline CGPoint CGPointDiv(const CGPoint lhs, const CGFloat rhs) {
    return CGPointMake(lhs.x / rhs, lhs.y / rhs);
}

inline CGPoint CGPointDiv(const CGPoint lhs, const CGPoint rhs) {
    return CGPointMake(lhs.x / rhs.x, lhs.y / rhs.y);
}

CGPoint CGPointClamp(const CGPoint point, const CGPoint min, const CGPoint max);

#endif /* CGPointMath_h */
