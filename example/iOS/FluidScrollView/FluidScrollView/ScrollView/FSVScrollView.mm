//
//  Created by ktiays on 2023/9/3.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

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
static void safeDelete(T *ptr) {
    if (ptr != nullptr) {
        delete ptr;
    }
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

static void     enumerate_axes(void (^action)(UIAxis axis)) {
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
        safeDelete(scroller);
        safeDelete(spring_back);
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
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _isFirstLayout = true;
        _scrollObservers = [NSHashTable weakObjectsHashTable];
        _decelerationRate = UIScrollViewDecelerationRateNormal;
        _isCachedMinMaxContentOffsetInvalid = true;
        _propertiesX = std::make_shared<_ScrollProperties>();
        _propertiesY = std::make_shared<_ScrollProperties>();
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
    [super touchesBegan:touches withEvent:event];
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
    [super touchesMoved:touches withEvent:event];
    _touchProxy->move_with_touches(touches);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
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
        fl_spring_back_absorb(properties->spring_back, velocity, targetOffset - [self _offsetForAxis:axis]);
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

- (void)scrollsToTopWithCompletionHandler:(void (^)(void))completionHandler {
    if (![self _canVerticalScroll]) {
        return;
    }
    _scrollsToTopAnimationCallback = completionHandler;
    _isDragging = false;
    _isTracking = false;
    
    const auto currentOffset = _contentOffset.y;
    const auto distance = currentOffset - self.minimumContentOffset.y;
    if (distance > 0) {
        const auto properties = [self _scrollPropertiesForAxis:UIAxisVertical];
        properties->is_decelerating = false;
        const auto velocity = distance / 100;
        properties->prepare_spring_back();
        properties->reset(velocity, currentOffset);
        properties->bounce_edge = _BounceEdge::MIN;
        fl_spring_back_absorb(properties->spring_back, velocity, -distance);
        properties->is_bouncing = true;
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
        return offset - minOffset;
    } else if (offset > maxOffset) {
        return offset - maxOffset;
    } else {
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

#pragma mark - Getters & Setters

- (void)setContentOffset:(CGPoint)contentOffset {
    _contentOffset = contentOffset;
    [self setNeedsLayout];
    [self _notifyScrollObservers];
}

- (void)setContentSize:(CGSize)contentSize {
    _contentSize = contentSize;
    [self setNeedsLayout];
    _isCachedMinMaxContentOffsetInvalid = true;
}

- (void)setContentInsets:(UIEdgeInsets)contentInsets {
    _contentInsets = contentInsets;
    [self setNeedsLayout];
    _isCachedMinMaxContentOffsetInvalid = true;
}

- (void)setDecelerationRate:(UIScrollViewDecelerationRate)decelerationRate {
    if (decelerationRate <= 0 || decelerationRate >= 1) {
        _decelerationRate = UIScrollViewDecelerationRateNormal;
    } else {
        _decelerationRate = decelerationRate;
    }
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
