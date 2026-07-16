# Lessons

- Gesture-domain APIs must define re-entrancy explicitly: a new `startPath` cannot replace an active gesture, and terminal path states must reject forward movement while still permitting immediate backtracking.
- Optimistic persistence controllers must serialize state derivation and writes together; retry requests should read pending state only when their queued operation starts, so concurrent callers cannot duplicate or reorder saves.
