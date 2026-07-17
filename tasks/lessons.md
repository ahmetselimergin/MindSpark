# Lessons

- Gesture-domain APIs must define re-entrancy explicitly: a new `startPath` cannot replace an active gesture, and terminal path states must reject forward movement while still permitting immediate backtracking.
- Optimistic persistence controllers must serialize state derivation and writes together; retry requests should read pending state only when their queued operation starts, so concurrent callers cannot duplicate or reorder saves.
- Prefer Riverpod's public `AsyncNotifier.state` setter for previous-value merging; do not call `@internal` `AsyncValue` helpers or suppress analyzer warnings when the framework setter already provides the required behavior.
- Reversible interpolation cannot be derived only from each pair of raw pointer samples: retain the accepted synthetic segment so partial opposite samples can request the domain's true penultimate cells without inventing an off-route path.
- Treat replacement pointer segments as provisional: a rejected candidate must not erase the last accepted segment or advance reconciliation anchors.
- Riverpod `AsyncValue.hasValue` is not proof of success because refresh errors can retain previous data; gate side effects on no error/no loading and revalidate again when a post-frame callback executes.
- Retry callbacks need a synchronous in-flight latch before the initializer is invoked or the UI rebuilds; pair it with attempt identity so stale async completions cannot win state ownership.
