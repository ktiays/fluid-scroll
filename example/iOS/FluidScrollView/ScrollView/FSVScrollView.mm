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

#import <iostream>
#import <memory>
#import <optional>
#import <cassert>
#import <cmath>

#import "FSVScrollView.h"
#import "fluid_scroll.h"

#import "NSSet+Sequence.h"
#import "CGPointMath.h"
#import "UIEdgeInsetsMath.h"

#define FSV_DIRECT __attribute__((objc_direct))

#define AXIS_HANDLER(__X, __Y, __D) \
    switch (axis) { \
        case UIAxisHorizontal: \
            return __X; \
        case UIAxisVertical: \
            return __Y; \
        default: \
            return __D; \
    }

template <typename T>
static T signum(T x) {
    if (x > 0) {
        return 1;
    } else if (x < 0) {
        return -1;
    } else {
        return 0;
    }
}

static CGFloat CGPointValue(CGPoint point, UIAxis axis) {
    AXIS_HANDLER(point.x, point.y, 0);
}

static CGFloat kDefaultSpringBackResponse = 0.575;

/// Enumerates horizontal and vertical axes to perform the specified action.
static void enumerate_axes(void (^action)(UIAxis axis)) {
    action(UIAxisHorizontal);
    action(UIAxisVertical);
}

struct TouchProxy;

@protocol _FSVTouchDelegate <NSObject>

- (void)_handlePan:(const TouchProxy &)proxy;

@end

struct TouchProxy {
public:
    enum State {
        POSSIBLE,
        BEGAN,
        CHANGED,
        ENDED,
        CANCELLED,
    };
    
    TouchProxy(UIView<_FSVTouchDelegate> *view)
        : delegate_(view),
          state_(POSSIBLE),
          velocity_tracker_x_(nullptr),
          velocity_tracker_y_(nullptr) {}
    
    State state() const {
        return state_;
    }
    
    CGPoint translation() const {
        return CGPointAdd(previous_traslation_, CGPointSub(active_touch_location(), active_touch_begin_location_));
    }
    
    CGPoint velocity() const {
        const auto vx = fl_velocity_tracker_calculate_velocity(velocity_tracker_x_);
        const auto vy = fl_velocity_tracker_calculate_velocity(velocity_tracker_y_);
        return CGPointMake(vx, vy);
    }
    
    void begin_with_touches(NSSet<UITouch *> *touches) {
        if (active_touch_ != nil) {
            // It means a touch event is already in progress.
            // Current touch will be treated as a new response touch.
            auto enumerator = [touches objectEnumerator];
            UITouch *touch;
            while (touch = [enumerator nextObject]) {
                if (touch != active_touch_) {
                    break;
                }
            }
            // There are no other available instances of `UITouch`.
            if (!touch) {
                return;
            }
            previous_traslation_ = translation();
            active_touch_begin_location_ = touch_location(touch);
            
            active_touch_ = touch;
        } else {
            state_ = BEGAN;
            active_touch_ = [touches firstObject];
            touch_begin_time_ = active_touch_.timestamp;
            active_touch_begin_location_ = active_touch_location();
        }
        add_current_location();
        [delegate_ _handlePan:*this];
    }
    
    void move_with_touches(NSSet<UITouch *> *touches) {
        if (![touches containsObject:active_touch_]) {
            return;
        }
        state_ = CHANGED;
        add_current_location();
        [delegate_ _handlePan:*this];
    }
    
    void end_with_touches(NSSet<UITouch *> *touches, bool cancelled) {
        if (![touches containsObject:active_touch_]) {
            return;
        }
        state_ = cancelled ? CANCELLED : ENDED;
        add_current_location();
        [delegate_ _handlePan:*this];
        state_ = POSSIBLE;
    }
    
    void reset() {
        if (velocity_tracker_x_ != nullptr) {
            fl_velocity_tracker_reset(velocity_tracker_x_);
        }
        if (velocity_tracker_y_ != nullptr) {
            fl_velocity_tracker_reset(velocity_tracker_y_);
        }
        state_ = POSSIBLE;
        previous_traslation_ = CGPointZero;
        active_touch_ = nil;
        active_touch_begin_location_ = CGPointZero;
    }
    
    ~TouchProxy() {
        if (velocity_tracker_x_ != nullptr) {
            fl_velocity_tracker_free(velocity_tracker_x_);
        }
        if (velocity_tracker_y_ != nullptr) {
            fl_velocity_tracker_free(velocity_tracker_y_);
        }
    }
    
private:
    State state_;
    __weak UIView<_FSVTouchDelegate> *delegate_;
    
    FlVelocityTracker *velocity_tracker_x_;
    FlVelocityTracker *velocity_tracker_y_;
    
    CGPoint previous_traslation_;
    UITouch *active_touch_;
    CGPoint active_touch_begin_location_;
    CFTimeInterval touch_begin_time_;
    
    CGPoint touch_location(UITouch *touch) const {
        return [touch locationInView:delegate_.window];
    }
    
    CGPoint active_touch_location() const {
        return touch_location(active_touch_);
    }
    
    void add_current_location() {
        if (velocity_tracker_x_ == nullptr) {
            velocity_tracker_x_ = fl_velocity_tracker_new(FL_VELOCITY_TRACKER_RECURRENCE_STRATEGY);
        }
        if (velocity_tracker_y_ == nullptr) {
            velocity_tracker_y_ = fl_velocity_tracker_new(FL_VELOCITY_TRACKER_RECURRENCE_STRATEGY);
        }
        const auto now = static_cast<float>((active_touch_.timestamp - touch_begin_time_) * 1e3);
        const auto trans = translation();
        fl_velocity_tracker_add_data_point(velocity_tracker_x_, now, static_cast<float>(trans.x));
        fl_velocity_tracker_add_data_point(velocity_tracker_y_, now, static_cast<float>(trans.y));
    }
};

enum class _BounceEdge {
    NONE,
    MIN, MAX
};

/// A struct that records the state of the scroll animation.
struct _ScrollProperties {
public:
    bool is_decelerating = false;
    bool is_bouncing = false;
    
    _BounceEdge bounce_edge = _BounceEdge::NONE;
    
    CGFloat animation_begin_time = 0;
    CGFloat animation_begin_offset = 0;
    CGFloat animation_begin_velocity = 0;
    
    FlScroller *scroller = nullptr;
    FlSpringBack *spring_back = nullptr;
    
    void clear() {
        is_decelerating = false;
        is_bouncing = false;
        bounce_edge = _BounceEdge::NONE;
        animation_begin_time = 0;
        animation_begin_offset = 0;
        animation_begin_velocity = 0;
    }
    
    void reset(CGFloat velocity, CGFloat offset) {
        if (scroller != nullptr) {
            fl_scroller_reset(scroller);
        }
        if (spring_back != nullptr) {
            fl_spring_back_reset(spring_back);
        }
        
        assert(!std::isnan(velocity) && !std::isnan(offset));
        animation_begin_offset = offset;
        animation_begin_time = CACurrentMediaTime();
        animation_begin_velocity = velocity;
    }
    
    void prepare_scroller(UIScrollViewDecelerationRate rate) {
        if (scroller == nullptr) {
            scroller = new FlScroller;
            fl_scroller_init(scroller, (float) rate);
        }
        fl_scroller_set_deceleration_rate(scroller, rate);
    }
    
    void prepare_spring_back() {
        if (spring_back == nullptr) {
            spring_back = new FlSpringBack;
            fl_spring_back_init(spring_back);
        }
    }
    
    ~_ScrollProperties() {
        if (scroller != nullptr) {
            delete scroller;
        }
        if (spring_back != nullptr) {
            delete spring_back;
        }
    }
};

#define GET_AXIS_PROPERTIES const auto properties = [self _scrollPropertiesForAxis:axis]

@interface FSVScrollView () <_FSVTouchDelegate>

@end

@implementation FSVScrollView {
    CADisplayLink *_displayLink;
    NSHashTable *_scrollObservers;
    bool _isFirstLayout;
    void (^_scrollsToTopAnimationCallback)(void);
    bool _ignoreScrollObserver;
    
    std::unique_ptr<TouchProxy> _touchProxy;
    // Records the translation of the gesture's first response.
    std::optional<CGPoint> _touchBeganTranslation;
    BOOL _isTracking;
    BOOL _isDragging;
    CGPoint _lastContentOffset;
    
    std::shared_ptr<_ScrollProperties> _propertiesX;
    std::shared_ptr<_ScrollProperties> _propertiesY;
    
    CGPoint _cachedMinimumContentOffset;
    CGPoint _cachedMaximumContentOffset;
    bool _isCachedMinMaxContentOffsetInvalid;
    
    // Records touch events that result in conflicts.
    NSMutableSet<UITouch *> *_ignoredTouches;
    UIImpactFeedbackGenerator *_impactFeedback;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _isFirstLayout = true;
        _scrollObservers = [NSHashTable weakObjectsHashTable];
        _decelerationRate = UIScrollViewDecelerationRateNormal;
        _bounceResponse = kDefaultSpringBackResponse;
        _isCachedMinMaxContentOffsetInvalid = true;
        _propertiesX = std::make_shared<_ScrollProperties>();
        _propertiesY = std::make_shared<_ScrollProperties>();
        _ignoredTouches = [NSMutableSet set];
        _impactFeedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
    }
    return self;
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    
    if (self.superview) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_handleDisplayLinkFire:)];
        _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(60, 120, 120);
        [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    } else {
        [_displayLink invalidate];
        _displayLink = nil;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (_isFirstLayout) {
        const auto minimumContentOffset = self.minimumContentOffset;
        _contentOffset = CGPointMake(
            [self _canHorizontalScroll] ? minimumContentOffset.x : 0,
            [self _canVerticalScroll] ? minimumContentOffset.y : 0
        );
        _isFirstLayout = false;
    }
    const auto size = self.bounds.size;
    self.bounds = CGRectMake(_contentOffset.x, _contentOffset.y, size.width, size.height);
}

- (BOOL)isMultipleTouchEnabled {
    return true;
}

#pragma mark - Touches

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        const auto location = [touch locationInView:self.window];
        for (UIView *view in self.subviews) {
            // If there is a scroll view under the touch position and it can respond to events, then pass the touch event to the subview.
            //
            // ps. This is a simple processing method, and the effect is not the best.
            const auto rect = [view convertRect:view.frame toView:nil];
            if (view.isUserInteractionEnabled && [view isKindOfClass:self.class]) {
                if (CGRectContainsPoint(rect, location)) {
                    [_ignoredTouches addObject:touch];
                    [super touchesBegan:touches withEvent:event];
                    return;
                }
            }
        }
    }
    if (!_touchProxy) {
        _touchProxy = std::make_unique<TouchProxy>(self);
    }
    if (_touchProxy->state() == TouchProxy::POSSIBLE) {
        // Non-possible state indicates that there is currently an active touch event.
        _touchProxy->reset();
    }
    _touchProxy->begin_with_touches(touches);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        if ([_ignoredTouches containsObject:touch]) {
            [super touchesMoved:touches withEvent:event];
            return;
        }
    }
    _touchProxy->move_with_touches(touches);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    bool ignore = false;
    for (UITouch *touch in touches) {
        if ([_ignoredTouches containsObject:touch]) {
            ignore = true;
            // Removes the element from the record when touch ends.
            [_ignoredTouches removeObject:touch];
        }
    }
    if (ignore) {
        [super touchesEnded:touches withEvent:event];
        return;
    }
    _touchProxy->end_with_touches(touches, false);
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    _touchProxy->end_with_touches(touches, true);
}

- (void)_handlePan:(const TouchProxy &)proxy {
    const auto canHorizontalScroll = [self _canHorizontalScroll];
    const auto canVerticalScroll = [self _canVerticalScroll];
    
    const auto viewportSize = self.bounds.size;
    const auto minContentOffset = self.minimumContentOffset;
    const auto maxContentOffset = self.maximumContentOffset;
    
    switch (proxy.state()) {
        case TouchProxy::State::BEGAN:
            // When the touch event began, clear all animation states.
            _isTracking = true;
            _isDragging = false;
            _propertiesX->clear();
            _propertiesY->clear();
            _scrollsToTopAnimationCallback = nil;
            _ignoreScrollObserver = false;
            _lastContentOffset.x = [self _rubberBandForOffset:_contentOffset.x
                                                    minOffset:minContentOffset.x
                                                    maxOffset:maxContentOffset.x
                                                        range:viewportSize.width
                                                      inverse:true];
            _lastContentOffset.y = [self _rubberBandForOffset:_contentOffset.y
                                                    minOffset:minContentOffset.y
                                                    maxOffset:maxContentOffset.y
                                                        range:viewportSize.height
                                                      inverse:true];
            _touchBeganTranslation = std::nullopt;
            break;
        case TouchProxy::State::CHANGED: {
            _isTracking = false;
            _isDragging = true;
            
            auto translation = proxy.translation();
            // There is a significant delay between the system calling `touchesBegan:withEvent:` and `touchesMoved:withEvent:`,
            // which can cause large position mutated when responding to gesture.
            // We use the translation of the first call to `touchesMoved:withEvent:` as a baseline to avoid this issue.
            if (!_touchBeganTranslation.has_value()) {
                _touchBeganTranslation = translation;
            }
            translation = CGPointSub(translation, *_touchBeganTranslation);
            const auto x = canHorizontalScroll ? translation.x : 0;
            const auto y = canVerticalScroll ? translation.y : 0;
            auto targetContentOffsetX = _lastContentOffset.x - x;
            auto targetContentOffsetY = _lastContentOffset.y -y;
            targetContentOffsetX = [self _rubberBandForOffset:targetContentOffsetX
                                                    minOffset:minContentOffset.x
                                                    maxOffset:maxContentOffset.x
                                                        range:viewportSize.width
                                                      inverse:false];
            targetContentOffsetY = [self _rubberBandForOffset:targetContentOffsetY
                                                    minOffset:minContentOffset.y
                                                    maxOffset:maxContentOffset.y
                                                        range:viewportSize.height
                                                      inverse:false];
            self.contentOffset = CGPointMake(targetContentOffsetX, targetContentOffsetY);
            [self _notifyScrollObservers];
        } break;
        case TouchProxy::State::ENDED:
        case TouchProxy::State::CANCELLED: {
            _isDragging = false;
            // The direction of the gesture velocity is opposite to the sign of the content offset change.
            auto velocity = proxy.velocity();
            if (fl_velocity_approaching_halt(velocity.x, velocity.y)) {
                velocity = CGPointZero;
            }
            if (!canHorizontalScroll) velocity.x = 0;
            if (!canVerticalScroll) velocity.y = 0;
            [self _handleEndPanWithVelocity:velocity];
            [_impactFeedback prepare];
        } break;
        default:
            break;
    }
}

#pragma mark - Actions

- (void)_handleEndPanWithVelocity:(CGPoint)velocity FSV_DIRECT {
    enumerate_axes(^(UIAxis axis) {
        const auto v = CGPointValue(velocity, axis);
        GET_AXIS_PROPERTIES;
        const auto overflow = [self _overflowOffsetForAxis:axis];
        if (overflow != 0) {
            [self _prepareBouncingWithVelocity:v overflowVelocity:true axis:axis];
            return;
        }
        
        if (v != 0) {
            properties->prepare_scroller(self->_decelerationRate);
            properties->reset(v, [self _offsetForAxis:axis]);
            fl_scroller_fling(properties->scroller, v);
            properties->is_decelerating = true;
        }
    });
}

- (void)_handleDisplayLinkFire:(CADisplayLink *)sender {
    enumerate_axes(^(UIAxis axis) {
        GET_AXIS_PROPERTIES;
        
        if (properties->is_decelerating) {
            const auto interval = (CACurrentMediaTime() - properties->animation_begin_time) * 1e3;
            CGFloat velocity;
            properties->is_decelerating = ![self _handleDeceleratingWithInterval:interval finalVelocity:&velocity axis:axis];
            
            const auto overflow = [self _overflowOffsetForAxis:axis];
            if (properties->is_decelerating && overflow != 0) {
                properties->is_decelerating = false;
                // Just for fun ^_^
                [self->_impactFeedback impactOccurredWithIntensity:std::min(std::abs(velocity), 5.0) / 5];
                [self->_impactFeedback prepare];
                [self _prepareBouncingWithVelocity:velocity overflowVelocity:false axis:axis];
            }
            [self _setNeedsLayoutWithNotify];
        }
        
        if (properties->is_bouncing) {
            const auto interval = (CACurrentMediaTime() - properties->animation_begin_time) * 1e3;
            properties->is_bouncing = ![self _handleBouncingWithInterval:interval axis:axis];
            if (axis == UIAxisVertical) {
                if (self->_scrollsToTopAnimationCallback) {
                    const auto offset = [self _offsetForAxis:axis];
                    const auto minOffset = [self _minimumOffsetForAxis:axis];
                    // When performing the scroll-to-top animation, it is necessary to allow some extra time 
                    // for the navigation bar to complete its alpha animation.
                    if (std::abs(offset - minOffset) <= 2) {
                        self->_scrollsToTopAnimationCallback();
                        self->_scrollsToTopAnimationCallback = nil;
                    }
                }
                if (!properties->is_bouncing) {
                    self->_ignoreScrollObserver = false;
                }
            }
            [self _setNeedsLayoutWithNotify];
        }
    });
}

- (bool)_handleDeceleratingWithInterval:(CFTimeInterval)interval finalVelocity:(CGFloat *)velocityPointer axis:(UIAxis)axis FSV_DIRECT {
    GET_AXIS_PROPERTIES;
    bool finish = false;
    auto targetOffset = [self _offsetForAxis:axis];
    CGFloat finalVelocity = 0;
    const auto value = fl_scroller_value(properties->scroller, (float) interval, &finish);
    if (!finish) {
        const auto offset = value.offset;
        finalVelocity = value.velocity;
        targetOffset = properties->animation_begin_offset - offset;
    }
    if (velocityPointer != nullptr) {
        *velocityPointer = finalVelocity;
    }
    [self _setContentOffsetValue:targetOffset forAxis:axis];
    return finish;
}

- (void)_prepareBouncingWithVelocity:(CGFloat)velocity overflowVelocity:(bool)overflowVelocity axis:(UIAxis)axis FSV_DIRECT {
    GET_AXIS_PROPERTIES;
    // Divide the overflow distance by 100 as the initial bounce velocity of the current position.
    const auto overV = [self _overflowOffsetForAxis:axis] / 100;
    if (overflowVelocity) {
        if (std::signbit(overV) != std::signbit(velocity)) {
            velocity += overV;
        } else {
            velocity = overV;
        }
    }
    
    properties->prepare_spring_back();
    properties->reset(velocity, 0);
    
    const auto minOffset = [self _minimumOffsetForAxis:axis];
    const auto maxContentOffset = [self _maximumOffsetForAxis:axis];
    
    CGFloat targetOffset = 0;
    if (overV < 0) {
        properties->bounce_edge = _BounceEdge::MIN;
        targetOffset = minOffset;
    } else if (overV > 0) {
        properties->bounce_edge = _BounceEdge::MAX;
        targetOffset = maxContentOffset;
    }
    if (properties->bounce_edge != _BounceEdge::NONE) {
        fl_spring_back_absorb_with_response(properties->spring_back, velocity, targetOffset - [self _offsetForAxis:axis], _bounceResponse);
        properties->is_bouncing = true;
    }
}

- (bool)_handleBouncingWithInterval:(CFTimeInterval)interval axis:(UIAxis)axis FSV_DIRECT {
    GET_AXIS_PROPERTIES;
    
    const auto minContentOffset = [self _minimumOffsetForAxis:axis];
    const auto maxContentOffset = [self _maximumOffsetForAxis:axis];
    CGFloat targetContentOffset = [self _offsetForAxis:axis];
    bool finish = true;
    if (properties->bounce_edge != _BounceEdge::NONE) {
        const auto target = properties->bounce_edge == _BounceEdge::MIN ? minContentOffset : maxContentOffset;
        const auto offset = fl_spring_back_value(properties->spring_back, interval, &finish);
        targetContentOffset = target - offset;
    }
    [self _setContentOffsetValue:targetContentOffset forAxis:axis];
    return finish;
}

- (CGFloat)_rubberBandForOffset:(CGFloat)offset 
                      minOffset:(CGFloat)minOffset
                      maxOffset:(CGFloat)maxOffset
                          range:(CGFloat)range
                        inverse:(bool)inverse FSV_DIRECT {
    if (std::abs(range) < CGFLOAT_EPSILON) {
        return offset;
    }
    
    const auto min = minOffset;
    const auto max = std::max(minOffset, maxOffset);
    
    if (min <= offset && offset <= max) {
        return offset;
    }
    
    const auto target = offset < min ? min : max;
    const auto distance = offset - target;
    const auto transformed =
        inverse ? fl_calculate_rubber_band_offset_inv(std::abs(distance), range) : fl_calculate_rubber_band_offset(std::abs(distance), range);
    return target + transformed * signum(distance);
}

- (void)_setContentOffsetValue:(CGFloat)value forAxis:(UIAxis)axis FSV_DIRECT {
    switch (axis) {
        case UIAxisHorizontal:
            _contentOffset.x = value;
            break;
        case UIAxisVertical:
            _contentOffset.y = value;
            break;
        default:
            break;
    }
}

#pragma mark - Public Methods

- (void)scrollsToTopWithCompletion:(void (^)(void))completion {
    if (![self _canVerticalScroll]) {
        return;
    }
    _scrollsToTopAnimationCallback = completion;
    _isDragging = false;
    _isTracking = false;
    
    const auto currentOffset = _contentOffset.y;
    const auto distance = currentOffset - self.minimumContentOffset.y;
    if (distance > 0) {
        const auto properties = [self _scrollPropertiesForAxis:UIAxisVertical];
        properties->is_decelerating = false;
        // Adjusts the startup velocity according to the current position.
        const auto velocity = distance / 100;
        properties->prepare_spring_back();
        properties->reset(velocity, currentOffset);
        properties->bounce_edge = _BounceEdge::MIN;
        fl_spring_back_absorb_with_response(properties->spring_back, velocity, -distance, _bounceResponse);
        properties->is_bouncing = true;
        // Prevents the scroll observer from being notified during the scrolls-to-top animation.
        _ignoreScrollObserver = true;
    }
}

- (void)addScrollObserver:(id<FSVScrollViewScrollObserver>)observer {
    [_scrollObservers addObject:observer];
}

#pragma mark - Private Methods

- (BOOL)_canHorizontalScroll FSV_DIRECT {
    return _alwaysBounceHorizontal || _contentSize.width > self.bounds.size.width;
}

- (BOOL)_canVerticalScroll FSV_DIRECT {
    return _alwaysBounceVertical || _contentSize.height > self.bounds.size.height;
}

- (void)_notifyScrollObservers FSV_DIRECT {
    auto enumerator = [_scrollObservers objectEnumerator];
    id<FSVScrollViewScrollObserver> observer;
    while (observer = [enumerator nextObject]) {
        if ([observer respondsToSelector:@selector(observeScrollViewDidScroll:)]) {
            [observer observeScrollViewDidScroll:self];
        }
    }
}

- (CGFloat)_overflowOffsetForAxis:(UIAxis)axis FSV_DIRECT {
    if (![self _canScrollForAxis:axis]) {
        return 0;
    }
    const auto offset = [self _offsetForAxis:axis];
    const auto minOffset = [self _minimumOffsetForAxis:axis];
    const auto maxOffset = [self _maximumOffsetForAxis:axis];
    if (offset < minOffset) {
        // The offset is less than the minimum offset.
        // The value is negative.
        return offset - minOffset;
    } else if (offset > maxOffset) {
        // The offset is greater than the maximum offset.
        // The value is positive.
        return offset - maxOffset;
    } else {
        // The offset is within the range of the minimum and maximum offsets.
        return 0;
    }
}

- (std::shared_ptr<_ScrollProperties>)_scrollPropertiesForAxis:(UIAxis)axis FSV_DIRECT {
    AXIS_HANDLER(_propertiesX, _propertiesY, nullptr);
}

- (CGFloat)_offsetForAxis:(UIAxis)axis FSV_DIRECT {
    AXIS_HANDLER(_contentOffset.x, _contentOffset.y, 0);
}

- (CGFloat)_minimumOffsetForAxis:(UIAxis)axis FSV_DIRECT {
    const auto min = [self minimumContentOffset];
    AXIS_HANDLER(min.x, min.y, 0);
}

- (CGFloat)_maximumOffsetForAxis:(UIAxis)axis FSV_DIRECT {
    const auto max = [self maximumContentOffset];
    AXIS_HANDLER(max.x, max.y, 0);
}

- (bool)_canScrollForAxis:(UIAxis)axis FSV_DIRECT {
    AXIS_HANDLER([self _canHorizontalScroll], [self _canVerticalScroll], false);
}

- (void)_setNeedsLayoutWithNotify FSV_DIRECT {
    [self setNeedsLayout];
    if (!_ignoreScrollObserver) {
        [self _notifyScrollObservers];
    }
}

- (void)_fitContentOffsetToContentSizeIfNeeded FSV_DIRECT {
    if (self.isDecelerating) {
        // During the animation, since the latest value is taken for each frame.
        // There is no need for additional adjustments.
        _isCachedMinMaxContentOffsetInvalid = true;
        return;
    }
    // At this time, the data obtained is still cached.
    auto min = self.minimumContentOffset;
    const auto distance = CGPointSub(_contentOffset, min);
    _isCachedMinMaxContentOffsetInvalid = true;
    min = self.minimumContentOffset;
    auto target = CGPointAdd(min, distance);
    target = CGPointClamp(target, min, self.maximumContentOffset);
    if (![self _canHorizontalScroll]) {
        target.x = 0;
    }
    if (![self _canVerticalScroll]) {
        target.y = 0;
    }
    self.contentOffset = target;
}

#pragma mark - Getters & Setters

- (void)setFrame:(CGRect)frame {
    bool needFitting = !CGSizeEqualToSize(frame.size, self.bounds.size);
    [super setFrame:frame];
    if (needFitting) {
        // When the view size changes, it will also cause a change in the boundary of the content offset.
        [self _fitContentOffsetToContentSizeIfNeeded];
    }
}

- (void)setContentOffset:(CGPoint)contentOffset {
    if (CGPointEqualToPoint(_contentOffset, contentOffset)) {
        return;
    }
    _contentOffset = contentOffset;
    [self setNeedsLayout];
}

- (void)setContentSize:(CGSize)contentSize {
    if (CGSizeEqualToSize(_contentSize, contentSize)) {
        return;
    }
    _contentSize = contentSize;
    [self _fitContentOffsetToContentSizeIfNeeded];
    [self setNeedsLayout];
}

- (void)setContentInsets:(UIEdgeInsets)contentInsets {
    if (UIEdgeInsetsEqualToEdgeInsets(_contentInsets, contentInsets)) {
        return;
    }
    _contentInsets = contentInsets;
    [self _fitContentOffsetToContentSizeIfNeeded];
    [self setNeedsLayout];
}

- (void)setDecelerationRate:(UIScrollViewDecelerationRate)decelerationRate {
    if (decelerationRate <= 0 || decelerationRate >= 1) {
        _decelerationRate = UIScrollViewDecelerationRateNormal;
    } else {
        _decelerationRate = decelerationRate;
    }
}

- (void)setBounceResponse:(CGFloat)bounceResponse {
    _bounceResponse = bounceResponse <= 0 ? 0.575 : bounceResponse;
}

- (UIEdgeInsets)adjustedContentInset {
    return UIEdgeInsetsAdd(_contentInsets, self.safeAreaInsets);
}

- (BOOL)isTracking {
    return _isTracking;
}

- (BOOL)isDragging {
    return _isDragging;
}

- (BOOL)isDecelerating {
    __block bool result = false;
    enumerate_axes(^(UIAxis axis) {
        GET_AXIS_PROPERTIES;
        result |= properties->is_decelerating || properties->is_bouncing;
    });
    return result;
}

- (CGPoint)minimumContentOffset {
    if (_isCachedMinMaxContentOffsetInvalid) {
        [self _updateCachedMinMaxContentOffset];
        _isCachedMinMaxContentOffsetInvalid = false;
    }
    return _cachedMinimumContentOffset;
}

- (CGPoint)maximumContentOffset {
    if (_isCachedMinMaxContentOffsetInvalid) {
        [self _updateCachedMinMaxContentOffset];
        _isCachedMinMaxContentOffsetInvalid = false;
    }
    return _cachedMaximumContentOffset;
}

- (void)_updateCachedMinMaxContentOffset FSV_DIRECT {
    const auto contentSize = _contentSize;
    const auto viewSize = self.bounds.size;
    const auto adjustedContentInset = self.adjustedContentInset;
    _cachedMinimumContentOffset = CGPointMake(-adjustedContentInset.left, -adjustedContentInset.top);
    _cachedMaximumContentOffset = CGPointMake(
        contentSize.width - viewSize.width + adjustedContentInset.right,
        contentSize.height - viewSize.height + adjustedContentInset.bottom
    );
}

@end
