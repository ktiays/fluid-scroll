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

use std::{
    cell::{Cell, RefCell},
    rc::Rc,
};

use fluid_scroll::{rubber_band, Scroller, SpringBack, VelocityTracker};
use num::Zero;
use web_sys::{Element, MouseEvent, TouchEvent};

use crate::{
    animate::{device_pixel_ratio, Animatable, AnimationContext, Animator},
    closure,
    event_adpater::*,
    point::Point,
};

fn performance_now() -> f64 {
    web_sys::window()
        .and_then(|w| w.performance())
        .map(|p| p.now())
        .unwrap_or(0.0)
}

#[derive(Debug)]
pub struct ListControl {
    inner: Rc<ListControlInner>,
}

#[derive(Debug, PartialEq, Eq)]
enum ListAnimationType {
    None,
    Decelerate,
    SpringBack,
}

impl Default for ListAnimationType {
    fn default() -> Self {
        Self::None
    }
}

#[derive(Debug, Default)]
struct ListAnimationState {
    type_: ListAnimationType,

    last_offset: f32,
    began_time: Option<f64>,
    // Used for calculating scrolling inertia.
    began_offset: f32,
    // Used for spring back effect.
    spring_target: f32,

    scroller: Scroller,
    spring_back: SpringBack,
}

#[derive(Debug)]
pub struct ListControlInner {
    element: Element,

    touch_adapter: RefCell<EventAdapter>,
    touch_began_time: Cell<f64>,
    velocity_tracker_x: RefCell<VelocityTracker>,
    velocity_tracker_y: RefCell<VelocityTracker>,

    animator: Rc<Animator>,
    animation_state: RefCell<ListAnimationState>,

    content_offset: Cell<f32>,
}

impl ListControl {
    pub fn new(element: Element) -> ListControl {
        let inner = Rc::new(ListControlInner {
            element,
            touch_adapter: RefCell::new(EventAdapter::new()),
            touch_began_time: Cell::new(0.0),
            velocity_tracker_x: RefCell::new(VelocityTracker::new()),
            velocity_tracker_y: RefCell::new(VelocityTracker::new()),
            animation_state: RefCell::new(ListAnimationState::default()),
            animator: Animator::new(),
            content_offset: Cell::new(0.0),
        });
        inner.touch_adapter.borrow_mut().set_delegate(&inner);
        let this = ListControl { inner };
        this.prepare_event_listeners();
        this
    }
}

impl ListControl {
    fn prepare_event_listeners(&self) {
        self.add_event_listener("mousedown", |inner, event: MouseEvent| {
            let mut adapter = inner.touch_adapter.borrow_mut();
            adapter.send_mouse_down(event);
        });
        self.add_event_listener("mousemove", |inner, event: MouseEvent| {
            let adapter = inner.touch_adapter.borrow_mut();
            adapter.send_mouse_move(event);
        });
        self.add_event_listener("mouseup", |inner, event: MouseEvent| {
            let mut adapter = inner.touch_adapter.borrow_mut();
            adapter.send_mouse_up(event);
        });
        self.add_event_listener("mouseleave", |inner, event: MouseEvent| {
            let mut adapter = inner.touch_adapter.borrow_mut();
            adapter.send_mouse_leave(event);
        });

        self.add_event_listener("touchstart", |inner, event: TouchEvent| {
            let mut adapter = inner.touch_adapter.borrow_mut();
            adapter.send_touch_start(event);
        });
        self.add_event_listener("touchmove", |inner, event: TouchEvent| {
            let adapter = inner.touch_adapter.borrow_mut();
            adapter.send_touch_move(event);
        });
        self.add_event_listener("touchend", |inner, event: TouchEvent| {
            let mut adapter = inner.touch_adapter.borrow_mut();
            adapter.send_touch_end(event);
        });
        self.add_event_listener("touchcancel", |inner, event: TouchEvent| {
            let mut adapter = inner.touch_adapter.borrow_mut();
            adapter.send_touch_cancel(event);
        });
    }

    fn add_event_listener<F, Arg>(&self, event_name: &'static str, mut callback: F)
    where
        F: FnMut(Rc<ListControlInner>, Arg) + 'static,
        Arg: wasm_bindgen::convert::FromWasmAbi + 'static,
    {
        let inner_cloned = self.inner.clone();
        let Some(parent) = self.inner.element.parent_element() else {
            web_sys::console::error_1(
                &format!("No parent element for {:?}", self.inner.element).into(),
            );
            return;
        };
        parent
            .add_event_listener_with_callback(
                event_name,
                &closure!(|arg: Arg| {
                    callback(inner_cloned.clone(), arg);
                })
                .into_js_value()
                .into(),
            )
            .unwrap();
    }
}

impl EventAdapterDelegate for ListControlInner {
    fn handle_touch_event(self: Rc<Self>, sender: EventSender) {
        let state = sender.state;
        let now = performance_now();
        let point = sender.position;
        let mut velocity_tracker_x = self.velocity_tracker_x.borrow_mut();
        let mut velocity_tracker_y = self.velocity_tracker_y.borrow_mut();
        let mut animation_state = self.animation_state.borrow_mut();
        match state {
            TouchState::Began => {
                velocity_tracker_x.reset();
                velocity_tracker_y.reset();

                self.touch_began_time.set(now);
                animation_state.type_ = ListAnimationType::None;
                animation_state.last_offset =
                    self.rubber_band_for_offset(self.content_offset.get(), true);
                animation_state.scroller.reset();
                animation_state.began_time = None;
            }
            TouchState::Changed => {
                let began_time = self.touch_began_time.get();
                let elapsed = now - began_time;
                velocity_tracker_x.add_data_point(elapsed as f32, point.x as f32);
                velocity_tracker_y.add_data_point(elapsed as f32, point.y as f32);
                let translation = sender.translation;
                let offset = animation_state.last_offset - translation.y as f32;
                self.set_content_offset(self.rubber_band_for_offset(offset, false));
            }
            TouchState::Ended | TouchState::Cancelled => {
                let mut velocity = -Point::new(
                    velocity_tracker_x.calculate(),
                    velocity_tracker_y.calculate(),
                );
                if VelocityTracker::approaching_halt(velocity.x, velocity.y) {
                    velocity = Point::zero();
                }

                let overflow = self.overflow_offset();
                if overflow != 0.0 {
                    // When released, the content offset has exceeded the boundary.
                    let overflow_velocity = -overflow / 100.0;
                    // If two velocities are in opposite directions, add the two velocities.
                    if overflow_velocity.is_sign_negative() != velocity.y.is_sign_negative() {
                        velocity.y += overflow_velocity;
                    } else {
                        velocity.y = overflow_velocity;
                    }
                    drop(animation_state);
                    self.prepare_spring_back_with_velocity(None, velocity.y);
                } else if velocity != Point::zero() {
                    animation_state.scroller.fling(velocity.y);
                    animation_state.type_ = ListAnimationType::Decelerate;
                } else {
                    // No velocity, no spring back, no decelerate.
                    animation_state.type_ = ListAnimationType::None;
                    return;
                }
                self.animator.animate(self.clone());
            }
        }
    }
}

impl ListControlInner {
    fn set_content_offset(&self, offset: f32) {
        self.content_offset.set(offset);
        let element = &self.element;
        element.set_scroll_top((offset as f64 * device_pixel_ratio()) as i32);

        let overflow = self.overflow_offset();
        self.transform_element(-overflow);
    }

    fn content_height(&self) -> f32 {
        let element = &self.element;
        let scroll_height = element.scroll_height() as f32;
        scroll_height / device_pixel_ratio() as f32
    }

    fn transform_element(&self, offset: f32) {
        let element = &self.element;
        let transform = format!(
            "transform: translateY({}px)",
            (offset as f64 * device_pixel_ratio()) as i32
        );
        element.set_attribute("style", &transform).unwrap();
    }

    fn element_height(&self) -> f32 {
        self.element.client_height() as f32 / (device_pixel_ratio() as f32)
    }

    fn min_offset(&self) -> f32 {
        0.0
    }

    fn max_offset(&self) -> f32 {
        self.content_height() - self.element_height()
    }

    fn overflow_offset(&self) -> f32 {
        let content_offset = self.content_offset.get();
        let min = self.min_offset();
        let max = self.max_offset();
        if content_offset < min {
            content_offset - min
        } else if content_offset > max {
            content_offset - max
        } else {
            0.0
        }
    }

    fn prepare_spring_back_with_velocity(&self, now: Option<f64>, velocity: f32) {
        let mut animation_state = self.animation_state.borrow_mut();
        let overflow = self.overflow_offset();
        if overflow != 0.0 {
            if overflow < 0.0 {
                animation_state.spring_target = self.min_offset();
            } else {
                animation_state.spring_target = self.max_offset();
            }
            animation_state.spring_back.reset();
            animation_state.began_time = now;
            animation_state.type_ = ListAnimationType::SpringBack;
            animation_state.spring_back.absorb(velocity, overflow);
        }
    }

    fn rubber_band_for_offset(&self, offset: f32, inv: bool) -> f32 {
        let range = self.element_height();
        if range.abs() < std::f32::EPSILON {
            return offset;
        }

        let min = self.min_offset();
        let max = self.max_offset().max(min);

        if min <= offset && offset <= max {
            return offset;
        }

        let target = if offset < min { min } else { max };
        let distance = offset - target;
        let transformed = if inv {
            rubber_band::calculate_offset_inv(distance.abs(), range)
        } else {
            rubber_band::calculate_offset(distance.abs(), range)
        };

        target + transformed * distance.signum()
    }
}

impl Animatable for ListControlInner {
    fn animate(&self, context: &AnimationContext) {
        let now = context.timestamp;
        let mut animation_state = self.animation_state.borrow_mut();
        let elapsed = (now
            - animation_state.began_time.unwrap_or_else(|| {
                animation_state.began_time = Some(now);
                animation_state.began_offset = self.content_offset.get();
                now
            })) as f32;
        match animation_state.type_ {
            ListAnimationType::Decelerate => {
                if let Some(value) = animation_state.scroller.value(elapsed) {
                    let offset = value.offset;
                    let velocity = value.velocity;
                    self.set_content_offset(offset + animation_state.began_offset);

                    // When scrolling to the edge, if there is still unused velocity, a spring back will occur.
                    drop(animation_state);
                    self.prepare_spring_back_with_velocity(Some(now), velocity);
                } else {
                    animation_state.type_ = ListAnimationType::None;
                    animation_state.began_time = None;
                }
            }
            ListAnimationType::SpringBack => {
                if let Some(value) = animation_state.spring_back.value(elapsed) {
                    self.set_content_offset(value + animation_state.spring_target);
                } else {
                    animation_state.type_ = ListAnimationType::None;
                    animation_state.began_time = None;
                }
            }
            _ => {}
        }
    }
}
