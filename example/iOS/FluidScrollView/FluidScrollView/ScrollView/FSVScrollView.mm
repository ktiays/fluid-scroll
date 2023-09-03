//
//  Created by ktiays on 2023/9/3.
//  Copyright (c) 2023 ktiays. All rights reserved.
// 

#import "FSVScrollView.h"
#import "fluid_scroll.h"

#import "NSSet+Sequence.h"

@implementation FSVScrollView {
    CADisplayLink *_displayLink;
    
    FlVelocityTracker *_velocityTrackerX;
    FlVelocityTracker *_velocityTrackerY;
    
    CGFloat _touchBeganTime;
    UITouch *_activeTouch;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _velocityTrackerX = fl_velocity_tracker_new_default();
        _velocityTrackerY = fl_velocity_tracker_new_default();
    }
    return self;
}

- (void)dealloc {
    fl_velocity_tracker_free(_velocityTrackerX);
    fl_velocity_tracker_free(_velocityTrackerY);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    const auto size = self.bounds.size;
    self.bounds = CGRectMake(-_contentOffset.x, -_contentOffset.y, size.width, size.height);
}

#pragma mark - Touches

#define TOUCH_ASSERT() NSAssert([touches containsObject:_activeTouch], @"There should be a currently active touch in `touches`.")
#define TOUCH_ADD_LOCATION(now) \
    const auto location = [_activeTouch locationInView:self.window]; \
    const auto interval = (now - _touchBeganTime) * 1e3; \
    NSLog(@"%lf: (%lf, %lf)", interval, location.x, location.y); \
    fl_velocity_tracker_add_data_point(_velocityTrackerX, interval, location.x); \
    fl_velocity_tracker_add_data_point(_velocityTrackerY, interval, location.y); \

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    const auto now = CACurrentMediaTime();
    if (!_activeTouch) {
        _activeTouch = [touches firstObject];
        _touchBeganTime = now;
        [self resetVelocityTracker];
    }
    TOUCH_ADD_LOCATION(now);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    TOUCH_ASSERT();
    TOUCH_ADD_LOCATION(CACurrentMediaTime());
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    [self _handleTouchesEndedOrCancelled:touches];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    [self _handleTouchesEndedOrCancelled:touches];
}

- (void)_handleTouchesEndedOrCancelled:(NSSet<UITouch *> *)touches {
    TOUCH_ASSERT();
    TOUCH_ADD_LOCATION(CACurrentMediaTime());
    const auto velocityX = fl_velocity_tracker_calculate_velocity(_velocityTrackerX);
    const auto velocityY = fl_velocity_tracker_calculate_velocity(_velocityTrackerY);
    if (fl_velocity_approaching_halt((float) velocityX, (float) velocityY)) {
        [self _handleEndPanWithVelocity:CGPointZero];
    } else {
        [self _handleEndPanWithVelocity:CGPointMake(velocityX, velocityY)];
    }
    _activeTouch = nil;
}

- (void)resetVelocityTracker {
    fl_velocity_tracker_reset(_velocityTrackerX);
    fl_velocity_tracker_reset(_velocityTrackerY);
}

#pragma mark - Actions

- (void)_handleEndPanWithVelocity:(CGPoint)velocity {
    NSLog(@"velocity: %@", @(velocity));
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

@end
