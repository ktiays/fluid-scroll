// Copyright 2019 The Android Open Source Project
// Copyright 2023 ktiays
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

use alloc::vec::Vec;
use core::{
    cell::RefCell,
    ops::{Index, IndexMut},
};
use std::ops::Deref;

extern crate alloc;

#[derive(Debug, Clone, Copy, Default)]
struct DataPoint {
    pub time: f32,
    pub value: f32,
}

const HISTORY_SIZE: usize = 20;
const HORIZON_MILLISECONDS: f32 = 100_f32;
const ASSUME_POINTER_MOVE_STOPPED_MILLISECONDS: f32 = 40_f32;

#[derive(Debug)]
struct Cache {
    reusable_values: Vector,
    reusable_time: Vector,
}

impl Cache {
    fn new() -> Self {
        Self {
            reusable_values: Vector::with_capacity(HISTORY_SIZE),
            reusable_time: Vector::with_capacity(HISTORY_SIZE),
        }
    }
}

impl Default for Cache {
    fn default() -> Self {
        Self::new()
    }
}

#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Strategy {
    Recurrence = 0,
    Lsq2 = 1,
}

impl Default for Strategy {
    fn default() -> Self {
        Self::Recurrence
    }
}

#[derive(Debug, Default)]
pub struct VelocityTracker {
    strategy: Strategy,
    samples: [Option<DataPoint>; HISTORY_SIZE],
    index: usize,

    cache: RefCell<Cache>,
}

impl VelocityTracker {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn with_strategy(strategy: Strategy) -> Self {
        Self {
            strategy,
            ..Self::default()
        }
    }

    /// Adds a data point for velocity calculation at a given time.
    pub fn add_data_point(&mut self, time_milliseconds: f32, value: f32) {
        let data_point = DataPoint {
            time: time_milliseconds,
            value,
        };
        self.index = (self.index + 1) % HISTORY_SIZE;
        self.samples[self.index] = Some(data_point);
    }

    /// Computes the estimated velocity at the time of the last provided data point.
    pub fn calculate(&self) -> f32 {
        let mut index = self.index;
        let mut sample_count = 0;

        // The sample at index is our newest sample.  If it is null, we have no samples so return.
        let Some(newest) = self.samples[index] else {
            return 0.0;
        };
        let mut previous = newest;

        let mut cache_mut = self.cache.borrow_mut();

        loop {
            let Some(sample) = self.samples[index] else {
                break;
            };

            let age = newest.time - sample.time;
            // Using a recurrence relation for calculation,
            // no sampling point can be discarded.
            if self.strategy != Strategy::Recurrence {
                let delta = (sample.value - previous.value).abs();
                previous = sample;
                if age > HORIZON_MILLISECONDS || delta > ASSUME_POINTER_MOVE_STOPPED_MILLISECONDS {
                    break;
                }
            }

            cache_mut.reusable_values[sample_count] = sample.value;
            cache_mut.reusable_time[sample_count] = -age;
            index = if index == 0 { HISTORY_SIZE } else { index } - 1;

            sample_count += 1;

            if sample_count >= HISTORY_SIZE {
                break;
            }
        }

        if sample_count >= self.min_sample_size() {
            match self.strategy {
                Strategy::Recurrence => calculate_recurrence_relation_velocity(
                    cache_mut
                        .reusable_time
                        .iter()
                        .take(sample_count.min(4))
                        .rev(),
                    cache_mut
                        .reusable_values
                        .iter()
                        .take(sample_count.min(4))
                        .rev(),
                )
                .ok(),

                Strategy::Lsq2 =>
                // The 2nd coefficient is the derivative of the quadratic polynomial at
                // x = 0, and that happens to be the last timestamp that we end up
                // passing to `poly_fit_least_squares`.
                {
                    poly_fit_least_squares(
                        &cache_mut.reusable_time,
                        &cache_mut.reusable_values,
                        sample_count,
                        2,
                        [0_f32; 3],
                    )
                    .ok()
                    .and_then(|r| r.get(1).cloned())
                }
            }
            .unwrap_or_default()
        } else {
            0_f32
        }
    }

    pub fn reset(&mut self) {
        self.samples.fill(None);
        self.index = 0;
    }

    pub fn approaching_halt(horizontal_velocity: f32, vertical_velocity: f32) -> bool {
        horizontal_velocity * horizontal_velocity + vertical_velocity * vertical_velocity
            < 0.0625_f32
    }
}

impl VelocityTracker {
    fn min_sample_size(&self) -> usize {
        match self.strategy {
            Strategy::Recurrence => 2,
            Strategy::Lsq2 => 3,
        }
    }
}

#[derive(Debug, Clone)]
struct Matrix(Vec<Vector>);

impl Matrix {
    pub fn new(rows: usize, columns: usize) -> Self {
        let mut matrix = Vec::with_capacity(rows);
        for _ in 0..rows {
            matrix.push(Vector::with_capacity(columns));
        }
        Self(matrix)
    }
}

impl Index<usize> for Matrix {
    type Output = Vector;

    fn index(&self, index: usize) -> &Self::Output {
        &self.0[index]
    }
}

impl IndexMut<usize> for Matrix {
    fn index_mut(&mut self, index: usize) -> &mut Self::Output {
        &mut self.0[index]
    }
}

#[derive(Debug, Clone, Default)]
struct Vector(Vec<f32>);

impl Vector {
    pub fn with_capacity(capacity: usize) -> Self {
        let mut vector = Vec::with_capacity(capacity);
        vector.resize(capacity, 0_f32);
        Self(vector)
    }

    pub fn dot(&self, other: &Self) -> f32 {
        let mut result = 0_f32;
        for i in 0..self.0.len() {
            result += self.0[i] * other.0[i];
        }
        result
    }

    pub fn norm(&self) -> f32 {
        self.dot(self).sqrt()
    }
}

impl Deref for Vector {
    type Target = Vec<f32>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl Index<usize> for Vector {
    type Output = f32;

    fn index(&self, index: usize) -> &Self::Output {
        &self.0[index]
    }
}

impl IndexMut<usize> for Vector {
    fn index_mut(&mut self, index: usize) -> &mut Self::Output {
        &mut self.0[index]
    }
}

/// Fits a polynomial of the given degree to the data points.
fn poly_fit_least_squares(
    x: &Vector,
    y: &Vector,
    sample_count: usize,
    degree: usize,
    mut coefficients: [f32; 3],
) -> Result<[f32; 3], &'static str> {
    if degree < 1 {
        return Err("The degree must be at positive integer");
    }
    if sample_count == 0 {
        return Err("At least one point must be provided");
    }

    let truncated_degree = if degree >= sample_count {
        sample_count - 1
    } else {
        degree
    };

    let m = sample_count;
    let n = truncated_degree + 1;

    // Expand the X vector to a matrix A, pre-multiplied by the weights.
    let mut a = Matrix::new(n, m);
    for h in 0..m {
        a[0][h] = 1_f32;
        for i in 1..n {
            a[i][h] = a[i - 1][h] * x[h];
        }
    }

    // Apply the Gram-Schmidt process to A to obtain its QR decomposition.

    // Orthonormal basis, column-major order.
    let mut q = Matrix::new(n, m);
    // Upper triangular matrix, row-major order.
    let mut r = Matrix::new(n, n);
    for j in 0..n {
        let aw = &mut a[j];
        for h in 0..m {
            q[j][h] = aw[h];
        }
        for i in 0..j {
            let dot = q[j].dot(&q[i]);
            for h in 0..m {
                q[j][h] -= dot * q[i][h];
            }
        }

        let norm = q[j].norm();
        if norm < 1e-6 {
            return Err("Vectors are linearly dependent or zero so no solution.");
        }

        let inverse_norm = 1_f32 / norm;
        for h in 0..m {
            q[j][h] *= inverse_norm;
        }
        let v = &mut r[j];
        for i in 0..n {
            v[i] = if i < j { 0_f32 } else { q[j].dot(&a[i]) };
        }
    }

    // Solve R B = Qt W Y to find B. This is easy because R is upper triangular.
    // We just work from bottom-right to top-left calculating B's coefficients.
    let wy = y;

    for i in (0..=n - 1).rev() {
        coefficients[i] = q[i].dot(wy);
        for j in (i + 1..=n - 1).rev() {
            coefficients[i] -= r[i][j] * coefficients[j];
        }
        coefficients[i] /= r[i][i];
    }

    Ok(coefficients)
}

fn calculate_recurrence_relation_velocity<'a, T, V>(
    times_iter: T,
    values_iter: V,
) -> Result<f32, &'static str>
where
    T: ExactSizeIterator<Item = &'a f32>,
    V: ExactSizeIterator<Item = &'a f32>,
{
    if times_iter.len() != values_iter.len() {
        return Err("The number of times and values must be equal");
    }

    let sample_count = times_iter.len();
    if sample_count < 2 {
        return Err("At least two points must be provided");
    }

    let points = values_iter.zip(times_iter).collect::<Vec<_>>();
    let samples = points
        .windows(2)
        .filter_map(|window| {
            let delta_time = window[1].1 - window[0].1;
            if delta_time == 0_f32 {
                // The two points are at the same time, so we can't calculate a velocity.
                // Discard this sample.
                None
            } else {
                Some((window[1].0 - window[0].0) / delta_time)
            }
        })
        .collect::<Vec<_>>();

    // Save the velocity values of the last two times.
    let mut previous_velocity = None;
    let mut current_velocity = None;
    samples.windows(2).for_each(|window| {
        let velocity = window[0] * 0.4 + window[1] * 0.6;
        if let Some(current) = current_velocity {
            previous_velocity = Some(current);
            // Weighted average of the velocity with a ratio of 8:2 compared to the previous time.
            current_velocity = Some(current * 0.8 + velocity * 0.2);
        } else {
            current_velocity = Some(velocity);
        }
    });
    let Some(current) = current_velocity else {
        return Ok(*samples
            .first()
            .expect("At least one velocity sampling is required"));
    };
    if let Some(previous) = previous_velocity {
        Ok(previous * 0.75 + current * 0.25)
    } else {
        Ok(current)
    }
}

#[cfg(test)]
mod tests {
    use crate::velocity_tracker::Strategy;

    use super::VelocityTracker;

    #[test]
    fn test_lsq2() {
        let mut velocity_tracker = VelocityTracker::with_strategy(Strategy::Lsq2);
        velocity_tracker.add_data_point(0_f32, 0_f32);
        velocity_tracker.add_data_point(10_f32, 20_f32);
        velocity_tracker.add_data_point(20_f32, 30_f32);
        velocity_tracker.add_data_point(30_f32, 40_f32);
        let velocity = velocity_tracker.calculate();
        assert!((velocity - 0.55).abs() < 0.001)
    }

    #[test]
    fn test_instantaneous() {
        let mut velocity_tracker = VelocityTracker::with_strategy(Strategy::Recurrence);
        velocity_tracker.add_data_point(1.53283_f32, 0_f32);
        velocity_tracker.add_data_point(3.27537_f32, 376_f32);
        velocity_tracker.add_data_point(5.27733_f32, 276_f32);
        velocity_tracker.add_data_point(22.2795_f32, 153.5_f32);
        velocity_tracker.add_data_point(58.22_f32, 151.5_f32);
        let velocity = velocity_tracker.calculate();
        assert!((velocity + 6.678).abs() < 0.001)
    }
}
