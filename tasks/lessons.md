# Lessons

- Gesture-domain APIs must define re-entrancy explicitly: a new `startPath` cannot replace an active gesture, and terminal path states must reject forward movement while still permitting immediate backtracking.
