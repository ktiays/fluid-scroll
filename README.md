# fluid-scroll

## Introduction

The library provides iOS-like scrolling animation algorithm, including scroll inertia and edge bounce.

## Motivation

Scrolling is an extremely important part of touch-based interaction, and almost all of our interactions rely on scrolling. We believe that the scrolling effect of iOS is the best among widely used mobile platforms at present. It is smooth, responsive, and has a good sense of inertia. We hope to bring the scrolling effect of iOS to other platforms.

This library aims to restore the scrolling effect of `UIScrollView` on iOS as much as possible. It is suitable for implementing scrolling effects in games and other scenarios.

## Preview

https://github.com/ktiays/fluid-scroll/assets/44366293/00ce77e5-92ee-4ea4-b789-7d57b7525039

## Usage

> [!Note]
> All time units in this library are measured in milliseconds, and speed units are measured in pixels per millisecond.

### Scroll Inertia

Create a `Scroller` object with the deceleration rate you want.

```rust
use fluid_scroll::Scroller;

let mut scroller = Scroller::new(DecelerationRate::NORMAL);
```

You can modify the deceleration rate at any time through the `set_deceleration_rate` method.

Call the `fling` method when starting to scroll, and provide the initial velocity of the scrolling.

```rust
scroller.fling(3.0);
```

At this point, you are ready to scroll.

You just need to retrieve the distance of movement for each moment from the `scroller` at the frequency you desire.

```rust
// After 16 milliseconds, the expected offset and velocity at this moment.
let scroller_value = scroller.value(16.0);
let offset = scroller_value.offset;
let velocity = scroller_value.velocity;
```

### Edge Bounce

`SpringBack` provides an animation that starts from any position and velocity, and returns to the 0 position.

It can be used to achieve the edge bouncing effect of lists, as well as scrolling animations from the current position to any target position.

```rust
use fluid_scroll::SpringBack;

let mut spring_back = SpringBack::new();
// Starts the animation from position 50 with a velocity of 1 pixel per millisecond.
spring_back.absorb(1.0, 50.0);
```

You can also a custom response value to start the animation.

```rust
spring_back.absorb_with_response(1.0, 50.0, 0.4);
```

You can get the offset of any time through the `SpringBack` object after the animation starts.

```rust
let offset = spring_back.value(16.0);
```

### Rubber Band Offset

A simple function used to map an offset like a rubber band.

It can be used to simulate the damping effect when continuing to pull while reaching the edge of a list.

```rust
use fluid_scroll::rubber_band;

let offset = rubber_band::calculate_offset(200.0, 600.0);
```

## FAQ

## License

Copyright (c) 2023 ktiays.

Source code and its algorithm are available under the terms of Apache License.
