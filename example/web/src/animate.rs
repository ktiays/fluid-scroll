// Copyright (C) 2023 ktiays
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
    borrow::BorrowMut,
    cell::{Cell, RefCell},
    rc::{Rc, Weak},
};

use crate::closure_once;

pub fn device_pixel_ratio() -> f64 {
    web_sys::window()
        .expect("no global `window` exists")
        .device_pixel_ratio()
}

pub trait Animatable {
    fn animate(&self, context: &AnimationContext);
}

#[readonly::make]
#[derive(Debug, Default)]
pub struct AnimationContext {
    animator: Weak<Animator>,
    pub timestamp: f64,
}

#[derive(Debug, Default)]
pub struct Animator {
    context: RefCell<AnimationContext>,
    cancelled: Cell<bool>,
    animation_id: Cell<i32>,
}

impl Animator {
    pub fn new() -> Rc<Self> {
        let mut this = Rc::new(Animator::default());
        this.borrow_mut().context.borrow_mut().animator = Rc::downgrade(&this);
        this
    }

    pub fn animate<A>(self: &Rc<Self>, animatable: Rc<A>)
    where
        A: Animatable + 'static,
    {
        let Some(window) = web_sys::window() else {
            return;
        };
        // If the animation is marked as cancelled, we should stop the animation.
        if self.cancelled.get() {
            window
                .cancel_animation_frame(self.animation_id.get())
                .unwrap();
            self.cancelled.set(false);
            return;
        }
        let this = self.clone();
        self.animation_id.set(
            window
                .request_animation_frame(
                    &closure_once!(|timestamp: f64| {
                        let mut context = this.context.borrow_mut();
                        context.timestamp = timestamp;
                        animatable.animate(&context);
                        this.animate(animatable);
                    })
                    .into_js_value()
                    .into(),
                )
                .unwrap(),
        );
    }
}
