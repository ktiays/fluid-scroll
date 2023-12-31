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

/// The stiffness of the edge spring effect, defined as an approximate duration in seconds.
@property (nonatomic, assign) CGFloat bounceResponse;

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

/// A Boolean value that determines whether bouncing always occurs when vertical scrolling reaches the end of the content.
///
/// The scroll view allows vertical dragging even if the content is smaller than the bounds of the scroll view.
/// The default value is `NO`.
@property (nonatomic, assign) BOOL alwaysBounceVertical;

/// A Boolean value that determines whether bouncing always occurs when horizontal scrolling reaches the end of the content view.
///
/// The scroll view allows horizontal dragging even if the content is smaller than the bounds of the scroll view.
/// The default value is `NO`.
@property (nonatomic, assign) BOOL alwaysBounceHorizontal;

/// The minimum point (in content view coordinates) that the content view can be scrolled.
@property (nonatomic, readonly) CGPoint minimumContentOffset;

/// The maximum point (in content view coordinates) that the content view can be scrolled.
@property (nonatomic, readonly) CGPoint maximumContentOffset;

/// Scrolls to the top of the content view.
- (void)scrollsToTopWithCompletion:(void (^)(void))completion;

/// Registers the observer object to receive scroll-related messages for the scroll view.
- (void)addScrollObserver:(id<FSVScrollViewScrollObserver>)observer NS_SWIFT_NAME(addScrollObserver(_:));

@end

NS_ASSUME_NONNULL_END
