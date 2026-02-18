---
name: performance
description: This skill should be used when optimizing Swift applications, managing resources, or profiling performance with Instruments.
---

# Performance Optimization

## Overview

Standards for maintaining a fast, responsive, and resource-efficient application.

## 1. Resource Management

- **Lazy Initialization**: Use `lazy var` for expensive objects or computations to avoid unnecessary work during initialization.
- **Background Processing**: Perform heavy tasks (disk I/O, networking, data processing) on background threads.
- **Main Thread Isolation**: Reserve the Main Thread exclusively for UI updates and user interaction.

## 2. Caching & Memory

- **Caching Strategy**: Implement caching with explicit expiration and invalidation policies. Do not cache data indefinitely.
- **Image Optimization**: Use appropriate image sizes and formats; leverage system frameworks for efficient rendering.
- **Object Lifecycle**: Monitor object allocation to prevent memory growth over time.

## 3. Profiling & Measurement

- **Measure First**: Profile the application using Instruments (Time Profiler, Allocations) before attempting optimizations.
- **Performance Baselines**: Establish baselines for critical paths (e.g., audio processing) and monitor them during testing.
- **XCTMetric**: Use performance tests to detect regressions in efficiency.

## 4. Baseline KPIs (Track Before/After)

- **CPU**: average CPU % for target interaction and peak CPU %
- **Wakeups**: wakeups/sec over a fixed idle or interaction window
- **Memory**: peak resident size and growth trend over time
- **Responsiveness**: interaction latency and hitch/drop indicators where available
- **Startup**: launch-to-first-interaction time

Prefer repeatable extraction via:

```bash
make profile-report
```

## 5. Skill Routing

- Use `swiftui-performance-audit` for SwiftUI rendering/update/layout/animation runtime issues.
- Use `audio-realtime` for capture/processing callback pressure and low-latency audio constraints.
- Use this `performance` skill for app-wide/system-level optimization that is not primarily SwiftUI-rendering bound.
