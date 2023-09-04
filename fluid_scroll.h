#ifndef __SCROLL_PHYSICS_H
#define __SCROLL_PHYSICS_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  char padding[16];
} FlScroller;

typedef struct {
  float offset;
  float velocity;
} FlScrollerValue;

void fl_scroller_init(FlScroller *scroller, float deceleration_rate);
void fl_scroller_init_default(FlScroller *scroller);

void fl_scroller_set_deceleration_rate(FlScroller *scroller,
                                       float deceleration_rate);

void fl_scroller_fling(FlScroller *scroller, float velocity);

FlScrollerValue fl_scroller_value(FlScroller *scroller, float time,
                                  bool *out_stop);

void fl_scroller_reset(FlScroller *scroller);

typedef struct {
  char padding[16];
} FlSpringBack;

void fl_spring_back_init(FlSpringBack *spring_back);

void fl_spring_back_absorb(FlSpringBack *spring_back, float velocity,
                           float distance);

void fl_spring_back_absorb_with_response(FlSpringBack *spring_back,
                                         float velocity, float distance,
                                         float response);

float fl_spring_back_value(FlSpringBack *spring_back, float time,
                           bool *out_stop);

void fl_spring_back_reset(FlSpringBack *spring_back);

float fl_calculate_rubber_band_offset(float offset, float range);

typedef struct __FlVelocityTracker FlVelocityTracker;

enum FlVelocityTrackerStrategy {
  FL_VELOCITY_TRACKER_RECURRENCE_STRATEGY = 0,
  FL_VELOCITY_TRACKER_LSQ2_STRATEGY = 1,
};

FlVelocityTracker *fl_velocity_tracker_new(FlVelocityTrackerStrategy strategy);

FlVelocityTracker *fl_velocity_tracker_new_default(void);

void fl_velocity_tracker_free(FlVelocityTracker *velocity_tracker);

void fl_velocity_tracker_add_data_point(FlVelocityTracker *velocity_tracker,
                                        float time, float position);

float fl_velocity_tracker_calculate_velocity(
    FlVelocityTracker *velocity_tracker);

void fl_velocity_tracker_reset(FlVelocityTracker *velocity_tracker);

bool fl_velocity_approaching_halt(float vx, float vy);

#ifdef __cplusplus
}
#endif

#endif // __SCROLL_PHYSICS_H