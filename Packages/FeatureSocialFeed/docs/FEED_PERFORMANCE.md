# Feed Performance — Profiling Notes

Use these signposts (subsystem `com.splick.feed`, category `Performance`) with Instruments:

| Signpost | Meaning |
|----------|---------|
| `FeedLoad` | Initial load / pull-to-refresh duration |
| `FeedMerge` | Client-state merge after network fetch |
| `PostCardBody` | Post card body evaluation |
| `VideoPlayerCreate` / `VideoPlayerAcquire` / `VideoPlayerRelease` | AVPlayer pool lifecycle |

## Suggested Instruments templates

1. **SwiftUI** — body evaluation counts while scrolling the feed.
2. **os_signpost** — filter subsystem `com.splick.feed`.
3. **Allocations** — peak memory while scrolling video-heavy feeds (pool should keep ≤2 AVPlayers).
4. **Time Profiler** — main-thread work during fast scroll.

## Baseline checklist (manual)

- Scroll 50 posts with mixed image/video: target ≥55 FPS on iPhone 12+.
- Memory after scrolling 40 posts: no unbounded AVPlayer growth.
- Network while scrolling: one `POST /v1/feed/posts/batch-viewed` after idle, not N× `GET /v1/feed/posts/{id}`.
- Cold launch: cached feed paints before startup network returns.
