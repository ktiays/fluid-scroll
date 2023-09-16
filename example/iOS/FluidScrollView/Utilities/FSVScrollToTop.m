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

#import <objc/runtime.h>

#import "FSVScrollToTop.h"

NSNotificationName kFSVScollViewWillScrollToTopNotification = @"kFSVScollViewWillScrollToTopNotification";

@implementation FSVScrollToTop

+ (void)load {
    // Use the block method to hook the `-handleTapAction:` method of `UIStatusBarManager`.
    Method original = class_getInstanceMethod(UIStatusBarManager.class, sel_registerName("handleTapAction:"));

    IMP originalImp = method_getImplementation(original);
    IMP imp = imp_implementationWithBlock(^(id _self, id arg) {
        // Call the original method.
        ((void (*)(id, id)) originalImp)(_self, arg);
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center postNotificationName:kFSVScollViewWillScrollToTopNotification object:nil];
    });
    method_setImplementation(original, imp);
}

@end
