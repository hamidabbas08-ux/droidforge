# V11.11 — Final Two-Test Runtime Decision

This build performs exactly two automated isolated-process JVM attempts from one tap:

1. `minimal-practical`: java.home, tmpdir, Xms16m, Xmx128m, Xrs.
2. `absolute-minimum`: java.home and Xmx128m, with unrecognized options ignored.

If both attempts fail, the UI reports `FINAL RUNTIME DECISION: REJECTED` and explicitly states that no more tests will be run on this runtime.
