//
//  Created by ktiays on 2023/9/4.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

#import "NSSet+Sequence.h"

@implementation NSSet (Sequence)

- (nullable id)firstObject {
    return [[self allObjects] firstObject];
}

- (nullable id)filter:(BOOL (^)(id _Nonnull))action {
    if (!action) {
        return nil;
    }
    for (id object in self) {
        if (action(object)) {
            return object;
        }
    }
    return nil;
}

@end
