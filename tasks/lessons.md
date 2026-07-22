# Lessons

- Gesture-domain APIs must define re-entrancy explicitly: a new `startPath` cannot replace an active gesture, and terminal path states must reject forward movement while still permitting immediate backtracking.
- Optimistic persistence controllers must serialize state derivation and writes together; retry requests should read pending state only when their queued operation starts, so concurrent callers cannot duplicate or reorder saves.
- Prefer Riverpod's public `AsyncNotifier.state` setter for previous-value merging; do not call `@internal` `AsyncValue` helpers or suppress analyzer warnings when the framework setter already provides the required behavior.
- Reversible interpolation cannot be derived only from each pair of raw pointer samples: retain the accepted synthetic segment so partial opposite samples can request the domain's true penultimate cells without inventing an off-route path.
- Treat replacement pointer segments as provisional: a rejected candidate must not erase the last accepted segment or advance reconciliation anchors.
- Riverpod `AsyncValue.hasValue` is not proof of success because refresh errors can retain previous data; gate side effects on no error/no loading and revalidate again when a post-frame callback executes.
- Retry callbacks need a synchronous in-flight latch before the initializer is invoked or the UI rebuilds; pair it with attempt identity so stale async completions cannot win state ownership.
- End-of-content is a distinct product state: `highestUnlockedLevel` cannot double as “next playable” after the final level is completed. Acceptance tests must return Home after final completion and assert that the last level is not silently reopened.
- Passing widget tests is not evidence of visual quality. Before calling a UI complete, inspect a rendered phone-sized frame for hierarchy, board contrast, control affordance, and unstructured empty space.
- Save-format upgrades must reconcile legacy semantic invariants at one shared state boundary before any screen authorizes or labels content. Keep harmless derived repairs non-persistent when repeating them is idempotent, and stop sequential advancement at the first completion gap.
