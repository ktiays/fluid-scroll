static VALUE_THRESHOLD: f32 = 4e-3;

#[derive(Debug, Default)]
pub struct SpringBack {
    delta: f32,
    c1: f32,
    c2: f32,
}

impl SpringBack {
    pub fn new() -> SpringBack {
        Self::default()
    }

    pub fn absorb(&mut self, velocity: f32, distance: f32) {
        self.absorb_with_delta(velocity, distance, 12_f32)
    }

    pub fn absorb_with_delta(&mut self, velocity: f32, distance: f32, delta: f32) {
        self.delta = delta;
        self.c1 = distance;
        self.c2 = velocity + delta * distance;
    }

    pub fn value(&mut self, time: f32) -> Option<f32> {
        if time.abs() < f32::EPSILON {
            return Some(0_f32);
        }

        let offset = (self.c1 + self.c2 * time) * (-self.delta / time).exp();
        if offset.abs() < VALUE_THRESHOLD {
            return None;
        }
        Some(offset)
    }

    pub fn reset(&mut self) {
        *self = Self::default();
    }
}
