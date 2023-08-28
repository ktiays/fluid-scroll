#![no_std]

pub mod edge_effect;
pub mod over_scroller;
pub mod velocity_tracker;

#[cfg(test)]
mod tests {
    use std::println;

    extern crate std;

    use crate::velocity_tracker::*;

    #[test]
    fn it_works() {
        let mut velocity_tracker = VelocityTracker::new();
        velocity_tracker.add_data_point(0_f32, 0_f32);
        velocity_tracker.add_data_point(10_f32, 20_f32);
        velocity_tracker.add_data_point(20_f32, 30_f32);
        velocity_tracker.add_data_point(30_f32, 40_f32);
        let velocity = velocity_tracker.calculate();
        println!("velocity: {}", velocity);
    }
}
