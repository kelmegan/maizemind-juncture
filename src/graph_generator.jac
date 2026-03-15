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
        suggestions: list[str] = [],
        evidence_category: str = "",
        assumptions: list[str] = [];
}

obj GraphEdge {
    has from_id: str,
        to_id: str,
        label: str = "supports",
        weight: float = 0.5,
        reasoning_type: str = "inductive";
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
        improvement_nodes: list[str] = [],
        suggested_counterarguments: list[dict] = [];
}


# ============================================================
# 2. LLM FUNCTIONS
# Optimized: 2 lean LLM calls with minimal output
# ============================================================

"""Extract an argument graph from notes. Return JSON:
{"nodes":[{"id":"n1","kind":"thesis|claim|evidence|counterarg","text":"...","evidence_category":"empirical_data|expert_testimony|anecdotal|logical_reasoning|analogy","assumptions":["implicit assumption 1"]},...],
"edges":[{"from_id":"n2","to_id":"n1","kind":"supports|contradicts|addresses","reasoning_type":"deductive|inductive|causal|correlational|analogical","weight":0.8},...]}
Rules: exactly 1 thesis. Max 8 nodes. For evidence nodes, set evidence_category and list any implicit assumptions the evidence relies on. Edge weight is 0.0-1.0 reflecting connection strength. reasoning_type describes HOW the source supports/contradicts the target."""
def parse_notes_and_edges(
    notes: str,
    documents: list[Document]
) -> str
by llm(temperature=0.2);

"""Given argument graph nodes and edges as JSON, return:
{"top_issues":["issue1","issue2","issue3"],
"strength_nodes":["n1"],
"improvement_nodes":["n3","n4"],
"counterarguments":[{"target_node":"n2","text":"A specific counterargument","severity":"high|medium|low"}]}
List the 3 most critical weaknesses. Suggest 1-3 specific counterarguments someone could raise against the weakest claims. Be brief."""
def analyze_and_summarize_llm(
    all_nodes_json: str,
    all_edges_json: str,
    sources_json: str
) -> str
by llm(temperature=0.2);

"""Evaluate a single piece of evidence in the context of an argument.
Return JSON: {"evidence_category":"empirical_data|expert_testimony|anecdotal|logical_reasoning|analogy","assumptions":["assumption1","assumption2"],"confidence":0.3,"reasoning":"brief explanation of quality assessment"}
evidence_category: empirical_data (scientific studies, statistics), expert_testimony (expert opinions, authoritative sources), anecdotal (personal stories, individual observations), logical_reasoning (logical deductions, philosophical arguments), analogy (comparisons to similar situations).
confidence: 0.0-1.0 reflecting how strong this evidence actually is. Be critical and honest. Religious texts as evidence = 0.1-0.2. Personal observation = 0.1-0.3. Published studies = 0.7-0.9.
assumptions: list any implicit assumptions this evidence relies on."""
def:pub evaluate_single_evidence(
    evidence_text: str,
    thesis_text: str,
    context_description: str
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

    # Evidence category
    raw_cat = d.get("evidence_category", d.get("category", ""));
    ev_cat = str(raw_cat) if raw_cat else "";

    # Assumptions list
    raw_assumptions = d.get("assumptions", []);
    assumption_list: list[str] = [];
    if raw_assumptions is None {
        raw_assumptions = [];
    }
    if isinstance(raw_assumptions, str) and raw_assumptions {
        assumption_list = [s.strip() for s in raw_assumptions.split(",")];
    } elif isinstance(raw_assumptions, list) {
        assumption_list = [str(a) for a in raw_assumptions];
    }

    gn = GraphNode(id=nid);
    gn.label = nkind;
    gn.text = ntext;
    gn.parent_id = nparent;
    gn.confidence = nconf;
    gn.status = nstatus;
    gn.issues = issue_list;
    gn.suggestions = sugg_list;
    gn.evidence_category = ev_cat;
    gn.assumptions = assumption_list;
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
    raw_rt = d.get("reasoning_type", d.get("reasoningType", d.get("reason_type", "inductive")));
    ert = str(raw_rt) if raw_rt else "inductive";

    ge = GraphEdge(from_id=efrom, to_id=eto);
    ge.label = ekind;
    ge.weight = ew;
    ge.reasoning_type = ert;
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
        "assumption": "evidence", "premise": "evidence",
        "counterarg": "counterarg", "counterargument": "counterarg",
        "counter_argument": "counterarg", "counter": "counterarg",
        "rebuttal": "counterarg"
    };
    category_map: dict[str, str] = {
        "empirical_data": "empirical_data", "empirical": "empirical_data",
        "expert_testimony": "expert_testimony", "expert": "expert_testimony",
        "anecdotal": "anecdotal", "personal": "anecdotal",
        "logical_reasoning": "logical_reasoning", "logical": "logical_reasoning",
        "analogy": "analogy"
    };
    reasoning_type_map: dict[str, str] = {
        "deductive": "deductive", "inductive": "inductive",
        "causal": "causal", "correlational": "correlational",
        "analogical": "analogical"
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
        # If LLM returned "assumption" type, convert to evidence and note the assumption
        old_label = n.label.lower().strip();
        if old_label in ["assumption", "premise"] and not n.assumptions {
            n.assumptions = [n.text];
        }
        n.label = type_map.get(old_label, "claim");
        n.status = status_map.get(n.status.lower().strip(), "needs_work");
        if not n.parent_id {
            n.parent_id = "";
        }
        # Normalize evidence category
        if n.evidence_category {
            n.evidence_category = category_map.get(n.evidence_category.lower().strip(), "logical_reasoning");
        } elif n.label == "evidence" {
            n.evidence_category = "logical_reasoning";
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
        "depends_on": "supports", "depends": "supports",
        "addresses": "addresses", "address": "addresses",
        "rebuts": "addresses", "rebuttal": "addresses"
    };
    reasoning_map: dict[str, str] = {
        "deductive": "deductive", "inductive": "inductive",
        "causal": "causal", "correlational": "correlational",
        "analogical": "analogical"
    };
    for e in edges {
        e.label = edge_map.get(e.label.lower().strip(), "supports");
        e.reasoning_type = reasoning_map.get(e.reasoning_type.lower().strip(), "inductive");
    }
    return edges;
}


# ============================================================
# 5. SCORING - Rule-based, NOT LLM
# ============================================================

"Calculate reasoning score from graph structure with evidence quality weighting."
def calculate_score(
    nodes: list[GraphNode],
    edges: list[GraphEdge]
) -> ReasoningScore {
    claims: list[GraphNode] = [n for n in nodes if n.label in ["claim", "thesis"]];
    total_claims = len(claims);

    if total_claims == 0 {
        return ReasoningScore();
    }

    # Evidence quality base weights by category
    category_weights: dict[str, float] = {
        "empirical_data": 0.9, "expert_testimony": 0.8,
        "logical_reasoning": 0.6, "analogy": 0.5, "anecdotal": 0.3
    };

    # Score each evidence node by category and assumptions
    evidence_nodes = [n for n in nodes if n.label == "evidence"];
    evidence_scores: dict[str, float] = {};
    for ev in evidence_nodes {
        base = category_weights.get(ev.evidence_category, 0.6);
        # Each unaddressed assumption reduces quality by 15%
        assumption_count = len(ev.assumptions) if ev.assumptions else 0;
        penalty = assumption_count * 0.15;
        quality = base - penalty;
        if quality < 0.1 { quality = 0.1; }
        evidence_scores[ev.id] = quality;
    }

    # --- Support coverage ---
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

    # Penalty: low quality evidence supporting claims
    weak_evidence_penalty = 0;
    for c in claims {
        if c.id in supported_ids {
            # Get average quality of supporting evidence
            sup_qualities: list[float] = [];
            for e in edges {
                if e.to_id == c.id and e.label == "supports" {
                    q = evidence_scores.get(e.from_id, 0.5);
                    sup_qualities.append(q);
                }
            }
            if sup_qualities {
                avg_q = sum(sup_qualities) / len(sup_qualities);
                if avg_q < 0.4 {
                    weak_evidence_penalty = weak_evidence_penalty + 20;
                } elif avg_q < 0.6 {
                    weak_evidence_penalty = weak_evidence_penalty + 10;
                }
            }
        }
    }
    if weak_evidence_penalty > 40 { weak_evidence_penalty = 40; }

    # Penalty: thin support (only 1 evidence)
    thin_penalty = 0;
    for c in claims {
        sups: list[str] = [];
        for e in edges {
            if e.to_id == c.id and e.label == "supports" {
                sups.append(e.from_id);
            }
        }
        if len(sups) == 1 { thin_penalty = thin_penalty + 10; }
    }
    if thin_penalty > 20 { thin_penalty = 20; }

    support_score_val = max(0, int(support_pct * 100) - thesis_penalty - weak_evidence_penalty - thin_penalty);

    # --- Premise coverage ---
    # Claims with weak evidence quality are "weak premise"
    claims_missing = len([c for c in claims if "missing_premise" in c.issues]);
    claims_weak_premise = 0;
    for c in claims {
        if "missing_premise" not in c.issues {
            sup_qualities2: list[float] = [];
            for e in edges {
                if e.to_id == c.id and e.label == "supports" {
                    q2 = evidence_scores.get(e.from_id, 0.5);
                    sup_qualities2.append(q2);
                }
            }
            if sup_qualities2 {
                avg_q2 = sum(sup_qualities2) / len(sup_qualities2);
                if avg_q2 < 0.4 {
                    claims_weak_premise = claims_weak_premise + 1;
                }
            }
        }
    }
    total_premise_issues = claims_missing + claims_weak_premise;
    premise_score_val = int((1 - total_premise_issues / total_claims) * 100);
    if premise_score_val < 0 {
        premise_score_val = 0;
    }

    # --- Consistency ---
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
        raw_counters = parsed_result.get("counterarguments", []);
        if isinstance(raw_counters, list) {
            summary.suggested_counterarguments = raw_counters;
        }
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
            "suggestions": ",".join(n.suggestions),
            "evidence_category": n.evidence_category,
            "assumptions": n.assumptions
        };
        node_dicts.append(nd);
    }

    edge_dicts: list[dict[str, str]] = [];
    for e in all_edges {
        ed: dict[str, str] = {
            "from_id": e.from_id, "to_id": e.to_id,
            "type": e.label, "weight": str(e.weight),
            "reasoning_type": e.reasoning_type
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
            "improvement_nodes": summary.improvement_nodes,
            "suggested_counterarguments": summary.suggested_counterarguments
        }
    };
}
