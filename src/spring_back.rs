use std::f32::consts::PI;

const VALUE_THRESHOLD: f32 = 4e-3;
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
        self.c2 = velocity + self.lambda * distance;
    }

    pub fn value(&mut self, time: f32) -> Option<f32> {
        if time.abs() < f32::EPSILON {
            return Some(0_f32);
        }

        let offset = (self.c1 + self.c2 * time) * (-self.lambda * time).exp();
        if offset.abs() < VALUE_THRESHOLD {
            return None;
        }
        Some(offset)
    }

    pub fn reset(&mut self) {
        *self = Self::default();
    }
}
