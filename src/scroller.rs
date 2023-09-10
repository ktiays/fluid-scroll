use std::ops::Deref;

use crate::constants::VELOCITY_THRESHOLD;

/// Deceleration rates for the scroll animation.
///
/// You can create a deceleration rate with the specified raw value.
/// The raw value should be in the range of 0.0 to 1.0 (exclusive).
#[derive(Copy, Clone, Debug, PartialEq)]
pub struct DecelerationRate(pub f32);

impl DecelerationRate {
    /// The default deceleration rate for a scroll animation.
    pub const NORMAL: Self = Self(0.998);
    /// A fast deceleration rate for a scroll animation.
    pub const FAST: Self = Self(0.99);
}

impl Default for DecelerationRate {
    fn default() -> Self {
        Self::NORMAL
    }
}

impl Deref for DecelerationRate {
    type Target = f32;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

#[derive(Debug)]
pub struct Scroller {
    deceleration_rate: DecelerationRate,
    initial_velocity: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct ScrollerValue {
    pub offset: f32,
    pub velocity: f32,
}

impl Scroller {
    pub fn new(deceleration_rate: DecelerationRate) -> Self {
        Self {
            deceleration_rate,
            initial_velocity: 0.0,
        }
    }

    pub fn set_deceleration_rate(&mut self, deceleration_rate: DecelerationRate) {
        self.deceleration_rate = deceleration_rate;
    }

    pub fn fling(&mut self, velocity: f32) {
        self.initial_velocity = velocity;
    }

    pub fn value(&mut self, time: f32) -> Option<ScrollerValue> {
        let rate = *self.deceleration_rate;
        let coefficient = rate.powf(time);
        let velocity = self.initial_velocity * coefficient;
        let offset = self.initial_velocity * (1.0 / rate.ln()) * (coefficient - 1.0);

        if velocity.abs() < VELOCITY_THRESHOLD {
            return None;
        }

        Some(ScrollerValue { offset, velocity })
    }

    pub fn reset(&mut self) {
        self.initial_velocity = 0.0;
    }
}

impl Default for Scroller {
    fn default() -> Self {
        Self::new(DecelerationRate::NORMAL)
    }
}
