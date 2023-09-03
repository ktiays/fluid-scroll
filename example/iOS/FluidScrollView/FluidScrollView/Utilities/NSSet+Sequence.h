//
//  Created by ktiays on 2023/9/4.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSSet<__covariant ObjectType> (Sequence)

- (nullable ObjectType)firstObject;

- (nullable ObjectType)filter:(BOOL (^)(ObjectType object))action;

@end

NS_ASSUME_NONNULL_END
