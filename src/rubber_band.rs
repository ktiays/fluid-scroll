const RUBBER_BAND_COEFFICIENT: f32 = 0.55_f32;

pub fn calculate_offset(offset: f32, range: f32) -> f32 {
    // Check if offset and range are positive.
    if offset < 0_f32 || range <= 0_f32 {
        return 0_f32;
    }
    (1_f32 - (1_f32 / (offset / range * RUBBER_BAND_COEFFICIENT + 1_f32))) * range
}

pub fn calculate_offset_inv(mut offset: f32, range: f32) -> f32 {
    if offset < 0_f32 || range < 0_f32 {
        return 0_f32;
    }
    // The offset and range cannot be equal.
    // Offset only approaches range infinitely.
    //
    // To ensure valid calculation, we set the maximum value of offset slightly smaller than range.
    offset = offset.min(range - 1e-5);
    (range * offset / (range - offset)) / RUBBER_BAND_COEFFICIENT
}

#[cfg(test)]
mod tests {
    use super::{calculate_offset, calculate_offset_inv};

    #[test]
    fn it_works() {
        let origin = 201_f32;
        let range = 600_f32;
        let offset = calculate_offset(origin, range);
        let inv = calculate_offset_inv(offset, range);
        assert!((origin - inv).abs() < 1e-2);
    }
}
