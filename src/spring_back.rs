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

use std::f32::consts::PI;

use crate::constants::{VALUE_THRESHOLD, VELOCITY_THRESHOLD};

const DEFAULT_RESPONSE: f32 = 0.575_f32;

#[derive(Debug, Default)]
pub struct SpringBack {
    lambda: f32,
    c1: f32,
    c2: f32,
}

impl SpringBack {
    pub fn new() -> SpringBack {
        Self::default()
    }

    pub fn absorb(&mut self, velocity: f32, distance: f32) {
        self.absorb_with_response(velocity, distance, DEFAULT_RESPONSE)
    }

    pub fn absorb_with_response(&mut self, velocity: f32, distance: f32, response: f32) {
        self.lambda = 2_f32 * PI / response;
        self.c1 = distance;
        // The formula needs to be calculated in units of points per second.
        self.c2 = velocity * 1e3 + self.lambda * distance;
    }

    pub fn value(&self, mut time: f32) -> Option<f32> {
        // Convert time from milliseconds to seconds.
        time /= 1e3;
        let offset = (self.c1 + self.c2 * time) * (-self.lambda * time).exp();

        let velocity = self.velocity_at(time);
        // The velocity threshold is in units of points per millisecond.
        // We need to convert velocity to match the unit.
        if offset.abs() < VALUE_THRESHOLD && velocity.abs() / 1e3 < VELOCITY_THRESHOLD {
            None
        } else {
            Some(offset)
        }
    }

    pub fn reset(&mut self) {
        *self = Self::default();
    }
}

impl SpringBack {
    /// Calculate the velocity at a given time.
    ///
    /// The unit of velocity is points per second.
    fn velocity_at(&self, time: f32) -> f32 {
        (self.c2 - self.lambda * (self.c1 + self.c2 * time)) * (-self.lambda * time).exp()
    }
}
