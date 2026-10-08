# LayoutDesignDatabaseIntegration

## Purpose and Scope

Host-only domain schema and runtime integration. Parent: [LSI](../DESIGN.md).
This adoption owns exact package dependencies; existing domain implementation
remains unchanged. SwiftPM target boundaries are listed in [Package.swift](Package.swift).

## Responsibilities and Boundaries

Schema targets own canonical domain state and exact source bindings. Runtime
adapters compose validated state with DesignDatabase's public runtime contracts.
Domain engines own algorithms; DesignDatabase owns storage and publication.

## Related Designs

| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [LSI](../DESIGN.md) | parent | Integration boundary | Host-only dependencies stay outside portable domains |
| [PDKKit](../PDKKit/DESIGN.md) | depends on | Existing public products pinned by Package.swift | Agree with the composing host revision |
| [PDKDesignDatabaseIntegration](../PDKDesignDatabaseIntegration/DESIGN.md) | depends on | Existing public products pinned by Package.swift | Agree with the composing host revision |
| [DesignDatabase](../DesignDatabase/DESIGN.md) | depends on | Exact revision, facets and runtime contribution | Fixed public database API |
| [Xcircuite](../Xcircuite/DESIGN.md) | used by | Schema and runtime adapter products | Resolve exact revisions without overrides |

## Architecture

```text
Domain values + exact source facets -> schema/codec/plan
    -> runtime adapter -> DesignDatabase public runtime -> Xcircuite composition
```

## Contracts and Invariants

[Package.swift](Package.swift) retains immutable revisions shared with the composing
host. PDK identity belongs to [PDKCore](../PDKKit/Sources/PDKCore/Identity/DESIGN.md);
this package retains exact source references without inferring identity from
availability. Existing canonical codecs and source admission own domain state.
PDK input-only database admission does not become producer-output admission.

## Verification and Change Impact

Existing schema/runtime tests own domain behavior. This dependency-only adoption
requires the composing host to build affected products and verify canonical PDK
source identity, descriptor refusal and ordinary exact dependency resolution.
It does not establish process qualification or unexecuted runtime test coverage.
