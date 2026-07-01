---
name: performance
description: This skill should be used when the user asks to "optimize CPU/memory/startup", "profile with Instruments", or "improve app-wide performance" outside primary SwiftUI rendering issues.
---

# Performance Optimization

## Role

Use this skill as the canonical owner for app-wide performance and resource-efficiency guidance in Prisma.

- Own CPU, memory, startup, and measurement practices outside primarily SwiftUI-rendering issues.
- Keep optimization advice measurement-first and baseline-driven.
- Delegate SwiftUI runtime and audio hot-path issues to their specialist owners.

## Scope Boundary

- Use this skill for app-wide/system-level performance work.
- Use `../swiftui-performance-audit/SKILL.md` for SwiftUI rendering/update/layout performance.
- Use `../audio-realtime/SKILL.md` for low-latency audio callback and buffering constraints.

## When to Use

Use this skill when the user asks to optimize CPU, memory, or startup, profile with Instruments, or improve app-wide performance outside primary SwiftUI rendering issues.

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

## 2026-06-19 Progression Drill

### New Evidence

- `ebdc397d` introduced model performance attempt tracking and metrics.
- `667752e9` removed provider/model search and kept the performance history surface compact.
- Recent product direction: performance comparison should use latency, error rate, and normalized speed/throughput; history should preserve immutable attempts but show only the 10 newest rows in the dashboard.

### Skill Deepening Focus

1. Treat model-performance work as analytics over immutable attempts, not mutable transcription snapshots.
2. Separate raw latency from normalized throughput: transcription should account for audio duration; post-processing should account for text/bytes handled.
3. Keep dashboard UX compact by default: summary, filters, leaderboard, and newest 10 attempts before adding search-heavy controls.
4. Add regression tests for ranking order, error-rate impact, newest-first history, and UI-facing caps whenever performance aggregation changes.

## 2026-06-30 Progression Drill

### New Evidence

- `e9f99c25` centralized metrics metadata caching and formatting logic instead of recomputing it inside dashboard pages.
- `cdd980f5` moved leaderboard sorting into `ModelPerformance` and heatmap calculations into `MetricsDashboardSupport`, separating pure calculation from SwiftUI rendering.
- `77b1b90f` replaced instance-based weekday symbol retrieval with a static constant to avoid repeated `DateFormatter` creation in dashboard sections.

### Skill Deepening Focus

1. Treat dashboard performance work as two tracks: pure domain/support calculations and SwiftUI rendering cost.
2. Cache stable formatters, symbols, and metadata outside hot view body paths; do not instantiate formatters per render.
3. Keep leaderboard and heatmap rules testable outside the view layer before tuning visual layout.
4. When optimizing settings dashboards, pair the code change with a quick scan for repeated formatters, sorting, grouping, or date math in computed view properties.
