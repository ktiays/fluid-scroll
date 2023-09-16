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

#import "UIEdgeInsetsMath.h"

UIEdgeInsets UIEdgeInsetsAdd(const UIEdgeInsets lhs, const UIEdgeInsets rhs) {
    const CGFloat top = lhs.top + rhs.top;
    const CGFloat left = lhs.left + rhs.left;
    const CGFloat right = lhs.right + rhs.right;
    const CGFloat bottom = lhs.bottom + rhs.bottom;
    return UIEdgeInsetsMake(top, left, bottom, right);
}
