#[derive(Copy, Clone, Debug, PartialEq)]
pub struct DecelerationRate(f32);

impl DecelerationRate {
    pub const NORMAL: Self = Self(0.998);
    pub const FAST: Self = Self(0.99);

    fn value(&self) -> f32 {
        self.0
    }
}

static VELOCITY_THRESHOLD: f32 = 1e-2;

#[derive(Debug)]
pub struct OverScroller {
    pub deceleration_rate: DecelerationRate,

    initial_velocity: f32,
    velocity: f32,

    offset: f32,
}

impl OverScroller {
    pub fn fling(&mut self, velocity: f32) {
        self.initial_velocity = velocity;
        self.velocity = velocity;
    }

    pub fn update(&mut self, elapsed: f32) {
        let rate = self.deceleration_rate.value();
        let coefficient = libm::powf(rate, elapsed);
        self.velocity = self.initial_velocity * coefficient;
        self.offset = self.initial_velocity * (1.0 / libm::logf(rate)) * (coefficient - 1.0);
    }

    pub fn is_finished(&self) -> bool {
        libm::fabsf(self.velocity) < VELOCITY_THRESHOLD
    }

    pub fn current_value(&self) -> f32 {
        self.offset
    }

    pub fn reset(&mut self) {
        self.initial_velocity = 0.0;
        self.velocity = 0.0;
        self.offset = 0.0;
    }
}
