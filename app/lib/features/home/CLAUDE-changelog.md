# Change Log
> Auto-maintained by session-exit hook. Last updated: 2026-09-02

- **2026-09-02 23:20** [home]. Backend confirmed. Eight statuses, no `expired` and no `no_show` — a ride that expires is written as **`cancelled`**. That matters: it means the "get off the page" fix hangs entirely on handling `Trip
- **2026-09-02 23:19** [home]. Correcting my own read — the null guard is fine (`if (state.offer != null)` wraps it), so no crash there. The real defect is narrower and I can now state it precisely. ## What's actually wrong `accept
