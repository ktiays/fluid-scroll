//
//  Created by ktiays on 2023/9/3.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

#import <UIKit/UIKit.h>

#import "FSVScrollViewScrollObserver.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(FluidScrollView)
@interface FSVScrollView : UIView

@property (nonatomic, assign) CGPoint contentOffset;

@property (nonatomic, assign) CGSize contentSize;

@property (nonatomic, assign) UIEdgeInsets contentInsets;

@property (nonatomic, assign, readonly) UIEdgeInsets adjustedContentInset;

@property (nonatomic, assign) UIScrollViewDecelerationRate decelerationRate;

- (void)scrollToTop;

- (void)addScrollObserver:(id<FSVScrollViewScrollObserver>)observer NS_SWIFT_NAME(addScrollObserver(_:));

@end

NS_ASSUME_NONNULL_END
