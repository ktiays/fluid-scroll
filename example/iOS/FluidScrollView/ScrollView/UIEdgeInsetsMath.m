//
//  Created by ktiays on 2023/9/4.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

#import "UIEdgeInsetsMath.h"

UIEdgeInsets UIEdgeInsetsAdd(const UIEdgeInsets lhs, const UIEdgeInsets rhs) {
    const CGFloat top = lhs.top + rhs.top;
    const CGFloat left = lhs.left + rhs.left;
    const CGFloat right = lhs.right + rhs.right;
    const CGFloat bottom = lhs.bottom + rhs.bottom;
    return UIEdgeInsetsMake(top, left, bottom, right);
}
