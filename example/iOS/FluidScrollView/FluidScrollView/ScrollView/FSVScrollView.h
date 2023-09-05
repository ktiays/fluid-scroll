//
//  Created by ktiays on 2023/9/3.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

#import <UIKit/UIKit.h>

#import "FSVScrollViewScrollObserver.h"

NS_ASSUME_NONNULL_BEGIN

/// A view that behaves like a `UIScrollView`, allowing the contained views to be scrolled.
NS_SWIFT_NAME(FluidScrollView)
@interface FSVScrollView : UIView

/// The point at which the origin of the content view is offset from the origin of the scroll view.
@property (nonatomic, assign) CGPoint contentOffset;

/// The size of the content view.
@property (nonatomic, assign) CGSize contentSize;

/// The custom distance that the content view is inset from the safe area or scroll view edges.
///
/// Use this property to extend the space between your content and the edges of the content view.
/// The unit of size is points.
/// The default value is `UIEdgeInsetsZero`.
@property (nonatomic, assign) UIEdgeInsets contentInsets;

/// The insets derived from the content insets and the safe area of the scroll view.
@property (nonatomic, assign, readonly) UIEdgeInsets adjustedContentInset;

/// A floating-point value that determines the rate of deceleration after the user lifts their finger.
///
/// The default rate is `UIScrollViewDecelerationRateNormal`.
@property (nonatomic, assign) UIScrollViewDecelerationRate decelerationRate;

/// A Boolean value that indicates whether the user has touched the content to initiate scrolling.
///
/// The value of this property is `YES` if the user has touched the content view but might not have yet have started dragging it.
@property (nonatomic, readonly, getter=isTracking) BOOL tracking;

/// A Boolean value that indicates whether the user has begun scrolling the content.
///
/// The value held by this property might require some time or distance of scrolling before it returns `YES`.
@property (nonatomic, readonly, getter=isDragging) BOOL dragging;

/// A Boolean value that indicates whether the content is moving in the scroll view after the user lifted their finger.
///
/// The returned value is `YES` if user isn’t dragging the content but scrolling is still occurring.
@property (nonatomic, readonly, getter=isDecelerating) BOOL decelerating;

- (void)scrollToTop;

- (void)addScrollObserver:(id<FSVScrollViewScrollObserver>)observer NS_SWIFT_NAME(addScrollObserver(_:));

@end

NS_ASSUME_NONNULL_END
