# """Juncture - Graph Generator Pipeline.
# Takes raw user notes/uploads, processes through LLM,
# outputs structured argument map with scoring.

# Place this file at: src/graph_generator.jac
# """

# import json;

# # Model is configured in jac.toml under [plugins.byllm.model]


# # ============================================================
# # 1. DATA TYPES
# # ============================================================

# obj Source {
#     has title: str = "",
#         quote: str = "",
#         page: int = 0;
# }

# obj GraphNode {
#     has id: str,
#         label: str = "claim",
#         text: str = "",
#         parent_id: str = "",
#         confidence: float = 0.5,
#         status: str = "needs_work",
#         issues: list[str] = [],
#         suggestions: list[str] = [];
# }

# obj GraphEdge {
#     has from_id: str,
#         to_id: str,
#         label: str = "supports",
#         weight: float = 0.5;
# }

# obj Document {
#     has title: str,
#         content: str;
# }

# obj CritiqueResult {
#     has raw: str = "";
# }

# obj ReasoningScore {
#     has overall: int = 0,
#         support_coverage: int = 0,
#         premise_coverage: int = 0,
#         consistency: int = 0,
#         passing: bool = False;
# }

# obj GraphSummary {
#     has top_issues: list[str] = [],
#         strength_nodes: list[str] = [],
#         improvement_nodes: list[str] = [];
# }


# # ============================================================
# # 2. LLM FUNCTIONS - All return raw JSON strings
# # ============================================================

# """Parse raw unstructured notes into a JSON list of node objects.
# Each node must have: id (like node_1), kind (thesis/claim/evidence/assumption/counterarg),
# text (one short sentence), parent_id (string or null), confidence (0.0-1.0),
# status (ok/needs_work/missing), issues (list of strings), suggestions (list of strings)."""
# def parse_notes_to_nodes(
#     notes: str,
#     documents: list[Document]
# ) -> str
# by llm();

# """Given nodes as JSON, return a JSON list of edge objects.
# Each edge must have: from_id, to_id, kind (supports/contradicts/depends_on/addresses), weight (0.0-1.0)."""
# def generate_edges(
#     nodes_json: str
# ) -> str
# by llm();

# """Given nodes and edges as JSON, return a JSON object with:
# critiques (list of {node_id, severity, issues}),
# suggested_actions (list of {node_id, action, example_prompt})."""
# def critique_graph_llm(
#     nodes_json: str,
#     edges_json: str
# ) -> str
# by llm();

# """Given nodes, edges, and critiques as JSON, return a JSON object with:
# top_issues (3 strings), strength_nodes (list of node ids), improvement_nodes (list of node ids)."""
# def summarize_graph_llm(
#     nodes_json: str,
#     edges_json: str,
#     critiques_json: str
# ) -> str
# by llm();

# """Perform deep analysis on a single node. You are given the node,
# its parent nodes, child nodes, sibling nodes, and available source documents.
# Return a JSON object with these fields:
# - strength_label: one of "well-supported", "needs-evidence", "weak", "contradicted"
# - issues: list of objects with {title, context, related_source}
#   where title is a short problem name, context explains WHY it matters
#   and references specific nodes or sources, related_source is a filename if relevant
# - suggestions: list of objects with {action, detail, source_hint}
#   where action is a short label, detail explains how to do it,
#   source_hint suggests what kind of source to look for
# - further_reading: list of objects with {title, why, search_query}
#   where title describes what to find, why explains the value,
#   search_query is a Google Scholar search string
# - logical_concept: empty string or the name of a relevant logical concept
# - concept_term: formal name (or empty)
# - concept_definition: plain language definition (or empty)
# - concept_how_to_use: when and how to apply it (or empty)
# - concept_example: a concrete everyday example (or empty)
# Be specific. Reference actual node text and source titles."""
# def analyze_node_deep_llm(
#     target_node_json: str,
#     parent_nodes_json: str,
#     child_nodes_json: str,
#     sibling_nodes_json: str,
#     sources_json: str
# ) -> str
# by llm(temperature=0.3);


# # ============================================================
# # 3. JSON PARSING HELPERS
# # ============================================================

# "Parse JSON string from LLM, handling markdown fences."
# def safe_parse_json(raw: str) -> list {
#     cleaned = raw.strip();
#     if cleaned.startswith("```") {
#         lines = cleaned.split("\n");
#         if lines[0].startswith("```") {
#             lines = lines[1:];
#         }
#         if lines and lines[-1].strip().startswith("```") {
#             lines = lines[:-1];
#         }
#         cleaned = "\n".join(lines).strip();
#     }
#     try {
#         return json.loads(cleaned);
#     } except Exception {
#         return [];
#     }
# }

# "Convert a raw dict from LLM into a GraphNode."
# def dict_to_graphnode(d: dict[str, object]) -> GraphNode {
#     nid = str(d.get("id", d.get("node_id", d.get("nodeId", "unknown"))));
#     nkind = str(d.get("kind", d.get("type", d.get("node_type", d.get("label", "claim")))));
#     ntext = str(d.get("text", d.get("content", d.get("description", ""))));
#     nparent = d.get("parent_id", d.get("parentId", d.get("parent", "")));
#     if nparent is None {
#         nparent = "";
#     }
#     nparent = str(nparent);

#     raw_conf = d.get("confidence", d.get("score", d.get("strength", 0.5)));
#     try {
#         nconf = float(raw_conf);
#     } except Exception {
#         nconf = 0.5;
#     }

#     nstatus = str(d.get("status", d.get("state", "needs_work")));

#     raw_issues = d.get("issues", d.get("problems", []));
#     issue_list: list[str] = [];
#     if raw_issues is None {
#         raw_issues = [];
#     }
#     if isinstance(raw_issues, str) and raw_issues {
#         issue_list = [s.strip() for s in raw_issues.split(",")];
#     } elif isinstance(raw_issues, list) {
#         issue_list = [str(i) for i in raw_issues];
#     }

#     raw_sugg = d.get("suggestions", d.get("actions", d.get("suggested_actions", [])));
#     sugg_list: list[str] = [];
#     if raw_sugg is None {
#         raw_sugg = [];
#     }
#     if isinstance(raw_sugg, str) and raw_sugg {
#         sugg_list = [s.strip() for s in raw_sugg.split(",")];
#     } elif isinstance(raw_sugg, list) {
#         sugg_list = [str(s) for s in raw_sugg];
#     }

#     gn = GraphNode(id=nid);
#     gn.label = nkind;
#     gn.text = ntext;
#     gn.parent_id = nparent;
#     gn.confidence = nconf;
#     gn.status = nstatus;
#     gn.issues = issue_list;
#     gn.suggestions = sugg_list;
#     return gn;
# }

# "Convert a raw dict from LLM into a GraphEdge."
# def dict_to_graphedge(d: dict[str, object]) -> GraphEdge {
#     efrom = str(d.get("from_id", d.get("fromId", d.get("from", d.get("source", "")))));
#     eto = str(d.get("to_id", d.get("toId", d.get("to", d.get("target", "")))));
#     ekind = str(d.get("kind", d.get("type", d.get("edge_type", d.get("label", d.get("relation", "supports"))))));
#     raw_w = d.get("weight", d.get("strength", d.get("score", 0.5)));
#     try {
#         ew = float(raw_w);
#     } except Exception {
#         ew = 0.5;
#     }
#     ge = GraphEdge(from_id=efrom, to_id=eto);
#     ge.label = ekind;
#     ge.weight = ew;
#     return ge;
# }


# # ============================================================
# # 4. NORMALIZERS
# # ============================================================

# "Normalize node labels and statuses to expected values."
# def normalize_nodes(nodes: list[GraphNode]) -> list[GraphNode] {
#     type_map: dict[str, str] = {
#         "thesis": "thesis", "claim": "claim",
#         "supportingclaim": "claim", "supporting_claim": "claim",
#         "sub_claim": "claim", "subclaim": "claim",
#         "evidence": "evidence", "document": "evidence",
#         "source": "evidence", "fact": "evidence", "statistic": "evidence",
#         "assumption": "assumption", "premise": "assumption",
#         "counterarg": "counterarg", "counterargument": "counterarg",
#         "counter_argument": "counterarg", "counter": "counterarg",
#         "rebuttal": "counterarg"
#     };
#     status_map: dict[str, str] = {
#         "ok": "ok", "valid": "ok", "strong": "ok",
#         "stable": "ok", "supported": "ok",
#         "needs_work": "needs_work", "weak": "needs_work",
#         "unsupported": "needs_work", "rebutted": "needs_work",
#         "missing": "missing", "none": "missing"
#     };
#     issue_map: dict[str, str] = {
#         "unsupported_claim": "unsupported_claim",
#         "missing_premise": "missing_premise",
#         "contradiction": "contradiction",
#         "vague_language": "vague_language",
#         "limited_support": "unsupported_claim",
#         "weak_support": "unsupported_claim",
#         "unclear_methodology": "vague_language",
#         "missing_evidence": "unsupported_claim",
#         "weak_inference": "missing_premise",
#         "ambiguity": "vague_language"
#     };

#     for n in nodes {
#         n.label = type_map.get(n.label.lower().strip(), "claim");
#         n.status = status_map.get(n.status.lower().strip(), "needs_work");
#         if not n.parent_id {
#             n.parent_id = "";
#         }
#         fixed: list[str] = [];
#         for iss in n.issues {
#             fixed.append(issue_map.get(iss.lower().strip(), iss.lower().strip()));
#         }
#         n.issues = fixed;
#     }
#     return nodes;
# }

# "Normalize edge labels to expected values."
# def normalize_edges(edges: list[GraphEdge]) -> list[GraphEdge] {
#     edge_map: dict[str, str] = {
#         "supports": "supports", "support": "supports",
#         "contradicts": "contradicts", "contradict": "contradicts",
#         "counterarguments": "contradicts", "counterargument": "contradicts",
#         "depends_on": "depends_on", "depends": "depends_on",
#         "addresses": "addresses", "address": "addresses",
#         "rebuts": "addresses", "rebuttal": "addresses"
#     };
#     for e in edges {
#         e.label = edge_map.get(e.label.lower().strip(), "supports");
#     }
#     return edges;
# }


# # ============================================================
# # 5. SCORING - Rule-based, NOT LLM
# # ============================================================

# "Calculate reasoning score from graph structure."
# def calculate_score(
#     nodes: list[GraphNode],
#     edges: list[GraphEdge]
# ) -> ReasoningScore {
#     claims: list[GraphNode] = [n for n in nodes if n.label in ["claim", "thesis"]];
#     total_claims = len(claims);

#     if total_claims == 0 {
#         return ReasoningScore();
#     }

#     supported_ids: list[str] = [];
#     for e in edges {
#         if e.label == "supports" {
#             supported_ids.append(e.to_id);
#         }
#     }
#     supported_claims = len([c for c in claims if c.id in supported_ids]);
#     support_pct = supported_claims / total_claims;

#     thesis_nodes = [n for n in nodes if n.label == "thesis"];
#     thesis_penalty = 0;
#     if thesis_nodes {
#         if thesis_nodes[0].id not in supported_ids {
#             thesis_penalty = 15;
#         }
#     }
#     support_score_val = max(0, int(support_pct * 100) - thesis_penalty);

#     claims_missing = len([c for c in claims if "missing_premise" in c.issues]);
#     premise_score_val = int((1 - claims_missing / total_claims) * 100);

#     counterargs = [n for n in nodes if n.label == "counterarg"];
#     total_contras = len(counterargs);
#     addressed_ids: list[str] = [];
#     for e in edges {
#         if e.label == "addresses" {
#             addressed_ids.append(e.to_id);
#         }
#     }

#     if total_contras > 0 {
#         unresolved = len([ca for ca in counterargs if ca.id not in addressed_ids]);
#         consistency_val = int((1 - unresolved / total_contras) * 100);
#     } else {
#         consistency_val = 100;
#     }

#     overall = int(0.4 * support_score_val + 0.4 * premise_score_val + 0.2 * consistency_val);

#     thesis_ok = len(thesis_nodes) > 0 and thesis_nodes[0].id in supported_ids;
#     unresolved_ct = len([ca for ca in counterargs if ca.id not in addressed_ids]);

#     return ReasoningScore(
#         overall=overall,
#         support_coverage=support_score_val,
#         premise_coverage=premise_score_val,
#         consistency=consistency_val,
#         passing=(overall >= 75 and thesis_ok and unresolved_ct <= 1)
#     );
# }


# # ============================================================
# # 6. MAIN PIPELINE
# # ============================================================

# "Run the full pipeline: notes in, structured graph out."
# def generate_argument_graph(
#     raw_text: str,
#     documents: list[Document] = [],
#     existing_nodes: list[GraphNode] = [],
#     existing_edges: list[GraphEdge] = []
# ) -> dict[str, object] {

#     # Step 1: Parse notes into nodes
#     print("  Step 1/5: Parsing notes into nodes...");
#     raw_json = parse_notes_to_nodes(raw_text, documents);
#     raw_list = safe_parse_json(raw_json);
#     new_nodes: list[GraphNode] = [];
#     for rd in raw_list {
#         if isinstance(rd, dict) {
#             new_nodes.append(dict_to_graphnode(rd));
#         }
#     }
#     new_nodes = normalize_nodes(new_nodes);
#     all_nodes = existing_nodes + new_nodes;

#     # Step 2: Generate edges
#     print("  Step 2/5: Generating edges...");
#     nj = json.dumps([{"id": n.id, "kind": n.label, "text": n.text, "parent_id": n.parent_id} for n in all_nodes]);
#     raw_ej = generate_edges(nj);
#     raw_el = safe_parse_json(raw_ej);
#     new_edges: list[GraphEdge] = [];
#     for rd in raw_el {
#         if isinstance(rd, dict) {
#             new_edges.append(dict_to_graphedge(rd));
#         }
#     }
#     new_edges = normalize_edges(new_edges);
#     all_edges = existing_edges + new_edges;

#     # Step 3: Deep per-node analysis
#     print("  Step 3/5: Deep analysis per node...");
#     parent_map: dict[str, str] = {};
#     children_map: dict[str, list[str]] = {};
#     for e in all_edges {
#         if e.label in ["supports", "depends_on"] {
#             parent_map[e.from_id] = e.to_id;
#             if e.to_id not in children_map {
#                 children_map[e.to_id] = [];
#             }
#             children_map[e.to_id].append(e.from_id);
#         }
#     }

#     node_lookup: dict[str, dict[str, str]] = {};
#     for n in all_nodes {
#         node_lookup[n.id] = {"id": n.id, "kind": n.label, "text": n.text,
#                              "parent_id": n.parent_id, "confidence": str(n.confidence),
#                              "status": n.status};
#     }

#     analysis_dicts: list[dict[str, str]] = [];
#     for n in all_nodes {
#         # Build context JSONs
#         parent_list: list[dict[str, str]] = [];
#         if n.id in parent_map {
#             pid = parent_map[n.id];
#             if pid in node_lookup {
#                 parent_list.append(node_lookup[pid]);
#             }
#         }
#         child_list: list[dict[str, str]] = [];
#         if n.id in children_map {
#             for cid in children_map[n.id] {
#                 if cid in node_lookup {
#                     child_list.append(node_lookup[cid]);
#                 }
#             }
#         }
#         sibling_list: list[dict[str, str]] = [];
#         if n.id in parent_map {
#             pid = parent_map[n.id];
#             if pid in children_map {
#                 for sid in children_map[pid] {
#                     if sid != n.id and sid in node_lookup {
#                         sibling_list.append(node_lookup[sid]);
#                     }
#                 }
#             }
#         }
#         doc_list: list[dict[str, str]] = [];
#         for doc in documents {
#             doc_list.append({"title": doc.title, "content": doc.content});
#         }

#         print(f"    [{n.label}] {n.text[:45]}...");
#         raw_analysis = analyze_node_deep_llm(
#             json.dumps(node_lookup[n.id]),
#             json.dumps(parent_list),
#             json.dumps(child_list),
#             json.dumps(sibling_list),
#             json.dumps(doc_list)
#         );
#         parsed = safe_parse_json(raw_analysis);
#         if not isinstance(parsed, dict) {
#             parsed = {};
#         }

#         # Convert issues list to delimited string
#         raw_iss = parsed.get("issues", []);
#         iss_parts: list[str] = [];
#         if isinstance(raw_iss, list) {
#             for ri in raw_iss {
#                 if isinstance(ri, dict) {
#                     iss_parts.append(
#                         str(ri.get("title", "")) + "|||" +
#                         str(ri.get("context", "")) + "|||" +
#                         str(ri.get("related_source", ""))
#                     );
#                 } elif isinstance(ri, str) {
#                     iss_parts.append(ri + "|||" + "|||");
#                 }
#             }
#         }

#         # Convert suggestions
#         raw_sg = parsed.get("suggestions", []);
#         sg_parts: list[str] = [];
#         if isinstance(raw_sg, list) {
#             for rs in raw_sg {
#                 if isinstance(rs, dict) {
#                     sg_parts.append(
#                         str(rs.get("action", "")) + "|||" +
#                         str(rs.get("detail", "")) + "|||" +
#                         str(rs.get("source_hint", ""))
#                     );
#                 } elif isinstance(rs, str) {
#                     sg_parts.append(rs + "|||" + "|||");
#                 }
#             }
#         }

#         # Convert further reading
#         raw_rd = parsed.get("further_reading", []);
#         rd_parts: list[str] = [];
#         if isinstance(raw_rd, list) {
#             for rr in raw_rd {
#                 if isinstance(rr, dict) {
#                     rd_parts.append(
#                         str(rr.get("title", "")) + "|||" +
#                         str(rr.get("why", "")) + "|||" +
#                         str(rr.get("search_query", ""))
#                     );
#                 } elif isinstance(rr, str) {
#                     rd_parts.append(rr + "|||" + "|||");
#                 }
#             }
#         }

#         ad: dict[str, str] = {
#             "node_id": n.id,
#             "strength_label": str(parsed.get("strength_label", "")),
#             "issues": ";;;".join(iss_parts),
#             "suggestions": ";;;".join(sg_parts),
#             "further_reading": ";;;".join(rd_parts),
#             "logical_concept": str(parsed.get("logical_concept", "")),
#             "concept_term": str(parsed.get("concept_term", "")),
#             "concept_definition": str(parsed.get("concept_definition", "")),
#             "concept_how_to_use": str(parsed.get("concept_how_to_use", "")),
#             "concept_example": str(parsed.get("concept_example", ""))
#         };
#         analysis_dicts.append(ad);
#     }

#     # Step 4: Calculate score (rule-based)
#     print("  Step 4/5: Calculating score...");
#     score = calculate_score(all_nodes, all_edges);

#     # Step 5: Summarize via LLM
#     print("  Step 5/5: Generating summary...");
#     ej = json.dumps([{"from_id": e.from_id, "to_id": e.to_id, "kind": e.label, "weight": e.weight} for e in all_edges]);
#     raw_sj = summarize_graph_llm(nj, ej, "[]");
#     raw_s = safe_parse_json(raw_sj);
#     summary = GraphSummary();
#     if isinstance(raw_s, dict) {
#         summary.top_issues = raw_s.get("top_issues", []);
#         summary.strength_nodes = raw_s.get("strength_nodes", []);
#         summary.improvement_nodes = raw_s.get("improvement_nodes", []);
#     }

#     # Build output dicts
#     node_dicts: list[dict[str, str]] = [];
#     for n in all_nodes {
#         nd: dict[str, str] = {
#             "id": n.id, "type": n.label, "text": n.text,
#             "parent_id": n.parent_id, "confidence": str(n.confidence),
#             "status": n.status, "issues": ",".join(n.issues),
#             "suggestions": ",".join(n.suggestions)
#         };
#         node_dicts.append(nd);
#     }

#     edge_dicts: list[dict[str, str]] = [];
#     for e in all_edges {
#         ed: dict[str, str] = {
#             "from_id": e.from_id, "to_id": e.to_id,
#             "type": e.label, "weight": str(e.weight)
#         };
#         edge_dicts.append(ed);
#     }

#     return {
#         "nodes": node_dicts,
#         "edges": edge_dicts,
#         "analyses": analysis_dicts,
#         "reasoning_score": {
#             "overall": str(score.overall),
#             "support_coverage": str(score.support_coverage),
#             "premise_coverage": str(score.premise_coverage),
#             "consistency": str(score.consistency),
#             "passing": str(score.passing)
#         },
#         "summary": {
#             "top_issues": summary.top_issues,
#             "strength_nodes": summary.strength_nodes,
#             "improvement_nodes": summary.improvement_nodes
#         }
#     };
# }


# # ============================================================
# # 7. ENTRY POINT
# # ============================================================

# with entry {
#     test_notes = "Climate change is primarily caused by human activities. "
#                  "Burning fossil fuels releases CO2 into the atmosphere. "
#                  "Some scientists argue that natural cycles also play a role. "
#                  "The Paris Agreement aims to limit warming to 1.5 degrees. "
#                  "However, many countries are not meeting their targets. "
#                  "Renewable energy is growing but not fast enough.";

#     test_docs = [
#         Document(
#             title="IPCC Report 2023",
#             content="Human activities have unequivocally caused global warming."
#         )
#     ];

#     print("=== Juncture Graph Generator ===");
#     print("Processing notes...\n");

#     result = generate_argument_graph(test_notes, test_docs);

#     with open("graph_output.json", "w") as f {
#         json.dump(result, f, indent=2);
#     }

#     print("--- NODES ---");
#     for n in result.get("nodes", []) {
#         print(f"  [{n.get('type', '')}] {n.get('text', '')} "
#               f"(conf: {n.get('confidence', '')}, status: {n.get('status', '')})"
#               f"{' issues: ' + n.get('issues', '') if n.get('issues', '') else ''}");
#     }

#     print("\n--- EDGES ---");
#     for e in result.get("edges", []) {
#         print(f"  {e.get('from_id', '')} --{e.get('type', '')}--> "
#               f"{e.get('to_id', '')} (weight: {e.get('weight', '')})");
#     }

#     s = result.get("reasoning_score", {});
#     print(f"\n--- SCORE ---");
#     print(f"  Overall: {s.get('overall', '0')}");
#     print(f"  Support: {s.get('support_coverage', '0')}");
#     print(f"  Premise: {s.get('premise_coverage', '0')}");
#     print(f"  Consistency: {s.get('consistency', '0')}");
#     print(f"  Passing: {s.get('passing', 'False')}");

#     print("\n--- TOP ISSUES ---");
#     for issue in result.get("summary", {}).get("top_issues", []) {
#         print(f"  - {issue}");
#     }

#     print(f"\nSaved to graph_output.json");
#     print("Done!");
# }
"""Juncture - Graph Generator Pipeline.
Takes raw user notes/uploads, processes through LLM,
outputs structured argument map with scoring.

Place this file at: src/graph_generator.jac
"""

import json;

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

obj CritiqueResult {
    has raw: str = "";
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
# 2. LLM FUNCTIONS - All return raw JSON strings
# ============================================================

"""Parse raw unstructured notes into a JSON list of node objects.
Each node must have: id (like node_1), kind (thesis/claim/evidence/assumption/counterarg),
text (one short sentence), parent_id (string or null), confidence (0.0-1.0),
status (ok/needs_work/missing), issues (list of strings), suggestions (list of strings)."""
def parse_notes_to_nodes(
    notes: str,
    documents: list[Document]
) -> str
by llm();

"""Given nodes as JSON, return a JSON list of edge objects.
Each edge must have: from_id, to_id, kind (supports/contradicts/depends_on/addresses), weight (0.0-1.0)."""
def generate_edges(
    nodes_json: str
) -> str
by llm();

"""Given nodes and edges as JSON, return a JSON object with:
critiques (list of {node_id, severity, issues}),
suggested_actions (list of {node_id, action, example_prompt})."""
def critique_graph_llm(
    nodes_json: str,
    edges_json: str
) -> str
by llm();

"""Given nodes, edges, and critiques as JSON, return a JSON object with:
top_issues (3 strings), strength_nodes (list of node ids), improvement_nodes (list of node ids)."""
def summarize_graph_llm(
    nodes_json: str,
    edges_json: str,
    critiques_json: str
) -> str
by llm();

"""Perform deep analysis on ALL nodes at once in a single batch call.
You are given all nodes, all edges, and all source documents as JSON.
Return a JSON list where each item has:
- node_id: the id of the node being analyzed
- strength_label: one of "well-supported", "needs-evidence", "weak", "contradicted"
- issues: list of {title, context, related_source} where title is a short problem name,
  context explains WHY it matters referencing specific other nodes or sources by name,
  related_source is the filename of a relevant source document if any
- suggestions: list of {action, detail, source_hint} where action is a short label like
  "Add longitudinal study" or "Critique sample demographics", detail explains how,
  source_hint describes what kind of source to look for
- further_reading: list of {title, why, search_query} where title describes what to find,
  why explains the value, search_query is a Google Scholar search string
- logical_concept: name of a relevant logical concept or empty string
- concept_term: formal name or empty string
- concept_definition: plain language definition or empty string
- concept_how_to_use: when and how to apply it or empty string
- concept_example: a concrete everyday example or empty string
Be thorough and specific for EVERY node. Reference actual node text and source titles."""
def analyze_all_nodes_llm(
    all_nodes_json: str,
    all_edges_json: str,
    sources_json: str
) -> str
by llm(temperature=0.3);


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
# 6. MAIN PIPELINE
# ============================================================

"Run the full pipeline: notes in, structured graph out."
def generate_argument_graph(
    raw_text: str,
    documents: list[Document] = [],
    existing_nodes: list[GraphNode] = [],
    existing_edges: list[GraphEdge] = []
) -> dict[str, object] {

    # Step 1: Parse notes into nodes
    print("  Step 1/5: Parsing notes into nodes...");
    raw_json = parse_notes_to_nodes(raw_text, documents);
    raw_list = safe_parse_json(raw_json);
    new_nodes: list[GraphNode] = [];
    for rd in raw_list {
        if isinstance(rd, dict) {
            new_nodes.append(dict_to_graphnode(rd));
        }
    }
    new_nodes = normalize_nodes(new_nodes);
    all_nodes = existing_nodes + new_nodes;

    # Step 2: Generate edges
    print("  Step 2/5: Generating edges...");
    nj = json.dumps([{"id": n.id, "kind": n.label, "text": n.text, "parent_id": n.parent_id} for n in all_nodes]);
    raw_ej = generate_edges(nj);
    raw_el = safe_parse_json(raw_ej);
    new_edges: list[GraphEdge] = [];
    for rd in raw_el {
        if isinstance(rd, dict) {
            new_edges.append(dict_to_graphedge(rd));
        }
    }
    new_edges = normalize_edges(new_edges);
    all_edges = existing_edges + new_edges;

    # Step 3: Deep analysis — single batch LLM call for all nodes
    print("  Step 3/5: Deep analysis (batch)...");
    doc_list: list[dict[str, str]] = [];
    for doc in documents {
        doc_list.append({"title": doc.title, "content": doc.content});
    }

    raw_analyses = analyze_all_nodes_llm(nj, ej, json.dumps(doc_list));
    parsed_analyses = safe_parse_json(raw_analyses);

    analysis_dicts: list[dict[str, str]] = [];
    if isinstance(parsed_analyses, list) {
        for parsed in parsed_analyses {
            if not isinstance(parsed, dict) {
                continue;
            }
            # Convert issues list to delimited string
            raw_iss = parsed.get("issues", []);
            iss_parts: list[str] = [];
            if isinstance(raw_iss, list) {
                for ri in raw_iss {
                    if isinstance(ri, dict) {
                        iss_parts.append(
                            str(ri.get("title", "")) + "|||" +
                            str(ri.get("context", "")) + "|||" +
                            str(ri.get("related_source", ""))
                        );
                    } elif isinstance(ri, str) {
                        iss_parts.append(ri + "||||||");
                    }
                }
            }
            # Convert suggestions
            raw_sg = parsed.get("suggestions", []);
            sg_parts: list[str] = [];
            if isinstance(raw_sg, list) {
                for rs in raw_sg {
                    if isinstance(rs, dict) {
                        sg_parts.append(
                            str(rs.get("action", "")) + "|||" +
                            str(rs.get("detail", "")) + "|||" +
                            str(rs.get("source_hint", ""))
                        );
                    } elif isinstance(rs, str) {
                        sg_parts.append(rs + "||||||");
                    }
                }
            }
            # Convert further reading
            raw_rd = parsed.get("further_reading", []);
            rd_parts: list[str] = [];
            if isinstance(raw_rd, list) {
                for rr in raw_rd {
                    if isinstance(rr, dict) {
                        rd_parts.append(
                            str(rr.get("title", "")) + "|||" +
                            str(rr.get("why", "")) + "|||" +
                            str(rr.get("search_query", ""))
                        );
                    } elif isinstance(rr, str) {
                        rd_parts.append(rr + "||||||");
                    }
                }
            }

            ad: dict[str, str] = {
                "node_id": str(parsed.get("node_id", "")),
                "strength_label": str(parsed.get("strength_label", "")),
                "issues": ";;;".join(iss_parts),
                "suggestions": ";;;".join(sg_parts),
                "further_reading": ";;;".join(rd_parts),
                "logical_concept": str(parsed.get("logical_concept", "")),
                "concept_term": str(parsed.get("concept_term", "")),
                "concept_definition": str(parsed.get("concept_definition", "")),
                "concept_how_to_use": str(parsed.get("concept_how_to_use", "")),
                "concept_example": str(parsed.get("concept_example", ""))
            };
            analysis_dicts.append(ad);
        }
    }

    # Step 4: Calculate score (rule-based)
    print("  Step 4/5: Calculating score...");
    score = calculate_score(all_nodes, all_edges);

    # Step 5: Summarize via LLM
    print("  Step 5/5: Generating summary...");
    ej = json.dumps([{"from_id": e.from_id, "to_id": e.to_id, "kind": e.label, "weight": e.weight} for e in all_edges]);
    raw_sj = summarize_graph_llm(nj, ej, "[]");
    raw_s = safe_parse_json(raw_sj);
    summary = GraphSummary();
    if isinstance(raw_s, dict) {
        summary.top_issues = raw_s.get("top_issues", []);
        summary.strength_nodes = raw_s.get("strength_nodes", []);
        summary.improvement_nodes = raw_s.get("improvement_nodes", []);
    }

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


# ============================================================
# 7. ENTRY POINT - Use `jac run src/test_generator.jac` to test
# ============================================================

# Removed `with entry` block so importing this file
# doesn't trigger the LLM pipeline.
# To test standalone, run: jac run src/test_generator.jac