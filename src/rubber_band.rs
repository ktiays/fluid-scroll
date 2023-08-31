const RUBBER_BAND_COEFFICIENT: f32 = 0.55_f32;

pub fn calculate_offset(offset: f32, range: f32) -> f32 {
    // Check if offset and range are positive.
    if offset < 0_f32 || range < 0_f32 {
        assert!(false);
        return 0_f32;
    }
    (1_f32 - (1_f32 / (offset / range * RUBBER_BAND_COEFFICIENT + 1_f32))) * range
}
