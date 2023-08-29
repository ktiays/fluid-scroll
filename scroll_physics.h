#ifndef __SCROLL_PHYSICS_H
#define __SCROLL_PHYSICS_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  char padding[16];
} SpScroller;

typedef struct {
  float offset;
  float velocity;
} SpScrollerValue;

void sp_scroller_init(SpScroller *scroller, float deceleration_rate);
void sp_scroller_init_default(SpScroller *scroller);

void sp_scroller_set_deceleration_rate(SpScroller *scroller,
                                       float deceleration_rate);

void sp_scroller_fling(SpScroller *scroller, float velocity);

SpScrollerValue sp_scroller_value(SpScroller *scroller, float time,
                                  bool *out_stop);

void sp_scroller_reset(SpScroller *scroller);

typedef struct {
  char padding[16];
} SpSpringBack;

void sp_spring_back_init(SpSpringBack *spring_back);

void sp_spring_back_absorb(SpSpringBack *spring_back, float velocity,
                           float distance);

void sp_spring_back_absorb_with_response(SpSpringBack *spring_back,
                                         float velocity, float distance,
                                         float response);

float sp_spring_back_value(SpSpringBack *spring_back, float time,
                           bool *out_stop);

void sp_spring_back_reset(SpSpringBack *spring_back);

#ifdef __cplusplus
}
#endif

#endif // __SCROLL_PHYSICS_H