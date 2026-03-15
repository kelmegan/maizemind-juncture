# Graph Schema v0

This document is the MVP target contract and acceptance reference for Juncture.
It describes the response shape the team is aligning toward for graph generation,
scoring, revision, and export preview. The current `j.2` runtime may not expose
every field below yet.

## Top-level response

```json
{
  "graph": {
    "id": "graph_remote_work_demo",
    "nodes": [],
    "edges": []
  },
  "score": {
    "overall": 61,
    "support": 0.5,
    "premise": 0.75,
    "consistency": 0.5
  },
  "issues": [],
  "actions": [],
  "summary": {
    "top_issue": "Two claims need direct evidence.",
    "issue_count": 4,
    "weak_node_count": 3,
    "export_warning": "Export now, but 2 claims are unsupported. Want to fix the top 3 issues first?"
  }
}
```

## `graph`

### Node

Required fields:

- `id`
- `type`
- `content`
- `status`

Optional fields:

- `label`
- `position`
- `confidence`
- `flags`

Allowed node types:

- `THESIS`
- `CLAIM`
- `EVIDENCE`
- `ASSUMPTION`
- `COUNTERARGUMENT`

Allowed status values:

- `ok`
- `weak`
- `missing_premise`
- `unsupported`
- `contradicted`

Recommended node shape:

```json
{
  "id": "claim_productivity",
  "type": "CLAIM",
  "label": "Claim 1",
  "content": "Remote work improves productivity by reducing office distractions.",
  "status": "unsupported",
  "position": { "x": 90, "y": 220 },
  "confidence": 0.72,
  "flags": ["needs_evidence"]
}
```

### Edge

Required fields:

- `id`
- `source`
- `target`
- `type`

Allowed edge types:

- `SUPPORTS`
- `DEPENDS_ON`
- `CONTRADICTS`
- `ADDRESSES`

Recommended edge shape:

```json
{
  "id": "edge_evidence_claim",
  "source": "evidence_commute_study",
  "target": "claim_productivity",
  "type": "SUPPORTS"
}
```

## `score`

All score values are normalized to `0..1` except `overall`, which is `0..100`.

- `overall = round(40 * support + 40 * premise + 20 * consistency)`
- `support = C_supported / C`
- `premise = clamp(1 - (C_needs_premise / C), 0, 1)`
- `consistency = 1 - (K_unresolved / max(1, K))`
- Apply a flat `-15` penalty to `overall` if a thesis-level claim is unsupported

Where:

- `C` = total `THESIS` + `CLAIM` nodes
- `C_supported` = claims with incoming `SUPPORTS` edge from an `EVIDENCE` node
- `C_needs_premise` = claims flagged `MISSING_PREMISE`
- `K` = `CONTRADICTS` edges
- `K_unresolved` = contradictions with no `ADDRESSES` edge or acknowledged resolution

## `issues`

Ranked issue list. Each item should include:

- `id`
- `nodeId`
- `severity`
- `type`
- `title`
- `description`
- `why`
- `action`

## `actions`

Ordered next-step list. Each item should include:

- `id`
- `nodeId`
- `label`
- `kind`
- `priority`
- `reason`

## `summary`

Optional but recommended:

- `top_issue`
- `issue_count`
- `weak_node_count`
- `export_warning`
