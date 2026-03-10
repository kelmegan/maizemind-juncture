"""Juncture - Graph Generator Pipeline.
Takes raw user notes/uploads, processes through LLM,
outputs structured argument map with scoring.

Place this file at: src/graph_generator.jac
"""

# Model is configured in jac.toml under [plugins.byllm.model]
# No explicit Model import needed — uses the builtin `llm`


# ============================================================
# 1. DATA TYPES - Fully typed for byLLM schema generation
# ============================================================

"A source citation attached to evidence nodes"
obj Source {
    has title: str = "",
        quote: str = "",
        page: int = 0;
}

"A node in the argument graph"
obj GraphNode {
    has id: str,
        type: str,          # thesis | claim | evidence | assumption | counterarg
        text: str,
        parent_id: str = "",
        confidence: float = 0.5,
        support_score: float = 0.0,
        premise_coverage: float = 0.0,
        consistency_flag: bool = True,
        status: str = "needs_work",   # ok | needs_work | missing
        issues: list[str] = [],
        suggestions: list[str] = [];
}

sem GraphNode = "A node in an argument graph representing one idea";
sem GraphNode.type = "MUST be exactly one of these lowercase strings: thesis, claim, evidence, assumption, counterarg. No other values allowed.";
sem GraphNode.status = "MUST be exactly one of these lowercase strings: ok, needs_work, missing. No other values allowed.";
sem GraphNode.issues = "List of issue type strings. Each MUST be exactly one of: unsupported_claim, missing_premise, contradiction, vague_language. No other values allowed.";
sem GraphNode.suggestions = "Actionable improvement suggestions for this node";

"An edge connecting two nodes"
obj GraphEdge {
    has from_id: str,
        to_id: str,
        type: str,          # supports | contradicts | depends_on | addresses
        weight: float = 0.5;
}

sem GraphEdge = "A directed relationship between two argument graph nodes";
sem GraphEdge.type = "MUST be exactly one of these lowercase strings: supports, contradicts, depends_on, addresses. No other values allowed.";
sem GraphEdge.weight = "Strength of relationship from 0.0 to 1.0";

"A document uploaded by the user"
obj Document {
    has title: str,
        content: str;
}

"A single issue found in a node"
obj Issue {
    has type: str,
        explanation: str,
        suggested_actions: list[str] = [];
}

sem Issue.type = "MUST be exactly one of these lowercase strings: missing_evidence, weak_inference, ambiguity, contradiction. No other values allowed.";
sem Issue.suggested_actions = "Actions like: add_evidence, narrow_scope, add_assumption, clarify_wording";

"A critique of a specific node"
obj Critique {
    has node_id: str,
        severity: str,
        issues: list[Issue] = [];
}

sem Critique.severity = "MUST be exactly one of these lowercase strings: high, medium, low. No other values allowed.";

"A suggested action for a node"
obj SuggestedAction {
    has node_id: str,
        action: str,
        example_prompt: str;
}

sem SuggestedAction.action = "One of: add_evidence, narrow_scope, add_assumption, clarify_wording, address_counter";
sem SuggestedAction.example_prompt = "A short example prompt the user could follow to fix the issue";

"Summary of the graph analysis"
obj GraphSummary {
    has top_issues: list[str] = [],
        strength_nodes: list[str] = [],
        improvement_nodes: list[str] = [];
}

sem GraphSummary.top_issues = "Top 3 plain-language strings describing the biggest problems";
sem GraphSummary.strength_nodes = "Node IDs that are well-supported";
sem GraphSummary.improvement_nodes = "Node IDs that need the most work";

"Result from the critique step"
obj CritiqueResult {
    has critiques: list[Critique] = [],
        suggested_actions: list[SuggestedAction] = [];
}

"The reasoning score breakdown"
obj ReasoningScore {
    has overall: int = 0,
        support_coverage: int = 0,
        premise_coverage: int = 0,
        consistency: int = 0,
        passing: bool = False;
}


# ============================================================
# 2. LLM FUNCTIONS - Using Jac's `by llm` (MTP)
# ============================================================

"""Parse raw unstructured notes and any uploaded documents into
a structured argument graph. Decompose the text into a thesis,
supporting claims, evidence, assumptions, and counterarguments.
Each node should have a unique id (node_1, node_2, ...),
short text (one idea per node, max 30 words),
parent_id pointing to the node it relates to (thesis has no parent),
confidence score 0.0-1.0, and appropriate status and issues."""
def parse_notes_to_nodes(
    notes: str,
    documents: list[Document]
) -> list[GraphNode]
by llm();

"""Given a list of argument graph nodes, determine the logical
relationships between them. Each edge should connect two node ids
with the appropriate relationship type and a weight from 0.0-1.0."""
def generate_edges(
    nodes: list[GraphNode]
) -> list[GraphEdge]
by llm();

"""Given argument graph nodes and edges, produce critiques for
nodes that have issues. Return critiques with severity levels
and specific issues, plus suggested actions with example prompts."""
def critique_graph(
    nodes: list[GraphNode],
    edges: list[GraphEdge]
) -> CritiqueResult
by llm();

# --- Deep per-node analysis types ---

"A specific issue found during deep analysis of a node"
obj DeepIssue {
    has title: str,
        context: str,
        related_source: str = "",
        related_node_id: str = "";
}

sem DeepIssue.title = "Short plain-language title of the issue, e.g. 'Main claim lacks direct causal evidence'";
sem DeepIssue.context = "1-2 sentence explanation of WHY this is a problem and which source or node is involved";
sem DeepIssue.related_source = "Filename of the source document involved, if any";
sem DeepIssue.related_node_id = "ID of the related node, if any";

"A specific actionable suggestion"
obj DeepSuggestion {
    has action: str,
        detail: str,
        source_hint: str = "";
}

sem DeepSuggestion.action = "Short action label like 'Add longitudinal study showing causation' or 'Critique Oxford sample demographics'";
sem DeepSuggestion.detail = "1-2 sentence explanation of how to carry out this action";
sem DeepSuggestion.source_hint = "A specific type of source to look for, e.g. 'peer-reviewed meta-analysis post-2020'";

"A recommended reading or source to strengthen this node"
obj ReadingRec {
    has title: str,
        why: str,
        search_query: str = "";
}

sem ReadingRec.title = "Descriptive title of what to look for, e.g. 'CDC adolescent mental health statistics 2023'";
sem ReadingRec.why = "Why this reading would strengthen or clarify this part of the argument";
sem ReadingRec.search_query = "A Google Scholar search query to find this type of source";

"A logical concept relevant to this node"
obj LogicalConcept {
    has term: str,
        definition: str,
        how_to_use: str,
        example: str;
}

sem LogicalConcept.term = "Formal name of the logical concept, e.g. 'Correlation ≠ Causation'";
sem LogicalConcept.definition = "Plain language definition of this concept";
sem LogicalConcept.how_to_use = "When and how to apply this concept in arguments";
sem LogicalConcept.example = "A concrete everyday example illustrating this concept";

"Complete deep analysis of a single node"
obj NodeAnalysis {
    has node_id: str,
        strength_label: str = "",
        issues: list[DeepIssue] = [],
        suggestions: list[DeepSuggestion] = [],
        further_reading: list[ReadingRec] = [],
        logical_concept: str = "",
        concept_detail: LogicalConcept = LogicalConcept(
            term="", definition="", how_to_use="", example=""
        );
}

sem NodeAnalysis.strength_label = "One of: well-supported, needs-evidence, weak, contradicted";
sem NodeAnalysis.logical_concept = "Name of a logical concept relevant to this node, or empty string if none applies";

"""Perform deep analysis on a single node in context of its
neighbors, the full graph structure, and available sources.
Consider: What logical fallacies or gaps exist? What sources
could strengthen it? What concepts should the user understand?
Be specific — reference actual node text and source titles."""
def analyze_node_deep(
    target_node: GraphNode,
    parent_nodes: list[GraphNode],
    child_nodes: list[GraphNode],
    sibling_nodes: list[GraphNode],
    all_edges: list[GraphEdge],
    available_sources: list[Document]
) -> NodeAnalysis
by llm(temperature=0.3);

"""Given argument graph nodes, edges, and critiques, produce a
summary with the top 3 issues, strongest nodes, and nodes
needing the most improvement."""
def summarize_graph(
    nodes: list[GraphNode],
    edges: list[GraphEdge],
    critiques: list[Critique]
) -> GraphSummary
by llm();


# ============================================================
# 3. SCORING - Rule-based (NOT LLM), per project spec
# ============================================================

"""Normalize LLM output to match expected schema values.
Fixes casing, maps synonyms, and cleans up sloppy model output."""
def normalize_nodes(nodes: list[GraphNode]) -> list[GraphNode] {
    # Maps for common LLM mistakes
    type_map: dict[str, str] = {
        "thesis": "thesis",
        "claim": "claim",
        "supportingclaim": "claim",
        "supporting_claim": "claim",
        "sub_claim": "claim",
        "subclaim": "claim",
        "evidence": "evidence",
        "document": "evidence",
        "source": "evidence",
        "fact": "evidence",
        "statistic": "evidence",
        "assumption": "assumption",
        "premise": "assumption",
        "counterarg": "counterarg",
        "counterargument": "counterarg",
        "counter_argument": "counterarg",
        "counter": "counterarg",
        "rebuttal": "counterarg"
    };

    status_map: dict[str, str] = {
        "ok": "ok",
        "valid": "ok",
        "strong": "ok",
        "stable": "ok",
        "supported": "ok",
        "needs_work": "needs_work",
        "weak": "needs_work",
        "unsupported": "needs_work",
        "rebutted": "needs_work",
        "missing": "missing",
        "none": "missing"
    };

    issue_map: dict[str, str] = {
        "unsupported_claim": "unsupported_claim",
        "missing_premise": "missing_premise",
        "contradiction": "contradiction",
        "vague_language": "vague_language",
        "limited_support": "unsupported_claim",
        "weak_support": "unsupported_claim",
        "unclear_methodology": "vague_language",
        "lack_of_enforcement": "unsupported_claim",
        "missing_evidence": "unsupported_claim",
        "weak_inference": "missing_premise",
        "ambiguity": "vague_language"
    };

    for n in nodes {
        n.type = type_map.get(n.type.lower().strip(), "claim");
        n.status = status_map.get(n.status.lower().strip(), "needs_work");
        normalized_issues: list[str] = [];
        for iss in n.issues {
            normalized_issues.append(
                issue_map.get(iss.lower().strip(), iss.lower().strip())
            );
        }
        n.issues = normalized_issues;
    }

    return nodes;
}

"""Normalize edge types from LLM output."""
def normalize_edges(edges: list[GraphEdge]) -> list[GraphEdge] {
    edge_type_map: dict[str, str] = {
        "supports": "supports",
        "support": "supports",
        "contradicts": "contradicts",
        "contradict": "contradicts",
        "counterarguments": "contradicts",
        "counterargument": "contradicts",
        "depends_on": "depends_on",
        "depends": "depends_on",
        "addresses": "addresses",
        "address": "addresses",
        "rebuts": "addresses",
        "rebuttal": "addresses"
    };

    for e in edges {
        e.type = edge_type_map.get(e.type.lower().strip(), "supports");
    }

    return edges;
}

"""Calculate the reasoning score from graph structure.
Score = 40% Support Coverage + 40% Premise Coverage + 20% Consistency."""
def calculate_score(
    nodes: list[GraphNode],
    edges: list[GraphEdge]
) -> ReasoningScore {

    # Count node types
    claims: list[GraphNode] = [n for n in nodes if n.type in ["claim", "thesis"]];
    total_claims = len(claims);

    if total_claims == 0 {
        return ReasoningScore(
            overall=0,
            support_coverage=0,
            premise_coverage=0,
            consistency=0,
            passing=False
        );
    }

    # --- Support Coverage (40%) ---
    supported_ids: list[str] = [];
    for e in edges {
        if e.type == "supports" {
            supported_ids.append(e.to_id);
        }
    }
    supported_claims = len([c for c in claims if c.id in supported_ids]);
    support_pct = supported_claims / total_claims;

    # Thesis without direct evidence = -15 penalty
    thesis_nodes = [n for n in nodes if n.type == "thesis"];
    thesis_penalty = 0;
    if thesis_nodes {
        thesis_id = thesis_nodes[0].id;
        if thesis_id not in supported_ids {
            thesis_penalty = 15;
        }
    }

    support_score_val = max(0, int(support_pct * 100) - thesis_penalty);

    # --- Premise Coverage (40%) ---
    claims_missing_premise = len([
        c for c in claims
        if "missing_premise" in c.issues
    ]);
    premise_score_val = int((1 - claims_missing_premise / total_claims) * 100);

    # --- Consistency (20%) ---
    counterargs = [n for n in nodes if n.type == "counterarg"];
    total_contradictions = len(counterargs);

    addressed_ids: list[str] = [];
    for e in edges {
        if e.type == "addresses" {
            addressed_ids.append(e.to_id);
        }
    }

    if total_contradictions > 0 {
        unresolved = len([
            ca for ca in counterargs
            if ca.id not in addressed_ids
        ]);
        consistency_val = int((1 - unresolved / total_contradictions) * 100);
    } else {
        consistency_val = 100;
    }

    # --- Overall ---
    overall = int(
        0.4 * support_score_val +
        0.4 * premise_score_val +
        0.2 * consistency_val
    );

    thesis_supported = (
        len(thesis_nodes) > 0
        and thesis_nodes[0].id in supported_ids
    );

    unresolved_count = len([
        ca for ca in counterargs
        if ca.id not in addressed_ids
    ]);

    passing = (
        overall >= 75
        and thesis_supported
        and unresolved_count <= 1
    );

    return ReasoningScore(
        overall=overall,
        support_coverage=support_score_val,
        premise_coverage=premise_score_val,
        consistency=consistency_val,
        passing=passing
    );
}


# ============================================================
# 4. MAIN PIPELINE - Orchestrates everything
# ============================================================

"""Run the full pipeline: notes/docs in -> structured graph out."""
def generate_argument_graph(
    raw_text: str,
    documents: list[Document] = [],
    existing_nodes: list[GraphNode] = [],
    existing_edges: list[GraphEdge] = []
) -> str {

    # Step 1: Parse notes into nodes via LLM
    print("  Step 1/5: Parsing notes into nodes...");
    new_nodes = parse_notes_to_nodes(raw_text, documents);
    new_nodes = normalize_nodes(new_nodes);

    # Merge with any existing graph
    all_nodes = existing_nodes + new_nodes;

    # Step 2: Generate edges via LLM
    print("  Step 2/5: Generating edges...");
    edges = generate_edges(all_nodes);
    edges = normalize_edges(edges);
    all_edges = existing_edges + edges;

    # Step 3: Deep per-node analysis via LLM
    print("  Step 3/5: Deep analysis per node...");
    # Build neighbor lookup
    parent_map: dict[str, str] = {};
    children_map: dict[str, list[str]] = {};
    for e in all_edges {
        if e.type in ["supports", "depends_on"] {
            parent_map[e.from_id] = e.to_id;
            if e.to_id not in children_map {
                children_map[e.to_id] = [];
            }
            children_map[e.to_id].append(e.from_id);
        }
    }

    node_map: dict[str, GraphNode] = {};
    for n in all_nodes {
        node_map[n.id] = n;
    }

    analyses: list[NodeAnalysis] = [];
    for n in all_nodes {
        # Get parent
        parents: list[GraphNode] = [];
        if n.id in parent_map {
            pid = parent_map[n.id];
            if pid in node_map {
                parents.append(node_map[pid]);
            }
        }
        # Get children
        children: list[GraphNode] = [];
        if n.id in children_map {
            for cid in children_map[n.id] {
                if cid in node_map {
                    children.append(node_map[cid]);
                }
            }
        }
        # Get siblings (same parent)
        siblings: list[GraphNode] = [];
        if n.id in parent_map {
            pid = parent_map[n.id];
            if pid in children_map {
                for sid in children_map[pid] {
                    if sid != n.id and sid in node_map {
                        siblings.append(node_map[sid]);
                    }
                }
            }
        }

        print(f"    Analyzing: {n.text[:40]}...");
        analysis = analyze_node_deep(
            n, parents, children, siblings, all_edges, documents
        );
        analysis.node_id = n.id;
        analyses.append(analysis);
    }

    # Also run bulk critique for the CritiqueResult (backwards compat)
    critique_result = critique_graph(all_nodes, all_edges);

    # Step 4: Calculate score (rule-based, NOT LLM)
    print("  Step 4/5: Calculating score...");
    score = calculate_score(all_nodes, all_edges);

    # Step 5: Summarize via LLM
    print("  Step 5/5: Generating summary...");
    summary = summarize_graph(all_nodes, all_edges, critique_result.critiques);

    # Build output matching output_example.json schema
    add_mutations: list[dict[str, str]] = [];
    for n in all_nodes {
        add_mutations.append({
            "temp_id": n.id,
            "type": n.type,
            "text": n.text,
            "parent_id": n.parent_id
        });
    }

    # Convert nodes to dicts for frontend
    node_dicts: list[dict[str, str]] = [];
    for n in all_nodes {
        nd: dict[str, str] = {
            "id": n.id,
            "type": n.type,
            "text": n.text,
            "parent_id": n.parent_id,
            "confidence": str(n.confidence),
            "status": n.status
        };
        node_dicts.append(nd);
    }

    edge_dicts: list[dict[str, str]] = [];
    for e in all_edges {
        ed: dict[str, str] = {
            "from_id": e.from_id,
            "to_id": e.to_id,
            "type": e.type,
            "weight": str(e.weight)
        };
        edge_dicts.append(ed);
    }

    # Convert analyses to dicts for frontend
    analysis_dicts: list[dict[str, str]] = [];
    for a in analyses {
        issue_list: list[str] = [];
        for iss in a.issues {
            issue_list.append(
                iss.title + "|||" + iss.context + "|||" +
                iss.related_source + "|||" + iss.related_node_id
            );
        }
        sugg_list: list[str] = [];
        for sg in a.suggestions {
            sugg_list.append(
                sg.action + "|||" + sg.detail + "|||" + sg.source_hint
            );
        }
        reading_list: list[str] = [];
        for rd in a.further_reading {
            reading_list.append(
                rd.title + "|||" + rd.why + "|||" + rd.search_query
            );
        }
        ad: dict[str, str] = {
            "node_id": a.node_id,
            "strength_label": a.strength_label,
            "issues": ";;;".join(issue_list),
            "suggestions": ";;;".join(sugg_list),
            "further_reading": ";;;".join(reading_list),
            "logical_concept": a.logical_concept,
            "concept_term": a.concept_detail.term,
            "concept_definition": a.concept_detail.definition,
            "concept_how_to_use": a.concept_detail.how_to_use,
            "concept_example": a.concept_detail.example
        };
        analysis_dicts.append(ad);
    }

    critique_dicts: list[dict[str, str]] = [];
    for c in critique_result.critiques {
        issue_strs: list[str] = [];
        for iss in c.issues {
            issue_strs.append(f"{iss.type}: {iss.explanation}");
        }
        cd: dict[str, str] = {
            "node_id": c.node_id,
            "severity": c.severity,
            "issues": ", ".join(issue_strs)
        };
        critique_dicts.append(cd);
    }

    return {
        "nodes": node_dicts,
        "edges": edge_dicts,
        "analyses": analysis_dicts,
        "critiques": critique_dicts,
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


# ============================================================
# 5. ENTRY POINT - For standalone testing with `jac run`
# ============================================================

with entry {
    import json;

    test_notes = "Climate change is primarily caused by human activities. "
                 "Burning fossil fuels releases CO2 into the atmosphere. "
                 "Some scientists argue that natural cycles also play a role. "
                 "The Paris Agreement aims to limit warming to 1.5 degrees. "
                 "However, many countries are not meeting their targets. "
                 "Renewable energy is growing but not fast enough.";

    test_docs = [
        Document(
            title="IPCC Report 2023",
            content="Human activities have unequivocally caused global warming."
        )
    ];

    print("=== Juncture Graph Generator ===");
    print("Processing notes...\n");

    # Run full pipeline
    result = generate_argument_graph(test_notes, test_docs);

    # Save to JSON for frontend to read
    with open("graph_output.json", "w") as f {
        json.dump(result, f, indent=2);
    }

    print("--- NODES ---");
    for n in result.get("nodes", []) {
        print(f"  [{n.get('type', '')}] {n.get('text', '')} "
              f"(confidence: {n.get('confidence', '')}, status: {n.get('status', '')})");
    }

    print("\n--- EDGES ---");
    for e in result.get("edges", []) {
        print(f"  {e.get('from_id', '')} --{e.get('type', '')}--> "
              f"{e.get('to_id', '')} (weight: {e.get('weight', '')})");
    }

    s = result.get("reasoning_score", {});
    print(f"\n--- SCORE ---");
    print(f"  Overall: {s.get('overall', '0')}");
    print(f"  Support: {s.get('support_coverage', '0')}");
    print(f"  Premise: {s.get('premise_coverage', '0')}");
    print(f"  Consistency: {s.get('consistency', '0')}");
    print(f"  Passing: {s.get('passing', 'False')}");

    print("\n--- TOP ISSUES ---");
    for issue in result.get("summary", {}).get("top_issues", []) {
        print(f"  - {issue}");
    }

    print(f"\nResults saved to graph_output.json");
    print("Done!");
}