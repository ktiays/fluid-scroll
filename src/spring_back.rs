use std::f32::consts::PI;

use crate::constants::{VALUE_THRESHOLD, VELOCITY_THRESHOLD};

const DEFAULT_RESPONSE: f32 = 0.575_f32;
const RUBBER_BAND_COEFFICIENT: f32 = 0.55_f32;

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
        self.c2 = velocity + self.lambda * distance;
    }

    pub fn value(&mut self, time: f32) -> Option<f32> {
        let offset = (self.c1 + self.c2 * time) * (-self.lambda * time).exp();

        let velocity = self.velocity_at(time);
        if offset.abs() < VALUE_THRESHOLD && velocity.abs() < VELOCITY_THRESHOLD {
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
    pub fn calculate_rubber_band_offset(offset: f32, range: f32) -> f32 {
        // Check if offset and range are positive.
        if offset < 0_f32 || range < 0_f32 {
            assert!(false);
            return 0_f32;
        }
        (1_f32 - (1_f32 / (offset / range * RUBBER_BAND_COEFFICIENT + 1_f32))) * range
    }
}

impl SpringBack {
    fn velocity_at(&self, time: f32) -> f32 {
        (self.c2 - self.lambda * (self.c1 + self.c2 * time)) * (-self.lambda * time).exp()
    }
}
