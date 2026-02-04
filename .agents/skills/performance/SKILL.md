---
name: performance
description: Optimization guidelines for Swift applications. Covers lazy initialization, background processing, caching, and profiling. Use when improving efficiency or responsiveness.
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
