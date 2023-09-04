//
//  Created by ktiays on 2023/9/4.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

#ifndef CGPointMath_h
#define CGPointMath_h

#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

CGPoint CGPointAdd(const CGPoint lhs, const CGPoint rhs);

CGPoint CGPointSub(const CGPoint lhs, const CGPoint rhs);

CGPoint CGPointMul(const CGPoint lhs, const CGFloat rhs);

CGPoint CGPointDiv(const CGPoint lhs, const CGFloat rhs);

#ifdef __cplusplus
}
#endif

#endif /* CGPointMath_h */
