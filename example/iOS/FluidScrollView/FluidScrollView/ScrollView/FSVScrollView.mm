//
//  Created by ktiays on 2023/9/3.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

#import <iostream>
#import <memory>

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
        : delegate_(view), state_(POSSIBLE) {}
    
    State state() const {
        return state_;
    }
    
    CGPoint translation() const {
        return CGPointAdd(previous_traslation_, CGPointSub(active_touch_location(), active_touch_begin_location_));
    }
    
    CGPoint velocity() const {
        return CGPointZero;
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
            active_touch_begin_location_ = translation();
            
            active_touch_ = touch;
        } else {
            state_ = BEGAN;
            active_touch_ = [touches firstObject];
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
        state_ = cancelled ? CANCELLED : ENDED;
        add_current_location();
        [delegate_ _handlePan:*this];
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
        const auto now = static_cast<float>(CACurrentMediaTime());
        const auto trans = translation();
        fl_velocity_tracker_add_data_point(velocity_tracker_x_, static_cast<float>(now), static_cast<float>(trans.x));
        fl_velocity_tracker_add_data_point(velocity_tracker_y_, static_cast<float>(now), static_cast<float>(trans.y));
    }
};

@interface FSVScrollView () <_FSVTouchDelegate>

@end

@implementation FSVScrollView {
    CADisplayLink *_displayLink;
    NSHashTable *_scrollObservers;
    
    FlScroller *_scrollerX;
    FlScroller *_scrollerY;
    FlSpringBack *_springBackX;
    FlSpringBack *_springBackY;
    
    UIGestureRecognizerState _touchState;
    CGFloat _touchBeganTime;
    UITouch *_activeTouch;
    std::unique_ptr<TouchProxy> _touchProxy;
    BOOL _isTracking;
    BOOL _isDragging;
    
    CGPoint _lastContentOffset;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _scrollObservers = [NSHashTable weakObjectsHashTable];
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
        if (@available(iOS 15.0, *)) {
            _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(60, 120, 120);
        }
        [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    } else {
        [_displayLink invalidate];
        _displayLink = nil;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    const auto size = self.bounds.size;
    self.bounds = CGRectMake(-_contentOffset.x, -_contentOffset.y, size.width, size.height);
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
    switch (proxy.state()) {
        case TouchProxy::State::BEGAN:
            _isTracking = true;
            _lastContentOffset = _contentOffset;
            break;
        case TouchProxy::State::CHANGED: {
            _isTracking = false;
            _isDragging = true;
            const auto translation = proxy.translation();
            std::cout << "(" << translation.x << ", " << translation.y << ")\n";
            self.contentOffset = CGPointSub(_lastContentOffset, translation);
        } break;
        case TouchProxy::State::ENDED:
        case TouchProxy::State::CANCELLED: {
            auto velocity = proxy.velocity();
            if (fl_velocity_approaching_halt(velocity.x, velocity.y)) {
                velocity = CGPointZero;
            }
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
}

- (void)_handleDisplayLinkFire:(CADisplayLink *)sender {
    
}

#pragma mark - Public Methods

- (void)scrollToTop {
    
}

- (void)addScrollObserver:(id<FSVScrollViewScrollObserver>)observer {
    [_scrollObservers addObject:observer];
}

#pragma mark - Private Methods

- (CGPoint)_minimumContentOffset {
    const auto adjustedContentInset = self.adjustedContentInset;
    return CGPointMake(-adjustedContentInset.top, -adjustedContentInset.left);
}

- (CGPoint)_maximumContentOffset {
    const auto contentSize = _contentSize;
    const auto viewSize = self.bounds.size;
    const auto adjustedContentInset = self.adjustedContentInset;
    return CGPointMake(
        contentSize.width - viewSize.width - adjustedContentInset.right,
        contentSize.height - viewSize.height - adjustedContentInset.bottom
    );
}

- (void)_notifyScrollObservers {
    [[_scrollObservers allObjects] enumerateObjectsUsingBlock:^(id<FSVScrollViewScrollObserver> obj, NSUInteger idx, BOOL *stop) {
        if ([obj respondsToSelector:@selector(observeScrollViewDidScroll:)]) {
            [obj observeScrollViewDidScroll:self];
        }
    }];
}

#pragma mark - Getters & Setters

- (void)setContentOffset:(CGPoint)contentOffset {
    _contentOffset = contentOffset;
    [self setNeedsLayout];
}

- (void)setContentSize:(CGSize)contentSize {
    _contentSize = contentSize;
    [self setNeedsLayout];
}

- (void)setContentInsets:(UIEdgeInsets)contentInsets {
    _contentInsets = contentInsets;
    [self setNeedsLayout];
}

- (UIEdgeInsets)adjustedContentInset {
    return UIEdgeInsetsAdd(_contentInsets, self.safeAreaInsets);
}

@end
