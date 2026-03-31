"""Walkers for generating and scoring argument graphs."""

import from graph.argument_graph_nodes { ArgumentGraph }
import from src.graph_generator { Document, generate_argument_graph }

walker:pub GenerateArgumentGraph {
    has notes: str,
        userId: str;

    can run with Root entry {
        print("=== GenerateArgumentGraph ENTERED ===");
        print(f"=== userId={self.userId}, notes length={len(self.notes)} ===");
        try {
        import time;
        graph_id = f"graph_{int(time.time())}";

        docs: list[Document] = [];
        # Retry up to 2 times if LLM returns empty
        result = generate_argument_graph(self.notes, docs);
        result_nodes = result["nodes"] if "nodes" in result else [];
        print(f"  [First attempt] Got {len(result_nodes)} nodes");
        if not result_nodes or len(result_nodes) == 0 {
            print("  [RETRY] LLM returned empty, retrying...");
            result = generate_argument_graph(self.notes, docs);
            result_nodes = result["nodes"] if "nodes" in result else [];
            print(f"  [Retry] Got {len(result_nodes)} nodes");
        }
        raw_nodes = result["nodes"] if "nodes" in result else [];
        raw_edges = result["edges"] if "edges" in result else [];

        type_map: dict[str, str] = {
            "thesis": "THESIS",
            "claim": "CLAIM",
            "evidence": "EVIDENCE",
            "assumption": "EVIDENCE",
            "counterarg": "COUNTERARGUMENT"
        };
        edge_type_map: dict[str, str] = {
            "supports": "SUPPORTS",
            "contradicts": "CONTRADICTS",
            "depends_on": "SUPPORTS",
            "addresses": "ADDRESSES"
        };

        parent_map: dict[str, str] = {};
        children_map: dict[str, list[str]] = {};
        for e in raw_edges {
            etype = e.get("type", "").lower();
            if etype in ["supports", "depends_on", "addresses"] {
                fid = e.get("from_id", "");
                tid = e.get("to_id", "");
                parent_map[fid] = tid;
                if tid not in children_map {
                    children_map[tid] = [];
                }
                children_map[tid].append(fid);
            }
        }

        all_ids = [n.get("id", "") for n in raw_nodes];
        has_parent_set = set(parent_map.keys());
        root_ids = [nid for nid in all_ids if nid not in has_parent_set];
        if not root_ids and all_ids {
            root_ids = [all_ids[0]];
        }

        level_map: dict[str, int] = {};
        bfs_q: list[str] = [];
        for rid in root_ids {
            bfs_q.append(rid);
            level_map[rid] = 0;
        }
        while bfs_q {
            cur = bfs_q.pop(0);
            for ch in children_map.get(cur, []) {
                if ch not in level_map {
                    level_map[ch] = level_map[cur] + 1;
                    bfs_q.append(ch);
                }
            }
        }
        for nid in all_ids {
            if nid not in level_map {
                level_map[nid] = 0;
            }
        }

        levels: dict[int, list[str]] = {};
        for nid in all_ids {
            lvl = level_map[nid];
            if lvl not in levels {
                levels[lvl] = [];
            }
            levels[lvl].append(nid);
        }

        fe_nodes: list[dict] = [];
        for n in raw_nodes {
            nid = n.get("id", "");
            lvl = level_map.get(nid, 0);
            ns_at_level = levels.get(lvl, [nid]);
            idx_in_level = ns_at_level.index(nid) if nid in ns_at_level else 0;
            spacing = 280;
            x_pos = 250 + (idx_in_level - (len(ns_at_level) - 1) / 2.0) * spacing;
            y_pos = 50 + lvl * 200;

            raw_type = n.get("type", "claim").lower();
            fe_type = type_map.get(raw_type, "CLAIM");

            llm_issue_types: list[str] = [];
            raw_issues = n.get("issues", "");
            if isinstance(raw_issues, list) {
                for iss in raw_issues {
                    stripped = str(iss).strip().lower();
                    if stripped {
                        llm_issue_types.append(stripped);
                    }
                }
            } elif raw_issues {
                for iss in str(raw_issues).split(",") {
                    stripped = iss.strip().lower();
                    if stripped {
                        llm_issue_types.append(stripped);
                    }
                }
            }

            conf = 0.5;
            try {
                conf = float(n.get("confidence", "0.5"));
            } except Exception {
                conf = 0.5;
            }

            # Extract evidence_category and assumptions
            ev_cat = n.get("evidence_category", "");
            if not ev_cat and fe_type == "EVIDENCE" {
                ev_cat = "logical_reasoning";
            }
            node_assumptions = n.get("assumptions", []);
            if not isinstance(node_assumptions, list) {
                node_assumptions = [];
            }
            # Capitalize each assumption
            capped_assumptions: list = [];
            for assumption in node_assumptions {
                capped_assumptions.append(self.capitalize_text(str(assumption)));
            }

            fe_nodes.append({
                "id": nid,
                "type": fe_type,
                "content": self.capitalize_text(n.get("text", "")),
                "confidence": conf,
                "isWeak": conf < 0.5,
                "issues": [],
                "llmIssueTypes": llm_issue_types,
                "position": {"x": x_pos, "y": y_pos},
                "evidence_category": ev_cat,
                "assumptions": capped_assumptions,
                "nodeScore": 50
            });
        }

        fe_edges: list[dict] = [];
        for (i, e) in enumerate(raw_edges) {
            raw_etype = e.get("type", "supports").lower();
            fe_etype = edge_type_map.get(raw_etype, "SUPPORTS");
            e_weight = 0.5;
            try {
                e_weight = float(e.get("weight", "0.5"));
            } except Exception {
                e_weight = 0.5;
            }
            e_reasoning = e.get("reasoning_type", "inductive");
            if not e_reasoning { e_reasoning = "inductive"; }
            fe_edges.append({
                "id": f"edge_{i+1}",
                "source": e.get("from_id", ""),
                "target": e.get("to_id", ""),
                "type": fe_etype,
                "weight": e_weight,
                "reasoning_type": e_reasoning
            });
        }

        new_graph = (root ++> ArgumentGraph(
            id=graph_id,
            nodes=fe_nodes,
            edges=fe_edges,
            createdAt=str(int(time.time())),
            updatedAt=str(int(time.time()))
        ))[0];
        summary = result.get("summary", {});
        suggested_counterargs = summary.get("suggested_counterarguments", []);

        scorer = GetGraphWithScoring(graphId=graph_id);
        scored_data = scorer.score_graph(new_graph);
        if "error" in scored_data {
            report {"error": scored_data["error"]};
            return;
        }

        report {
            "graph": scored_data.get("graph", {
                "id": graph_id,
                "nodes": fe_nodes,
                "edges": fe_edges,
                "createdAt": new_graph.createdAt,
                "updatedAt": new_graph.updatedAt
            }),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", []),
            "suggested_counterarguments": suggested_counterargs
        };
        } except Exception as e {
            print(f"=== GenerateArgumentGraph ERROR: {e} ===");
            report {"error": str(e)};
        }
    }

    def capitalize_text(text: str) -> str {
        """Sentence-case: capitalize first letter of each sentence."""
        result = text;
        if len(text) > 0 {
            sentences = text.split(". ");
            result_parts: list = [];
            for s in sentences {
                trimmed = s.strip();
                if len(trimmed) > 1 {
                    capped = trimmed[0].upper() + trimmed[1:];
                    result_parts.append(capped);
                } elif len(trimmed) == 1 {
                    result_parts.append(trimmed[0].upper());
                } else {
                    result_parts.append(trimmed);
                }
            }
            result = ". ".join(result_parts);
        } else {
            result = text;
        }
        return result;
    }
}

walker:pub GetGraphWithScoring {
    has graphId: str;

    can run with Root entry {
        graph_node = None;
        for graph in [-->](?:ArgumentGraph) {
            if graph.id == self.graphId {
                graph_node = graph;
                break;
            }
        }

        if not graph_node {
            report {"error": "Graph not found"};
            return;
        }

        score = self.calculate_score(graph_node.nodes, graph_node.edges);
        issues = self.identify_issues(graph_node.nodes, graph_node.edges, score);
        next_actions = self.build_next_actions(issues);
        self.annotate_nodes(graph_node.nodes, graph_node.edges, issues);

        report {
            "graph": {
                "id": graph_node.id,
                "nodes": graph_node.nodes,
                "edges": graph_node.edges,
                "createdAt": graph_node.createdAt,
                "updatedAt": graph_node.updatedAt
            },
            "score": score,
            "issues": issues,
            "nextActions": next_actions
        };
    }

    def score_graph(graph_node: obj) -> dict {
        nodes = graph_node.nodes;
        edges = graph_node.edges;
        score = self.calculate_score(nodes, edges);
        issues = self.identify_issues(nodes, edges, score);
        next_actions = self.build_next_actions(issues);
        self.annotate_nodes(nodes, edges, issues);
        return {
            "graph": {
                "id": graph_node.id,
                "nodes": graph_node.nodes,
                "edges": graph_node.edges,
                "createdAt": graph_node.createdAt,
                "updatedAt": graph_node.updatedAt
            },
            "score": score,
            "issues": issues,
            "nextActions": next_actions
        };
    }

    def get_node(nodes: list, node_id: str) -> dict {
        for n in nodes {
            if n.get("id", "") == node_id {
                return n;
            }
        }
        return None;
    }

    def get_claims(nodes: list) -> list {
        return [n for n in nodes if n.get("type", "") in ["CLAIM", "THESIS"]];
    }

    def clamp01(val: float) -> float {
        v = val;
        if v < 0.0 { v = 0.0; }
        if v > 1.0 { v = 1.0; }
        return v;
    }

    def to_float(val: any, default_val: float = 0.0) -> float {
        try {
            return float(val);
        } except Exception {
            return default_val;
        }
    }

    def is_acknowledged(node_data: dict) -> bool {
        if not node_data { return False; }
        ack = node_data.get("acknowledged", False);
        if isinstance(ack, str) {
            return ack.lower() == "true";
        }
        return bool(ack);
    }

    def has_issue_type(node_data: dict, issue_type: str) -> bool {
        if not node_data { return False; }
        target = issue_type.lower().strip();

        llm_issue_types = node_data.get("llmIssueTypes", []);
        if isinstance(llm_issue_types, str) and llm_issue_types {
            llm_issue_types = [s.strip() for s in llm_issue_types.split(",")];
        }
        if isinstance(llm_issue_types, list) {
            for it in llm_issue_types {
                if str(it).lower().strip() == target {
                    return True;
                }
            }
        }

        node_issues = node_data.get("issues", []);
        if isinstance(node_issues, str) and node_issues {
            for s in node_issues.split(",") {
                if s.lower().strip() == target {
                    return True;
                }
            }
        } elif isinstance(node_issues, list) {
            for iss in node_issues {
                if isinstance(iss, dict) {
                    iss_type = iss.get("type", "");
                    if str(iss_type).lower().strip() == target {
                        return True;
                    }
                } elif str(iss).lower().strip() == target {
                    return True;
                }
            }
        }
        return False;
    }

    def edge_weight(edge_data: dict) -> float {
        w = self.to_float(edge_data.get("weight", 0.5), 0.5);
        return self.clamp01(w);
    }

    def evidence_quality(node_data: dict) -> float {
        if not node_data { return 0.0; }
        if node_data.get("type", "") != "EVIDENCE" {
            return 0.0;
        }

        cat_weights: dict[str, float] = {
            "empirical_data": 0.92,
            "expert_testimony": 0.82,
            "logical_reasoning": 0.65,
            "analogy": 0.52,
            "anecdotal": 0.38
        };
        ev_cat = str(node_data.get("evidence_category", "logical_reasoning")).lower().strip();
        base = cat_weights.get(ev_cat, 0.65);

        conf = self.to_float(node_data.get("confidence", 0.5), 0.5);
        conf = self.clamp01(conf);

        assumptions = node_data.get("assumptions", []);
        assumption_count = len(assumptions) if isinstance(assumptions, list) else 0;
        assumption_penalty = min(0.25, assumption_count * 0.05);

        source_url = str(node_data.get("sourceUrl", "")).strip();
        source_bonus = 0.08 if source_url else 0.0;

        quality = base * 0.55 + conf * 0.45 + source_bonus - assumption_penalty;
        return self.clamp01(quality);
    }

    def find_weak_nodes(nodes: list, edges: list) -> list {
        """Find all weak node IDs via evidence quality + upward propagation."""
        weak_ids: list[str] = [];

        # Evidence with low quality
        for n in nodes {
            if n.get("type", "") == "EVIDENCE" {
                eq = self.evidence_quality(n);
                if eq < 0.4 and n.get("id", "") not in weak_ids {
                    weak_ids.append(n.get("id", ""));
                }
            }
        }

        # Nodes with low confidence
        for n in nodes {
            conf = self.to_float(n.get("confidence", 0.5), 0.5);
            if conf < 0.4 and n.get("id", "") not in weak_ids {
                weak_ids.append(n.get("id", ""));
            }
        }

        # Propagate upward: if ALL supporters of a node are weak, it's weak too
        changed = True;
        max_iters = 10;
        iter_count = 0;
        while changed and iter_count < max_iters {
            changed = False;
            iter_count = iter_count + 1;
            for e in edges {
                src = e.get("source", "");
                tgt = e.get("target", "");
                etype = e.get("type", "");
                if etype == "SUPPORTS" and src in weak_ids and tgt not in weak_ids {
                    all_sup: list[str] = [];
                    for e2 in edges {
                        if e2.get("target", "") == tgt and e2.get("type", "") == "SUPPORTS" {
                            all_sup.append(e2.get("source", ""));
                        }
                    }
                    all_weak = True;
                    for sid in all_sup {
                        if sid not in weak_ids {
                            all_weak = False;
                            break;
                        }
                    }
                    if all_weak and len(all_sup) > 0 {
                        weak_ids.append(tgt);
                        changed = True;
                    }
                }
            }
        }
        return weak_ids;
    }

    def has_evidence_support(nodes: list, edges: list, claim_id: str) -> bool {
        for e in edges {
            if e.get("type", "") == "SUPPORTS" and e.get("target", "") == claim_id {
                src_id = e.get("source", "");
                src_node = self.get_node(nodes, src_id);
                if src_node and src_node.get("type", "") == "EVIDENCE" {
                    return True;
                }
            }
        }
        return False;
    }

    def claim_support_score(nodes: list, edges: list, claim_id: str) -> float {
        total_support = 0.0;
        evidence_count = 0;
        for e in edges {
            if e.get("type", "") == "SUPPORTS" and e.get("target", "") == claim_id {
                src_node = self.get_node(nodes, e.get("source", ""));
                if src_node and src_node.get("type", "") == "EVIDENCE" {
                    evidence_count = evidence_count + 1;
                    total_support = total_support + self.edge_weight(e) * self.evidence_quality(src_node);
                }
            }
        }
        if evidence_count == 0 {
            return 0.0;
        }
        if total_support > 1.0 { total_support = 1.0; }
        return self.clamp01(total_support);
    }

    def has_assumption(nodes: list, edges: list, claim_id: str) -> bool {
        """Check if a claim has assumptions — looks at supporting evidence nodes' assumptions lists."""
        for e in edges {
            if e.get("type", "") == "SUPPORTS" and e.get("target", "") == claim_id {
                src_node = self.get_node(nodes, e.get("source", ""));
                if src_node and src_node.get("type", "") == "EVIDENCE" {
                    assumptions = src_node.get("assumptions", []);
                    if isinstance(assumptions, list) and len(assumptions) > 0 {
                        return True;
                    }
                }
            }
        }
        return False;
    }

    def node_degree(edges: list, node_id: str) -> int {
        deg = 0;
        for e in edges {
            if e.get("source", "") == node_id or e.get("target", "") == node_id {
                deg = deg + 1;
            }
        }
        return deg;
    }

    def claim_connected_to_thesis(nodes: list, edges: list, claim_id: str, thesis_ids: list) -> bool {
        if claim_id in thesis_ids {
            return True;
        }
        if len(thesis_ids) == 0 {
            return True;
        }

        visited: list[str] = [claim_id];
        queue: list[str] = [claim_id];
        qi = 0;
        while qi < len(queue) {
            cur = queue[qi];
            if cur in thesis_ids {
                return True;
            }

            for e in edges {
                et = e.get("type", "");
                if et not in ["SUPPORTS", "ADDRESSES", "CONTRADICTS"] {
                    continue;
                }
                nxt = "";
                if e.get("source", "") == cur {
                    nxt = e.get("target", "");
                } elif e.get("target", "") == cur {
                    nxt = e.get("source", "");
                }
                if nxt and nxt not in visited {
                    visited.append(nxt);
                    queue.append(nxt);
                }
            }
            qi = qi + 1;
        }
        return False;
    }

    def contradiction_unresolved(nodes: list, edges: list, contradiction_edge: dict) -> bool {
        src_id = contradiction_edge.get("source", "");
        tgt_id = contradiction_edge.get("target", "");
        src_node = self.get_node(nodes, src_id);
        tgt_node = self.get_node(nodes, tgt_id);

        if self.is_acknowledged(src_node) or self.is_acknowledged(tgt_node) {
            return False;
        }

        for e in edges {
            if e.get("type", "") == "ADDRESSES" {
                addr_target = e.get("target", "");
                if addr_target == src_id or addr_target == tgt_id {
                    return False;
                }
            }
        }
        return True;
    }

    def get_thesis_ids(nodes: list, edges: list) -> list {
        thesis_nodes = [n for n in nodes if n.get("type", "") == "THESIS"];
        if len(thesis_nodes) > 0 {
            return [n.get("id", "") for n in thesis_nodes[:2]];
        }

        claims = [n for n in nodes if n.get("type", "") == "CLAIM"];
        if len(claims) == 0 {
            return [];
        }

        roots: list[str] = [];
        for c in claims {
            cid = c.get("id", "");
            supports_parent_claim = False;
            for e in edges {
                if e.get("type", "") == "SUPPORTS" and e.get("source", "") == cid {
                    target_node = self.get_node(nodes, e.get("target", ""));
                    if target_node and target_node.get("type", "") in ["CLAIM", "THESIS"] {
                        supports_parent_claim = True;
                        break;
                    }
                }
            }
            if not supports_parent_claim {
                roots.append(cid);
            }
        }

        if len(roots) == 0 {
            roots = [claims[0].get("id", "")];
        }
        return roots[:2];
    }

    def calculate_score(nodes: list, edges: list) -> dict {
        claims = self.get_claims(nodes);
        total_claims = len(claims);
        total_nodes = len(nodes);

        thesis_ids = self.get_thesis_ids(nodes, edges);
        contradictions = [e for e in edges if e.get("type", "") == "CONTRADICTS"];
        total_contradictions = len(contradictions);
        unresolved_contradictions = 0;
        for ce in contradictions {
            if self.contradiction_unresolved(nodes, edges, ce) {
                unresolved_contradictions = unresolved_contradictions + 1;
            }
        }

        if total_claims == 0 or total_nodes == 0 {
            return {
                "overall": 0,
                "support": 0,
                "premise": 0,
                "coherence": 0,
                "counterargument": 0,
                "consistency": 0,
                "unsupportedClaims": 0,
                "claimsNeedingPremise": 0,
                "unresolvedContradictions": unresolved_contradictions,
                "weakInferenceClaims": 0,
                "vagueClaims": 0,
                "orphanNodes": 0,
                "disconnectedClaims": 0,
                "thesisSupported": False,
                "passesBar": False
            };
        }

        # 1) Support Quality (30%)
        support_sum = 0.0;
        unsupported_claims = 0;
        thesis_supported = True;
        if len(thesis_ids) == 0 {
            thesis_supported = False;
        }
        for c in claims {
            cid = c.get("id", "");
            c_support = self.claim_support_score(nodes, edges, cid);
            support_sum = support_sum + c_support;
            if c_support < 0.10 {
                unsupported_claims = unsupported_claims + 1;
            }
            if cid in thesis_ids and c_support < 0.25 {
                thesis_supported = False;
            }
        }
        support_quality = self.clamp01(support_sum / max(1, total_claims));

        # 2) Logical Soundness (25%)
        logical_penalty = 0.0;
        claims_needing_premise = 0;
        weak_inference_claims = 0;
        vague_claims = 0;
        for c in claims {
            cid = c.get("id", "");
            if self.has_issue_type(c, "missing_premise") and not self.has_assumption(nodes, edges, cid) {
                claims_needing_premise = claims_needing_premise + 1;
                logical_penalty = logical_penalty + 1.0;
            }
            if self.has_issue_type(c, "weak_inference") {
                weak_inference_claims = weak_inference_claims + 1;
                logical_penalty = logical_penalty + 0.7;
            }
            if self.has_issue_type(c, "vague_language") {
                vague_claims = vague_claims + 1;
                logical_penalty = logical_penalty + 0.4;
            }
        }
        max_logical_penalty = float(max(1, total_claims)) * 1.6;
        logical_soundness = self.clamp01(1.0 - (logical_penalty / max_logical_penalty));

        # 3) Coherence (20%)
        orphan_nodes = 0;
        for n in nodes {
            nid = n.get("id", "");
            if self.node_degree(edges, nid) == 0 {
                orphan_nodes = orphan_nodes + 1;
            }
        }

        disconnected_claims = 0;
        for c in claims {
            cid = c.get("id", "");
            if not self.claim_connected_to_thesis(nodes, edges, cid, thesis_ids) {
                disconnected_claims = disconnected_claims + 1;
            }
        }

        orphan_ratio = orphan_nodes / max(1, total_nodes);
        disconnected_ratio = disconnected_claims / max(1, total_claims);
        coherence = self.clamp01(1.0 - (0.7 * orphan_ratio + 0.3 * disconnected_ratio));

        # 4) Counterargument Handling (25%)
        counterarg_nodes = [n for n in nodes if n.get("type", "") == "COUNTERARGUMENT"];
        counterarg_handling = 0.50;
        if total_contradictions > 0 {
            counterarg_handling = self.clamp01(1.0 - (unresolved_contradictions / max(1, total_contradictions)));
        } else {
            addressed_counter_count = 0;
            for cn in counterarg_nodes {
                cid = cn.get("id", "");
                for e in edges {
                    if e.get("type", "") == "ADDRESSES" and e.get("target", "") == cid {
                        addressed_counter_count = addressed_counter_count + 1;
                        break;
                    }
                }
            }
            if len(counterarg_nodes) > 0 and addressed_counter_count > 0 {
                counterarg_handling = 0.90;
            } elif len(counterarg_nodes) > 0 {
                counterarg_handling = 0.75;
            }
        }

        overall = int(100 * (
            0.30 * support_quality +
            0.25 * logical_soundness +
            0.20 * coherence +
            0.25 * counterarg_handling
        ));

        if not thesis_supported {
            overall = overall - 10;
        }
        if overall < 0 { overall = 0; }
        if overall > 100 { overall = 100; }

        passes_bar = (
            overall >= 75 and
            thesis_supported and
            unresolved_contradictions <= 1
        );

        return {
            "overall": overall,
            "support": int(support_quality * 100),
            "premise": int(logical_soundness * 100),
            "coherence": int(coherence * 100),
            "counterargument": int(counterarg_handling * 100),
            "consistency": int(counterarg_handling * 100),
            "unsupportedClaims": unsupported_claims,
            "claimsNeedingPremise": claims_needing_premise,
            "unresolvedContradictions": unresolved_contradictions,
            "weakInferenceClaims": weak_inference_claims,
            "vagueClaims": vague_claims,
            "orphanNodes": orphan_nodes,
            "disconnectedClaims": disconnected_claims,
            "thesisSupported": thesis_supported,
            "passesBar": passes_bar
        };
    }

    def identify_issues(nodes: list, edges: list, score: dict) -> list {
        claims = self.get_claims(nodes);
        total_claims = len(claims);
        total_nodes = len(nodes);
        contradictions = [e for e in edges if e.get("type", "") == "CONTRADICTS"];
        total_contradictions = len(contradictions);

        support_unit = max(3, int(30 / max(1, total_claims)));
        logical_unit = max(2, int(25 / max(1, total_claims)));
        coherence_unit = max(2, int(20 / max(1, total_nodes)));
        counter_unit = max(4, int(25 / max(1, total_contradictions)));

        issues: list[dict] = [];
        issue_index = 1;

        for c in claims {
            cid = c.get("id", "");
            ctype = c.get("type", "CLAIM").lower();
            c_support = self.claim_support_score(nodes, edges, cid);

            if c_support < 0.10 {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "high",
                    "type": "unsupported_claim",
                    "description": f"This {ctype} has no supporting evidence",
                    "suggestedAction": f"Add at least one evidence node that directly supports this {ctype}.",
                    "area": "Support Quality",
                    "estimatedLift": support_unit + 4
                });
                issue_index = issue_index + 1;
            } elif c_support < 0.35 {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "medium",
                    "type": "weak_evidence",
                    "description": f"This {ctype} has weak supporting evidence",
                    "suggestedAction": "Strengthen with higher-quality evidence (data, source, or stronger link).",
                    "area": "Support Quality",
                    "estimatedLift": max(2, int(support_unit * 0.7))
                });
                issue_index = issue_index + 1;
            }

            if self.has_issue_type(c, "missing_premise") and not self.has_assumption(nodes, edges, cid) {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "high" if c_support >= 0.10 else "medium",
                    "type": "missing_premise",
                    "description": f"This {ctype} depends on an unstated assumption",
                    "suggestedAction": "Add an assumption to the supporting evidence to make the logic explicit.",
                    "area": "Logical Soundness",
                    "estimatedLift": logical_unit + 3
                });
                issue_index = issue_index + 1;
            }

            if self.has_issue_type(c, "weak_inference") {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "medium",
                    "type": "weak_inference",
                    "description": f"The reasoning in this {ctype} is weak",
                    "suggestedAction": "Clarify why the evidence justifies the claim, or narrow the claim.",
                    "area": "Logical Soundness",
                    "estimatedLift": logical_unit
                });
                issue_index = issue_index + 1;
            }

            if self.has_issue_type(c, "vague_language") {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "low",
                    "type": "vague_language",
                    "description": f"This {ctype} is vague",
                    "suggestedAction": "Clarify wording with concrete terms and scope.",
                    "area": "Logical Soundness",
                    "estimatedLift": max(1, logical_unit - 1)
                });
                issue_index = issue_index + 1;
            }
        }

        for ce in contradictions {
            if not self.contradiction_unresolved(nodes, edges, ce) {
                continue;
            }
            src_id = ce.get("source", "");
            tgt_id = ce.get("target", "");
            src_node = self.get_node(nodes, src_id);
            issue_node_id = src_id;
            if not src_node or src_node.get("type", "") != "COUNTERARGUMENT" {
                issue_node_id = tgt_id;
            }
            issues.append({
                "id": f"issue_{issue_index}",
                "nodeId": issue_node_id,
                "severity": "high",
                "type": "unresolved_contradiction",
                "description": "A contradiction is unaddressed",
                "suggestedAction": "Add a response with an ADDRESSES edge or mark the contradiction as acknowledged.",
                "area": "Counterargument Handling",
                "estimatedLift": counter_unit + 2
            });
            issue_index = issue_index + 1;
        }

        thesis_ids = self.get_thesis_ids(nodes, edges);
        for c in claims {
            cid = c.get("id", "");
            if not self.claim_connected_to_thesis(nodes, edges, cid, thesis_ids) {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "medium",
                    "type": "disconnected_claim",
                    "description": "This claim is disconnected from the main thesis path",
                    "suggestedAction": "Link this claim to thesis/parent claim with a SUPPORTS edge.",
                    "area": "Coherence",
                    "estimatedLift": coherence_unit + 1
                });
                issue_index = issue_index + 1;
            }
        }

        for n in nodes {
            nid = n.get("id", "");
            ntype = n.get("type", "");
            if self.node_degree(edges, nid) == 0 and ntype in ["CLAIM", "EVIDENCE", "COUNTERARGUMENT"] {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": nid,
                    "severity": "low",
                    "type": "orphan_node",
                    "description": "This node is isolated from the argument graph",
                    "suggestedAction": "Connect this node to a relevant claim or remove it if unnecessary.",
                    "area": "Coherence",
                    "estimatedLift": coherence_unit
                });
                issue_index = issue_index + 1;
            }
        }

        sorted_issues = self.sort_issues_by_priority(issues);
        return sorted_issues[:12];
    }

    def severity_weight(severity: str) -> int {
        sev = severity.lower().strip();
        if sev == "high" { return 300; }
        if sev == "medium" { return 200; }
        return 100;
    }

    def issue_priority(issue: dict) -> int {
        sev_w = self.severity_weight(issue.get("severity", "low"));
        lift = int(self.to_float(issue.get("estimatedLift", 0), 0.0));
        return sev_w + lift * 5;
    }

    def sort_issues_by_priority(issues: list) -> list {
        sorted_list: list = list(issues);
        i = 0;
        while i < len(sorted_list) {
            best_idx = i;
            j = i + 1;
            while j < len(sorted_list) {
                if self.issue_priority(sorted_list[j]) > self.issue_priority(sorted_list[best_idx]) {
                    best_idx = j;
                }
                j = j + 1;
            }
            if best_idx != i {
                tmp = sorted_list[i];
                sorted_list[i] = sorted_list[best_idx];
                sorted_list[best_idx] = tmp;
            }
            i = i + 1;
        }
        return sorted_list;
    }

    def build_next_actions(issues: list) -> list {
        actions: list[dict] = [];
        used_nodes: list[str] = [];
        action_count = 0;
        i = 0;
        while i < len(issues) and action_count < 3 {
            issue = issues[i];
            node_id = issue.get("nodeId", "");
            if node_id and node_id in used_nodes {
                i = i + 1;
                continue;
            }
            if node_id {
                used_nodes.append(node_id);
            }
            actions.append({
                "id": f"next_{action_count + 1}",
                "nodeId": node_id,
                "action": issue.get("suggestedAction", ""),
                "issueType": issue.get("type", ""),
                "rank": action_count + 1,
                "severity": issue.get("severity", "medium"),
                "area": issue.get("area", ""),
                "expectedLift": int(self.to_float(issue.get("estimatedLift", 0), 0.0))
            });
            action_count = action_count + 1;
            i = i + 1;
        }

        # Fill remaining slots if uniqueness filtering left fewer than 3
        i = 0;
        while i < len(issues) and action_count < 3 {
            issue = issues[i];
            node_id = issue.get("nodeId", "");
            already_added = False;
            for a in actions {
                if a.get("nodeId", "") == node_id and a.get("issueType", "") == issue.get("type", "") {
                    already_added = True;
                    break;
                }
            }
            if not already_added {
                actions.append({
                    "id": f"next_{action_count + 1}",
                    "nodeId": node_id,
                    "action": issue.get("suggestedAction", ""),
                    "issueType": issue.get("type", ""),
                    "rank": action_count + 1,
                    "severity": issue.get("severity", "medium"),
                    "area": issue.get("area", ""),
                    "expectedLift": int(self.to_float(issue.get("estimatedLift", 0), 0.0))
                });
                action_count = action_count + 1;
            }
            i = i + 1;
        }
        return actions;
    }

    def annotate_nodes(nodes: list, edges: list, issues: list) -> None {
        issue_map: dict[str, list[dict]] = {};
        for issue in issues {
            nid = issue.get("nodeId", "");
            if not nid { continue; }
            if nid not in issue_map {
                issue_map[nid] = [];
            }
            issue_map[nid].append(issue);
        }

        # Propagate weakness upward through the graph
        weak_ids = self.find_weak_nodes(nodes, edges);

        for n in nodes {
            nid = n.get("id", "");
            n_issues = issue_map.get(nid, []);
            n["issues"] = n_issues;
            n["isWeak"] = len(n_issues) > 0 or nid in weak_ids;

            ntype = n.get("type", "");
            if ntype in ["CLAIM", "THESIS"] {
                claim_support = self.claim_support_score(nodes, edges, nid);
                support_points = int(claim_support * 100);

                logical_points = 100;
                if self.has_issue_type(n, "missing_premise") and not self.has_assumption(nodes, edges, nid) {
                    logical_points = logical_points - 35;
                }
                if self.has_issue_type(n, "weak_inference") {
                    logical_points = logical_points - 20;
                }
                if self.has_issue_type(n, "vague_language") {
                    logical_points = logical_points - 10;
                }
                if logical_points < 0 { logical_points = 0; }

                # Penalize for unresolved counterarguments targeting this node
                counter_penalty = 0;
                for e in edges {
                    if e.get("type", "") == "CONTRADICTS" and e.get("target", "") == nid {
                        counter_src_id = e.get("source", "");
                        is_addressed = False;
                        for e2 in edges {
                            if e2.get("type", "") == "ADDRESSES" and e2.get("target", "") == counter_src_id {
                                is_addressed = True;
                                break;
                            }
                        }
                        if not is_addressed and not self.is_acknowledged(self.get_node(nodes, counter_src_id)) {
                            counter_penalty = counter_penalty + 15;
                        }
                    }
                }
                if counter_penalty > 40 { counter_penalty = 40; }

                raw_score = int(0.6 * support_points + 0.4 * logical_points) - counter_penalty;
                if raw_score < 0 { raw_score = 0; }
                n["nodeScore"] = raw_score;
            } elif ntype == "EVIDENCE" {
                n["nodeScore"] = int(self.evidence_quality(n) * 100);
            } elif ntype == "COUNTERARGUMENT" {
                # Find all addressing evidence and compute quality-weighted score
                address_quality_sum = 0.0;
                address_count = 0;
                for e in edges {
                    if e.get("type", "") == "ADDRESSES" and e.get("target", "") == nid {
                        addr_node = self.get_node(nodes, e.get("source", ""));
                        if addr_node {
                            address_count = address_count + 1;
                            address_quality_sum = address_quality_sum + self.evidence_quality(addr_node);
                        }
                    }
                }
                if address_count > 0 {
                    avg_addr_quality = address_quality_sum / address_count;
                    # Scale: bad evidence (0.0-0.3) → 40-55, decent (0.3-0.6) → 55-70, good (0.6+) → 70-85
                    n["nodeScore"] = int(40 + avg_addr_quality * 45);
                } else {
                    n["nodeScore"] = 55;
                }
            }
        }
    }
}
