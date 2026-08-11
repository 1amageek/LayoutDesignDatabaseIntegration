# LayoutDesignDatabaseIntegration

Host-only persistence integration for canonical cells, instances, nets, shapes, vias,
and layout constraints.

| Product | Responsibility |
|---|---|
| `LayoutDesignDatabaseSchema` | Locator-free canonical state, validation, paging, and deterministic plan compilation |
| `LayoutDesignDatabaseRuntimeAdapter` | Immutable registration contribution and bounded exact-snapshot reads |

The portable layout packages do not depend on DesignDatabase. DRC and extraction
verdicts remain evidence bound to an exact candidate revision and are not canonical
layout facets. Every mutation targets one database and one exact base revision.

## Verification

```bash
swift build --build-tests -j 4 \
  -Xswiftc -Xfrontend -Xswiftc -disable-round-trip-debug-types
```
