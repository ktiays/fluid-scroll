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
    if (rhs == 0) {
        return lhs;
    }
    return CGPointMake(lhs.x / rhs, lhs.y / rhs);
}

inline CGPoint CGPointDiv(const CGPoint lhs, const CGPoint rhs) {
    return CGPointMake(rhs.x == 0 ? lhs.x : (lhs.x / rhs.x), rhs.y == 0 ? lhs.y : (lhs.y / rhs.y));
}

CGPoint CGPointClamp(const CGPoint point, const CGPoint min, const CGPoint max);

#endif /* CGPointMath_h */
