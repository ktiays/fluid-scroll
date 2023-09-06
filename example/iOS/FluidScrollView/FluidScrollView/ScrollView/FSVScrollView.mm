//
//  Created by ktiays on 2023/9/3.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

#import <iostream>
#import <memory>
#import <optional>
#import <cassert>

#import "FSVScrollView.h"
#import "fluid_scroll.h"

#import "NSSet+Sequence.h"
#import "CGPointMath.h"
#import "UIEdgeInsetsMath.h"

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

@interface FSVScrollView () <_FSVTouchDelegate>

@end

@implementation FSVScrollView {
    CADisplayLink *_displayLink;
    NSHashTable *_scrollObservers;
    bool _isFirstLayout;
    
    FlScroller *_scrollerX;
    FlScroller *_scrollerY;
    FlSpringBack *_springBackX;
    FlSpringBack *_springBackY;
    
    std::unique_ptr<TouchProxy> _touchProxy;
    // Records the translation of the gesture's first response.
    std::optional<CGPoint> _touchBeganTranslation;
    BOOL _isTracking;
    BOOL _isDragging;
    bool _isDecelerating;
    bool _isBouncing;
    _BounceEdge _bounceEdgeX;
    _BounceEdge _bounceEdgeY;
    
    CGPoint _lastContentOffset;
    CGFloat _animationBeginTime;
    CGPoint _animationBeginContentOffset;
    CGPoint _animationBeginVelocity;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _isFirstLayout = true;
        _scrollerX = nullptr;
        _scrollerY = nullptr;
        _springBackX = nullptr;
        _scrollerY = nullptr;
        _bounceEdgeX = _BounceEdge::NONE;
        _bounceEdgeY = _BounceEdge::NONE;
        _scrollObservers = [NSHashTable weakObjectsHashTable];
        _decelerationRate = UIScrollViewDecelerationRateNormal;
    }
    return self;
}

- (void)dealloc {
    safeDelete(_scrollerX);
    safeDelete(_scrollerY);
    safeDelete(_springBackX);
    safeDelete(_springBackY);
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
            _isDecelerating = false;
            _isBouncing = false;
            _bounceEdgeX = _BounceEdge::NONE;
            _bounceEdgeY = _BounceEdge::NONE;
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

- (void)_handleEndPanWithVelocity:(CGPoint)velocity {
    if (CGPointEqualToPoint(velocity, CGPointZero)) {
        return;
    }
    
    [self _updateAnimationPropertiesWithVelocity:velocity];
    
    [self _prepareScrollers];
    [self _updateScrollersDecelerationRate];
    _isDecelerating = true;
}

- (void)_handleDisplayLinkFire:(CADisplayLink *)sender {
    if (_isDecelerating) {
        CGPoint velocity;
        _isDecelerating = ![self _handleDeceleratingWithInterval:(CACurrentMediaTime() - _animationBeginTime) * 1e3 finalVelocity:&velocity];
        
        const auto canHorizontalScroll = [self _canHorizontalScroll];
        const auto canVerticalScroll = [self _canVerticalScroll];
        const auto contentOffset = _contentOffset;
        const auto minContentOffset = self.minimumContentOffset;
        const auto maxContentOffset = self.maximumContentOffset;
        CGPoint targetOffset = CGPointZero;
        if (canHorizontalScroll && contentOffset.x < minContentOffset.x) {
            _bounceEdgeX = _BounceEdge::MIN;
            targetOffset.x = minContentOffset.x;
        }
        if (canHorizontalScroll && contentOffset.x > maxContentOffset.x) {
            _bounceEdgeX = _BounceEdge::MAX;
            targetOffset.x = maxContentOffset.x;
        }
        if (canVerticalScroll && contentOffset.y < minContentOffset.y) {
            _bounceEdgeY = _BounceEdge::MIN;
            targetOffset.y = minContentOffset.y;
        }
        if (canVerticalScroll && contentOffset.y > maxContentOffset.y) {
            _bounceEdgeY = _BounceEdge::MAX;
            targetOffset.y = maxContentOffset.y;
        }
        const auto outOfRange = (_bounceEdgeX != _BounceEdge::NONE || _bounceEdgeY != _BounceEdge::NONE);
        if (_isDecelerating && outOfRange) {
            _isDecelerating = false;
            _isBouncing = true;
            [self _updateAnimationPropertiesWithVelocity:velocity];
            [self _prepareSpringBacks];
            if (_bounceEdgeX != _BounceEdge::NONE) 
                fl_spring_back_absorb(_springBackX, velocity.x, targetOffset.x - contentOffset.x);
            if (_bounceEdgeY != _BounceEdge::NONE)
                fl_spring_back_absorb(_springBackY, velocity.y, targetOffset.y - contentOffset.y);
        }
    }
    if (_isBouncing) {
        _isBouncing = ![self _handleBouncingWithInterval:(CACurrentMediaTime() - _animationBeginTime) * 1e3];
    }
}

- (bool)_handleDeceleratingWithInterval:(CFTimeInterval)interval finalVelocity:(CGPoint *)velocityPointer {
    bool finishX, finishY;
    auto targetContentOffset = _contentOffset;
    CGFloat finalVelocityX = 0;
    CGFloat finalVelocityY = 0;
    const auto valueX = fl_scroller_value(_scrollerX, (float) interval, &finishX);
    if (!finishX) {
        const auto offsetX = valueX.offset;
        finalVelocityX = valueX.velocity;
        targetContentOffset.x = _animationBeginContentOffset.x - offsetX;
    }
    const auto valueY = fl_scroller_value(_scrollerY, (float) interval, &finishY);
    if (!finishY) {
        const auto offsetY = valueY.offset;
        finalVelocityY = valueY.velocity;
        targetContentOffset.y = _animationBeginContentOffset.y - offsetY;
    }
    if (velocityPointer != nullptr) {
        *velocityPointer = CGPointMake(finalVelocityX, finalVelocityY);
    }
    self.contentOffset = targetContentOffset;
    return finishX && finishY;
}

- (bool)_handleBouncingWithInterval:(CFTimeInterval)interval {
    const auto minContentOffset = self.minimumContentOffset;
    const auto maxContentOffset = self.maximumContentOffset;
    CGPoint targetContentOffset = _contentOffset;
    bool finishX = true;
    bool finishY = true;
    if (_bounceEdgeX != _BounceEdge::NONE) {
        const auto target = _bounceEdgeX == _BounceEdge::MIN ? minContentOffset.x : maxContentOffset.x;
        const auto offset = fl_spring_back_value(_springBackX, interval, &finishX);
        targetContentOffset.x = target - offset;
    }
    if (_bounceEdgeY != _BounceEdge::NONE) {
        const auto target = _bounceEdgeY == _BounceEdge::MIN ? minContentOffset.y : maxContentOffset.y;
        const auto offset = fl_spring_back_value(_springBackY, interval, &finishY);
        targetContentOffset.y = target - offset;
    }
    self.contentOffset = targetContentOffset;
    return finishX && finishY;
}

- (CGFloat)_rubberBandForOffset:(CGFloat)offset minOffset:(CGFloat)minOffset maxOffset:(CGFloat)maxOffset range:(CGFloat)range inverse:(bool)inverse {
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

#pragma mark - Public Methods

- (void)scrollToTop {
    if (![self _canVerticalScroll]) {
        return;
    }
}

- (void)addScrollObserver:(id<FSVScrollViewScrollObserver>)observer {
    [_scrollObservers addObject:observer];
}

#pragma mark - Private Methods

- (void)_prepareScrollers {
    const auto vx = _animationBeginVelocity.x;
    const auto vy = _animationBeginVelocity.y;
    if (_scrollerX == nullptr) {
        _scrollerX = new FlScroller;
        fl_scroller_init(_scrollerX, (float) _decelerationRate);
    }
    fl_scroller_reset(_scrollerX);
    fl_scroller_fling(_scrollerX, vx);
    if (_scrollerY == nullptr) {
        _scrollerY = new FlScroller;
        fl_scroller_init(_scrollerY, (float) _decelerationRate);
    }
    fl_scroller_reset(_scrollerY);
    fl_scroller_fling(_scrollerY, vy);
}

- (void)_updateScrollersDecelerationRate {
    if (_scrollerX != nullptr) {
        fl_scroller_set_deceleration_rate(_scrollerX, (float) _decelerationRate);
    }
    if (_scrollerY != nullptr) {
        fl_scroller_set_deceleration_rate(_scrollerY, (float) _decelerationRate);
    }
}

- (BOOL)_canHorizontalScroll {
    return _alwaysBounceHorizontal || _contentSize.width > self.bounds.size.width;
}

- (BOOL)_canVerticalScroll {
    return _alwaysBounceVertical || _contentSize.height > self.bounds.size.height;
}

- (void)_notifyScrollObservers {
    auto enumerator = [_scrollObservers objectEnumerator];
    id<FSVScrollViewScrollObserver> observer;
    while (observer = [enumerator nextObject]) {
        if ([observer respondsToSelector:@selector(observeScrollViewDidScroll:)]) {
            [observer observeScrollViewDidScroll:self];
        }
    }
}

- (BOOL)_outOfRange {
    const auto contentOffset = _contentOffset;
    const auto minContentOffset = self.minimumContentOffset;
    const auto maxContentOffset = self.maximumContentOffset;
    const auto outOfRangeX = (contentOffset.x < minContentOffset.x || contentOffset.x > maxContentOffset.x) && [self _canHorizontalScroll];
    const auto outOfRangeY = (contentOffset.y < minContentOffset.y || contentOffset.y > maxContentOffset.y) && [self _canVerticalScroll];
    return outOfRangeX || outOfRangeY;
}

- (void)_updateAnimationPropertiesWithVelocity:(CGPoint)velocity {
    _animationBeginVelocity = velocity;
    _animationBeginContentOffset = _contentOffset;
    _animationBeginTime = CACurrentMediaTime();
}

- (void)_prepareSpringBacks {
    if (_springBackX == nullptr) {
        _springBackX = new FlSpringBack;
        fl_spring_back_init(_springBackX);
    }
    fl_spring_back_reset(_springBackX);
    if (_springBackY == nullptr) {
        _springBackY = new FlSpringBack;
        fl_spring_back_init(_springBackY);
    }
    fl_spring_back_reset(_springBackY);
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
}

- (void)setContentInsets:(UIEdgeInsets)contentInsets {
    _contentInsets = contentInsets;
    [self setNeedsLayout];
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
    return _isDecelerating || _isBouncing;
}

- (CGPoint)minimumContentOffset {
    const auto adjustedContentInset = self.adjustedContentInset;
    return CGPointMake(-adjustedContentInset.left, -adjustedContentInset.top);
}

- (CGPoint)maximumContentOffset {
    const auto contentSize = _contentSize;
    const auto viewSize = self.bounds.size;
    const auto adjustedContentInset = self.adjustedContentInset;
    return CGPointMake(
        contentSize.width - viewSize.width + adjustedContentInset.right,
        contentSize.height - viewSize.height + adjustedContentInset.bottom
    );
}

@end
