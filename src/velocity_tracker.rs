use alloc::vec::Vec;
use core::{
    cell::RefCell,
    ops::{Index, IndexMut},
};

extern crate alloc;

#[derive(Debug, Clone, Copy, Default)]
struct DataPoint {
    pub time: f32,
    pub value: f32,
}

static HISTORY_SIZE: usize = 20;
static HORIZON_MILLISECONDS: f32 = 100_f32;
static ASSUME_POINTER_MOVE_STOPPED_MILLISECONDS: f32 = 40_f32;

static MIN_SAMPLE_SIZE: usize = 3;

#[derive(Debug)]
pub struct VelocityTracker {
    samples: Vec<DataPoint>,
    index: usize,

    reusable_values: RefCell<Vector>,
    reusable_time: RefCell<Vector>,
}

impl VelocityTracker {
    pub fn new() -> Self {
        let mut samples = Vec::with_capacity(HISTORY_SIZE);
        samples.resize(HISTORY_SIZE, DataPoint::default());
        Self {
            samples,
            index: 0,
            reusable_values: RefCell::new(Vector::with_capacity(HISTORY_SIZE)),
            reusable_time: RefCell::new(Vector::with_capacity(HISTORY_SIZE)),
        }
    }

    /// Adds a data point for velocity calculation at a given time.
    pub fn add_data_point(&mut self, time_milliseconds: f32, value: f32) {
        let data_point = DataPoint {
            time: time_milliseconds,
            value,
        };
        self.index = (self.index + 1) % HISTORY_SIZE;
        self.samples[self.index] = data_point;
    }

    /// Computes the estimated velocity at the time of the last provided data point.
    pub fn calculate(&self) -> f32 {
        let mut index = self.index;
        let mut sample_count = 0;

        // The sample at index is our newest sample.  If it is null, we have no samples so return.
        let Some(newest) = self.samples.get(index).cloned() else {
            return 0.0;
        };
        let mut previous = newest;

        loop {
            let Some(sample) = self.samples.get(index).cloned() else {
                break;
            };

            let age = newest.time - sample.time;
            let delta = libm::fabsf(sample.value - previous.value);
            previous = sample;
            if age > HORIZON_MILLISECONDS || delta > ASSUME_POINTER_MOVE_STOPPED_MILLISECONDS {
                break;
            }

            self.reusable_values.borrow_mut()[sample_count] = sample.value;
            self.reusable_time.borrow_mut()[sample_count] = -age;
            index = if index == 0 { HISTORY_SIZE } else { index } - 1;

            sample_count += 1;

            if sample_count >= HISTORY_SIZE {
                break;
            }
        }

        if sample_count >= MIN_SAMPLE_SIZE {
            let mut coefficients = Vec::with_capacity(3);
            coefficients.resize(3, 0_f32);
            // The 2nd coefficient is the derivative of the quadratic polynomial at
            // x = 0, and that happens to be the last timestamp that we end up
            // passing to polyFitLeastSquares.
            return poly_fit_least_squares(
                self.reusable_time.borrow().clone(),
                self.reusable_values.borrow().clone(),
                sample_count,
                2,
                coefficients,
            )
            .ok()
            .map(|r| r.get(1).cloned())
            .flatten()
            .unwrap_or_default();
        }

        return 0_f32;
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
        for _ in 0..capacity {
            vector.push(0_f32);
        }
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
        libm::sqrtf(self.dot(self))
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
    x: Vector,
    y: Vector,
    sample_count: usize,
    degree: usize,
    mut coefficients: Vec<f32>,
) -> Result<Vec<f32>, &'static str> {
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

    for i in (0..n - 1).rev() {
        coefficients[i] = q[i].dot(&wy);
        for j in (i + 1..n - 1).rev() {
            coefficients[i] -= r[i][j] * coefficients[j];
        }
        coefficients[i] /= r[i][i];
    }

    return Ok(coefficients);
}
