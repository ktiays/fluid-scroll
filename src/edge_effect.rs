static VALUE_THRESHOLD: f32 = 4e-3;

#[derive(Debug)]
pub struct EdgeEffect {
    delta: f32,
    c1: f32,
    c2: f32,
    offset: f32,
}

impl EdgeEffect {
    pub fn absorb(&mut self, velocity: f32, distance: f32) {
        self.absorb_with_delta(velocity, distance, 12_f32)
    }

    pub fn absorb_with_delta(&mut self, velocity: f32, distance: f32, delta: f32) {
        self.delta = delta;
        self.c1 = distance;
        self.c2 = velocity + delta * distance;
    }

    pub fn update(&mut self, elapsed: f32) {
        self.offset = (self.c1 + self.c2 * elapsed) * libm::expf(-self.delta / elapsed);
    }

    pub fn is_finished(&self) -> bool {
        libm::fabsf(self.offset) < VALUE_THRESHOLD
    }
}
