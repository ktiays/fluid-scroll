#![no_std]

pub mod velocity_tracker;

#[cfg(test)]
mod tests {
    use std::println;

    extern crate std;

    use crate::velocity_tracker::*;

    #[test]
    fn it_works() {
        let mut velocity_tracker = VelocityTracker::new();
        velocity_tracker.add_data_point(0f32, 0f32);
        velocity_tracker.add_data_point(10f32, 20f32);
        velocity_tracker.add_data_point(20f32, 30f32);
        velocity_tracker.add_data_point(30f32, 40f32);
        let velocity = velocity_tracker.calculate();
        println!("velocity: {}", velocity);
    }
}
