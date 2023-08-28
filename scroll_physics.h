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

#ifdef __cplusplus
}
#endif

#endif // __SCROLL_PHYSICS_H