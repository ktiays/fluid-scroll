//
//  Created by ktiays on 2023/9/4.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

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
