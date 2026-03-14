"""Juncture - Graph Generator Pipeline.
Takes raw user notes/uploads, processes through LLM,
outputs structured argument map with scoring.
"""

import json;
import time;

# Model is configured in jac.toml under [plugins.byllm.model]


# ============================================================
# 1. DATA TYPES
# ============================================================

obj Source {
    has title: str = "",
        quote: str = "",
        page: int = 0;
}

obj GraphNode {
    has id: str,
        label: str = "claim",
        text: str = "",
        parent_id: str = "",
        confidence: float = 0.5,
        status: str = "needs_work",
        issues: list[str] = [],
        suggestions: list[str] = [];
}

obj GraphEdge {
    has from_id: str,
        to_id: str,
        label: str = "supports",
        weight: float = 0.5;
}

obj Document {
    has title: str,
        content: str;
}

obj ReasoningScore {
    has overall: int = 0,
        support_coverage: int = 0,
        premise_coverage: int = 0,
        consistency: int = 0,
        passing: bool = False;
}

obj GraphSummary {
    has top_issues: list[str] = [],
        strength_nodes: list[str] = [],
        improvement_nodes: list[str] = [];
}


# ============================================================
# 2. LLM FUNCTIONS
# Optimized: 2 lean LLM calls with minimal output
# ============================================================

"""Extract an argument graph from notes. Return JSON:
{"nodes":[{"id":"n1","kind":"thesis|claim|evidence|assumption|counterarg","text":"..."},...],
"edges":[{"from_id":"n2","to_id":"n1","kind":"supports|contradicts|depends_on|addresses"},...]}
Rules: exactly 1 thesis node. Keep nodes concise (one sentence each). Max 8 nodes."""
def parse_notes_and_edges(
    notes: str,
    documents: list[Document]
) -> str
by llm(temperature=0.2);

"""Given argument graph nodes and edges as JSON, return:
{"top_issues":["issue1","issue2","issue3"],
"strength_nodes":["n1"],
"improvement_nodes":["n3","n4"]}
List the 3 most critical weaknesses. Be brief."""
def analyze_and_summarize_llm(
    all_nodes_json: str,
    all_edges_json: str,
    sources_json: str
) -> str
by llm(temperature=0.2);


# ============================================================
# 3. JSON PARSING HELPERS
# ============================================================

"Parse JSON string from LLM, handling markdown fences."
def safe_parse_json(raw: str) -> list {
    cleaned = raw.strip();
    if cleaned.startswith("```") {
        lines = cleaned.split("\n");
        if lines[0].startswith("```") {
            lines = lines[1:];
        }
        if lines and lines[-1].strip().startswith("```") {
            lines = lines[:-1];
        }
        cleaned = "\n".join(lines).strip();
    }
    try {
        return json.loads(cleaned);
    } except Exception {
        return [];
    }
}

"Convert a raw dict from LLM into a GraphNode."
def dict_to_graphnode(d: dict[str, object]) -> GraphNode {
    nid = str(d.get("id", d.get("node_id", d.get("nodeId", "unknown"))));
    nkind = str(d.get("kind", d.get("type", d.get("node_type", d.get("label", "claim")))));
    ntext = str(d.get("text", d.get("content", d.get("description", ""))));
    nparent = d.get("parent_id", d.get("parentId", d.get("parent", "")));
    if nparent is None {
        nparent = "";
    }
    nparent = str(nparent);

    raw_conf = d.get("confidence", d.get("score", d.get("strength", 0.5)));
    try {
        nconf = float(raw_conf);
    } except Exception {
        nconf = 0.5;
    }

    nstatus = str(d.get("status", d.get("state", "needs_work")));

    raw_issues = d.get("issues", d.get("problems", []));
    issue_list: list[str] = [];
    if raw_issues is None {
        raw_issues = [];
    }
    if isinstance(raw_issues, str) and raw_issues {
        issue_list = [s.strip() for s in raw_issues.split(",")];
    } elif isinstance(raw_issues, list) {
        issue_list = [str(i) for i in raw_issues];
    }

    raw_sugg = d.get("suggestions", d.get("actions", d.get("suggested_actions", [])));
    sugg_list: list[str] = [];
    if raw_sugg is None {
        raw_sugg = [];
    }
    if isinstance(raw_sugg, str) and raw_sugg {
        sugg_list = [s.strip() for s in raw_sugg.split(",")];
    } elif isinstance(raw_sugg, list) {
        sugg_list = [str(s) for s in raw_sugg];
    }

    gn = GraphNode(id=nid);
    gn.label = nkind;
    gn.text = ntext;
    gn.parent_id = nparent;
    gn.confidence = nconf;
    gn.status = nstatus;
    gn.issues = issue_list;
    gn.suggestions = sugg_list;
    return gn;
}

"Convert a raw dict from LLM into a GraphEdge."
def dict_to_graphedge(d: dict[str, object]) -> GraphEdge {
    efrom = str(d.get("from_id", d.get("fromId", d.get("from", d.get("source", "")))));
    eto = str(d.get("to_id", d.get("toId", d.get("to", d.get("target", "")))));
    ekind = str(d.get("kind", d.get("type", d.get("edge_type", d.get("label", d.get("relation", "supports"))))));
    raw_w = d.get("weight", d.get("strength", d.get("score", 0.5)));
    try {
        ew = float(raw_w);
    } except Exception {
        ew = 0.5;
    }
    ge = GraphEdge(from_id=efrom, to_id=eto);
    ge.label = ekind;
    ge.weight = ew;
    return ge;
}


# ============================================================
# 4. NORMALIZERS
# ============================================================

"Normalize node labels and statuses to expected values."
def normalize_nodes(nodes: list[GraphNode]) -> list[GraphNode] {
    type_map: dict[str, str] = {
        "thesis": "thesis", "claim": "claim",
        "supportingclaim": "claim", "supporting_claim": "claim",
        "sub_claim": "claim", "subclaim": "claim",
        "evidence": "evidence", "document": "evidence",
        "source": "evidence", "fact": "evidence", "statistic": "evidence",
        "assumption": "assumption", "premise": "assumption",
        "counterarg": "counterarg", "counterargument": "counterarg",
        "counter_argument": "counterarg", "counter": "counterarg",
        "rebuttal": "counterarg"
    };
    status_map: dict[str, str] = {
        "ok": "ok", "valid": "ok", "strong": "ok",
        "stable": "ok", "supported": "ok",
        "needs_work": "needs_work", "weak": "needs_work",
        "unsupported": "needs_work", "rebutted": "needs_work",
        "missing": "missing", "none": "missing"
    };
    issue_map: dict[str, str] = {
        "unsupported_claim": "unsupported_claim",
        "missing_premise": "missing_premise",
        "contradiction": "contradiction",
        "vague_language": "vague_language",
        "limited_support": "unsupported_claim",
        "weak_support": "unsupported_claim",
        "unclear_methodology": "vague_language",
        "missing_evidence": "unsupported_claim",
        "weak_inference": "missing_premise",
        "ambiguity": "vague_language"
    };

    for n in nodes {
        n.label = type_map.get(n.label.lower().strip(), "claim");
        n.status = status_map.get(n.status.lower().strip(), "needs_work");
        if not n.parent_id {
            n.parent_id = "";
        }
        fixed: list[str] = [];
        for iss in n.issues {
            fixed.append(issue_map.get(iss.lower().strip(), iss.lower().strip()));
        }
        n.issues = fixed;
    }
    return nodes;
}

"Normalize edge labels to expected values."
def normalize_edges(edges: list[GraphEdge]) -> list[GraphEdge] {
    edge_map: dict[str, str] = {
        "supports": "supports", "support": "supports",
        "contradicts": "contradicts", "contradict": "contradicts",
        "counterarguments": "contradicts", "counterargument": "contradicts",
        "depends_on": "depends_on", "depends": "depends_on",
        "addresses": "addresses", "address": "addresses",
        "rebuts": "addresses", "rebuttal": "addresses"
    };
    for e in edges {
        e.label = edge_map.get(e.label.lower().strip(), "supports");
    }
    return edges;
}


# ============================================================
# 5. SCORING - Rule-based, NOT LLM
# ============================================================

"Calculate reasoning score from graph structure."
def calculate_score(
    nodes: list[GraphNode],
    edges: list[GraphEdge]
) -> ReasoningScore {
    claims: list[GraphNode] = [n for n in nodes if n.label in ["claim", "thesis"]];
    total_claims = len(claims);

    if total_claims == 0 {
        return ReasoningScore();
    }

    supported_ids: list[str] = [];
    for e in edges {
        if e.label == "supports" {
            supported_ids.append(e.to_id);
        }
    }
    supported_claims = len([c for c in claims if c.id in supported_ids]);
    support_pct = supported_claims / total_claims;

    thesis_nodes = [n for n in nodes if n.label == "thesis"];
    thesis_penalty = 0;
    if thesis_nodes {
        if thesis_nodes[0].id not in supported_ids {
            thesis_penalty = 15;
        }
    }
    support_score_val = max(0, int(support_pct * 100) - thesis_penalty);

    claims_missing = len([c for c in claims if "missing_premise" in c.issues]);
    premise_score_val = int((1 - claims_missing / total_claims) * 100);

    counterargs = [n for n in nodes if n.label == "counterarg"];
    total_contras = len(counterargs);
    addressed_ids: list[str] = [];
    for e in edges {
        if e.label == "addresses" {
            addressed_ids.append(e.to_id);
        }
    }

    if total_contras > 0 {
        unresolved = len([ca for ca in counterargs if ca.id not in addressed_ids]);
        consistency_val = int((1 - unresolved / total_contras) * 100);
    } else {
        consistency_val = 100;
    }

    overall = int(0.4 * support_score_val + 0.4 * premise_score_val + 0.2 * consistency_val);

    thesis_ok = len(thesis_nodes) > 0 and thesis_nodes[0].id in supported_ids;
    unresolved_ct = len([ca for ca in counterargs if ca.id not in addressed_ids]);

    return ReasoningScore(
        overall=overall,
        support_coverage=support_score_val,
        premise_coverage=premise_score_val,
        consistency=consistency_val,
        passing=(overall >= 75 and thesis_ok and unresolved_ct <= 1)
    );
}


# ============================================================
# 6. MAIN PIPELINE (Optimized: 2 LLM calls)
# ============================================================

"Run the full pipeline: notes in, structured graph out."
def generate_argument_graph(
    raw_text: str,
    documents: list[Document] = [],
    existing_nodes: list[GraphNode] = [],
    existing_edges: list[GraphEdge] = []
) -> dict[str, object] {

    # Step 1: Parse notes into nodes AND edges (single LLM call)
    t0 = time.time();
    print(f"  [Step 1/3] Parsing notes into graph structure...");
    raw_json = parse_notes_and_edges(raw_text, documents);
    print(f"  [Step 1/3] Done in {time.time() - t0:.1f}s");
    parsed = safe_parse_json(raw_json);

    # Handle both list and dict responses
    raw_nodes_list = [];
    raw_edges_list = [];
    if isinstance(parsed, dict) {
        raw_nodes_list = parsed.get("nodes", []);
        raw_edges_list = parsed.get("edges", []);
    } elif isinstance(parsed, list) {
        # Fallback: if LLM returns a list, treat it as nodes
        raw_nodes_list = parsed;
    }

    new_nodes: list[GraphNode] = [];
    for rd in raw_nodes_list {
        if isinstance(rd, dict) {
            new_nodes.append(dict_to_graphnode(rd));
        }
    }
    new_nodes = normalize_nodes(new_nodes);
    all_nodes = existing_nodes + new_nodes;

    new_edges: list[GraphEdge] = [];
    for rd in raw_edges_list {
        if isinstance(rd, dict) {
            new_edges.append(dict_to_graphedge(rd));
        }
    }
    new_edges = normalize_edges(new_edges);
    all_edges = existing_edges + new_edges;

    # Build JSON representations for next call
    nj = json.dumps([{"id": n.id, "kind": n.label, "text": n.text, "parent_id": n.parent_id} for n in all_nodes]);
    ej = json.dumps([{"from_id": e.from_id, "to_id": e.to_id, "kind": e.label, "weight": e.weight} for e in all_edges]);

    # Step 2: Brief analysis + summary (single LLM call)
    t1 = time.time();
    print(f"  [Step 2/3] Analyzing graph and generating summary...");
    doc_list: list[dict[str, str]] = [];
    for doc in documents {
        doc_list.append({"title": doc.title, "content": doc.content});
    }

    raw_result = analyze_and_summarize_llm(nj, ej, json.dumps(doc_list));
    print(f"  [Step 2/3] Done in {time.time() - t1:.1f}s");
    parsed_result = safe_parse_json(raw_result);

    analysis_dicts: list[dict[str, str]] = [];
    summary = GraphSummary();

    if isinstance(parsed_result, dict) {
        summary.top_issues = parsed_result.get("top_issues", []);
        summary.strength_nodes = parsed_result.get("strength_nodes", []);
        summary.improvement_nodes = parsed_result.get("improvement_nodes", []);
    }

    # Step 3: Calculate score (rule-based, no LLM)
    print(f"  [Step 3/3] Calculating score (rule-based)...");
    score = calculate_score(all_nodes, all_edges);
    print(f"  [Done] Total pipeline: {time.time() - t0:.1f}s | Nodes: {len(all_nodes)} | Edges: {len(all_edges)} | Score: {score.overall}");

    # Build output dicts
    node_dicts: list[dict[str, str]] = [];
    for n in all_nodes {
        nd: dict[str, str] = {
            "id": n.id, "type": n.label, "text": n.text,
            "parent_id": n.parent_id, "confidence": str(n.confidence),
            "status": n.status, "issues": ",".join(n.issues),
            "suggestions": ",".join(n.suggestions)
        };
        node_dicts.append(nd);
    }

    edge_dicts: list[dict[str, str]] = [];
    for e in all_edges {
        ed: dict[str, str] = {
            "from_id": e.from_id, "to_id": e.to_id,
            "type": e.label, "weight": str(e.weight)
        };
        edge_dicts.append(ed);
    }

    return {
        "nodes": node_dicts,
        "edges": edge_dicts,
        "analyses": analysis_dicts,
        "reasoning_score": {
            "overall": str(score.overall),
            "support_coverage": str(score.support_coverage),
            "premise_coverage": str(score.premise_coverage),
            "consistency": str(score.consistency),
            "passing": str(score.passing)
        },
        "summary": {
            "top_issues": summary.top_issues,
            "strength_nodes": summary.strength_nodes,
            "improvement_nodes": summary.improvement_nodes
        }
    };
}
