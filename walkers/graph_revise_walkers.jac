"""Walkers for revising argument graph nodes."""

import from graph.argument_graph_nodes { ArgumentGraph }
import from src.graph_generator { evaluate_single_evidence, generate_counterargument, clarify_node_content, extract_llm_text, categorize_evidence_fast, expand_branch, extract_search_keywords, pick_best_wiki_result }
import from walkers.graph_generate_walkers { GetGraphWithScoring }
import time;
import json;
import urllib.request;
import urllib.parse;

def preserve_node_fields(node_data: dict) -> dict {
    return {
        "id": node_data.get("id", ""),
        "type": node_data.get("type", ""),
        "content": node_data.get("content", ""),
        "confidence": node_data.get("confidence", 0.5),
        "isWeak": node_data.get("isWeak", False),
        "issues": node_data.get("issues", []),
        "llmIssueTypes": node_data.get("llmIssueTypes", []),
        "position": node_data.get("position", {"x": 0, "y": 0}),
        "evidence_category": node_data.get("evidence_category", ""),
        "assumptions": node_data.get("assumptions", []),
        "nodeScore": node_data.get("nodeScore", 50),
        "sourceUrl": node_data.get("sourceUrl", ""),
        "moreInfo": node_data.get("moreInfo", ""),
        "acknowledged": node_data.get("acknowledged", False),
        "layoutLocked": node_data.get("layoutLocked", False),
        "role": node_data.get("role", node_data.get("semanticRole", "")),
        "semanticRole": node_data.get("semanticRole", ""),
        "source_span_ids": node_data.get("source_span_ids", []),
        "speaker_ids": node_data.get("speaker_ids", []),
        "origin": node_data.get("origin", ""),
        "question": node_data.get("question", ""),
        "decision_status": node_data.get("decision_status", ""),
        "resolution_text": node_data.get("resolution_text", ""),
        "scope": node_data.get("scope", ""),
        "time_horizon": node_data.get("time_horizon", ""),
        "option_status": node_data.get("option_status", ""),
        "evidence_kind": node_data.get("evidence_kind", ""),
        "criterion_tags": node_data.get("criterion_tags", []),
        "risk_kind": node_data.get("risk_kind", ""),
        "severity": node_data.get("severity", ""),
        "is_blocker": node_data.get("is_blocker", False),
        "assumption_status": node_data.get("assumption_status", ""),
        "question_status": node_data.get("question_status", ""),
        "owner": node_data.get("owner", ""),
        "owners": node_data.get("owners", []),
        "dueDate": node_data.get("dueDate", ""),
        "due_date": node_data.get("due_date", node_data.get("dueDate", "")),
        "priority": node_data.get("priority", ""),
        "taskStatus": node_data.get("taskStatus", ""),
        "task_status": node_data.get("task_status", node_data.get("taskStatus", "")),
        "action_status": node_data.get("action_status", node_data.get("taskStatus", ""))
    };
}

def revise_graph_payload(graph_node: obj) -> dict {
    return {
        "id": graph_node.id,
        "nodes": graph_node.nodes,
        "edges": graph_node.edges,
        "graphMode": graph_node.graphMode if hasattr(graph_node, "graphMode") else "education_argument",
        "graph_mode": graph_node.graph_mode if hasattr(graph_node, "graph_mode") else (graph_node.graphMode if hasattr(graph_node, "graphMode") else "education_argument"),
        "schema_version": graph_node.schema_version if hasattr(graph_node, "schema_version") else "",
        "board_id": graph_node.board_id if hasattr(graph_node, "board_id") else graph_node.id,
        "primary_decision_id": graph_node.primary_decision_id if hasattr(graph_node, "primary_decision_id") else "",
        "meeting": graph_node.meeting if hasattr(graph_node, "meeting") else {},
        "template": graph_node.template if hasattr(graph_node, "template") else "",
        "title": graph_node.title if hasattr(graph_node, "title") else "",
        "summary": graph_node.summary if hasattr(graph_node, "summary") else "",
        "createdAt": graph_node.createdAt,
        "updatedAt": graph_node.updatedAt
    };
}

def business_semantic_role(node_data: dict) -> str {
    if not node_data { return ""; }
    role = str(node_data.get("role", node_data.get("semanticRole", ""))).upper().strip();
    if role == "NEXT_ACTION" { role = "ACTION"; }
    if role { return role; }
    node_type = str(node_data.get("type", "")).upper().strip();
    if node_type == "THESIS" { return "DECISION"; }
    if node_type == "EVIDENCE" { return "EVIDENCE"; }
    if node_type == "COUNTERARGUMENT" { return "RISK"; }
    return "OPTION";
}

def primary_decision_target(graph_node: obj, fallback_id: str = "") -> str {
    if hasattr(graph_node, "primary_decision_id") and graph_node.primary_decision_id {
        return graph_node.primary_decision_id;
    }
    for node in graph_node.nodes {
        if business_semantic_role(node) == "DECISION" {
            return node.get("id", "");
        }
    }
    return fallback_id;
}

def action_edge_payload(graph_node: obj, target_node: dict, action_id: str) -> dict {
    target_role = business_semantic_role(target_node);
    target_id = target_node.get("id", "") if target_node else "";
    edge_role = "IMPLEMENTS";
    edge_target = primary_decision_target(graph_node, target_id);
    if target_role == "OPEN_QUESTION" or target_role == "RISK" or target_role == "ASSUMPTION" {
        edge_role = "RESOLVES";
        edge_target = target_id;
    } elif target_role == "DECISION" {
        edge_role = "IMPLEMENTS";
        edge_target = target_id;
    }
    return {
        "id": f"edge_{action_id}",
        "source": action_id,
        "target": edge_target,
        "type": edge_role,
        "role": edge_role
    };
}

def is_business_graph(graph_node: obj) -> bool {
    if hasattr(graph_node, "graph_mode") and graph_node.graph_mode == "business_meeting_decision" {
        return True;
    }
    if hasattr(graph_node, "graphMode") and graph_node.graphMode == "business_meeting_decision" {
        return True;
    }
    return False;
}

def layout_box_for_content(node_content: str) -> dict {
    max_chars = 26;
    line_count = 1;
    content_text = str(node_content) if node_content else "";
    if len(content_text) > max_chars {
        words = content_text.split(" ");
        cur = "";
        lines: list = [];
        for w in words {
            test = (cur + " " + w).strip() if cur else w;
            if len(test) <= max_chars {
                cur = test;
            } else {
                if cur { lines.append(cur); }
                cur = w;
            }
        }
        if cur { lines.append(cur); }
        line_count = min(3, len(lines)) if len(lines) > 0 else 1;
    }
    return {
        "w": 200.0,
        "h": max(70.0, 32.0 + line_count * 17.0 + 12.0)
    };
}

def layout_box_for_node(node_data: dict) -> dict {
    return layout_box_for_content(node_data.get("content", ""));
}

def layout_edge_role(edge_data: dict) -> str {
    raw_role = str(edge_data.get("role", edge_data.get("type", ""))).upper().strip();
    if raw_role == "CONTRADICTS" { return "OPPOSES"; }
    if raw_role == "ADDRESSES" { return "RESOLVES"; }
    return raw_role;
}

def expand_position_candidates(
    graph_node: obj,
    target_node: dict,
    branch_role: str,
    branch_type: str,
    target_x: float,
    target_y: float
) -> list {
    target_role = business_semantic_role(target_node) if is_business_graph(graph_node) else str(target_node.get("type", "CLAIM")).upper().strip();
    candidates: list = [];

    def add_candidate(x_val: float, y_val: float) -> None {
        candidates.append({"x": x_val, "y": y_val});
    }

    if is_business_graph(graph_node) {
        if branch_role == "OPTION" {
            add_candidate(target_x - 260.0, target_y + 190.0);
            add_candidate(target_x + 260.0, target_y + 190.0);
            add_candidate(target_x, target_y + 190.0);
            add_candidate(target_x - 520.0, target_y + 320.0);
            add_candidate(target_x + 520.0, target_y + 320.0);
            add_candidate(target_x - 130.0, target_y + 320.0);
            add_candidate(target_x + 130.0, target_y + 320.0);
            add_candidate(target_x - 390.0, target_y + 450.0);
            add_candidate(target_x + 390.0, target_y + 450.0);
            add_candidate(target_x, target_y + 450.0);
        } elif branch_role == "ACTION" {
            add_candidate(target_x, target_y + 220.0);
            add_candidate(target_x - 220.0, target_y + 220.0);
            add_candidate(target_x + 220.0, target_y + 220.0);
            add_candidate(target_x - 330.0, target_y + 330.0);
            add_candidate(target_x + 330.0, target_y + 330.0);
            add_candidate(target_x - 110.0, target_y + 330.0);
            add_candidate(target_x + 110.0, target_y + 330.0);
            add_candidate(target_x, target_y + 440.0);
        } elif branch_type == "EVIDENCE" {
            base_y = target_y + (340.0 if target_role == "DECISION" else 165.0);
            add_candidate(target_x, base_y);
            add_candidate(target_x - 240.0, base_y);
            add_candidate(target_x + 240.0, base_y);
            add_candidate(target_x - 120.0, base_y + 120.0);
            add_candidate(target_x + 120.0, base_y + 120.0);
            add_candidate(target_x - 360.0, base_y + 120.0);
            add_candidate(target_x + 360.0, base_y + 120.0);
            add_candidate(target_x, base_y + 240.0);
        } else {
            add_candidate(target_x - 220.0, target_y + 150.0);
            add_candidate(target_x + 220.0, target_y + 150.0);
            add_candidate(target_x, target_y + 150.0);
            add_candidate(target_x - 110.0, target_y + 270.0);
            add_candidate(target_x + 110.0, target_y + 270.0);
            add_candidate(target_x - 330.0, target_y + 270.0);
            add_candidate(target_x + 330.0, target_y + 270.0);
            add_candidate(target_x, target_y + 390.0);
        }
    } else {
        if branch_type == "EVIDENCE" {
            add_candidate(target_x, target_y + 145.0);
            add_candidate(target_x - 250.0, target_y + 145.0);
            add_candidate(target_x + 250.0, target_y + 145.0);
            add_candidate(target_x - 125.0, target_y + 260.0);
            add_candidate(target_x + 125.0, target_y + 260.0);
            add_candidate(target_x - 375.0, target_y + 260.0);
            add_candidate(target_x + 375.0, target_y + 260.0);
            add_candidate(target_x, target_y + 375.0);
        } else {
            add_candidate(target_x - 220.0, target_y + 145.0);
            add_candidate(target_x + 220.0, target_y + 145.0);
            add_candidate(target_x, target_y + 145.0);
            add_candidate(target_x - 110.0, target_y + 260.0);
            add_candidate(target_x + 110.0, target_y + 260.0);
            add_candidate(target_x - 330.0, target_y + 260.0);
            add_candidate(target_x + 330.0, target_y + 260.0);
            add_candidate(target_x, target_y + 375.0);
        }
    }

    return candidates;
}

def choose_expand_position(
    graph_node: obj,
    target_node: dict,
    branch_role: str,
    branch_type: str,
    branch_content: str,
    target_x: float,
    target_y: float
) -> dict {
    candidate_box = layout_box_for_content(branch_content);
    candidates = expand_position_candidates(graph_node, target_node, branch_role, branch_type, target_x, target_y);
    if len(candidates) == 0 {
        return {"x": target_x, "y": target_y + 145.0};
    }

    occupied: list = [];
    for node in graph_node.nodes {
        node_id = node.get("id", "");
        node_pos = node.get("position", {"x": 0, "y": 0});
        occupied.append({
            "id": node_id,
            "x": float(node_pos.get("x", 0)),
            "y": float(node_pos.get("y", 0)),
            "box": layout_box_for_node(node)
        });
    }

    best_pos = candidates[0];
    best_penalty = 999999999.0;
    ci = 0;
    while ci < len(candidates) {
        cand = candidates[ci];
        cand_x = float(cand["x"]) if "x" in cand else target_x;
        cand_y = float(cand["y"]) if "y" in cand else target_y + 145.0;
        penalty = float(ci) * 0.35 + abs(cand_x - target_x) * 0.03 + abs(cand_y - target_y) * 0.015;

        oi = 0;
        while oi < len(occupied) {
            occ = occupied[oi];
            occ_box = occ["box"] if "box" in occ else {"w": 200.0, "h": 80.0};
            dx = abs(cand_x - float(occ["x"]) if "x" in occ else cand_x);
            dy = abs(cand_y - float(occ["y"]) if "y" in occ else cand_y);
            min_x_gap = (candidate_box["w"] + occ_box["w"]) / 2.0 + 30.0;
            min_y_gap = (candidate_box["h"] + occ_box["h"]) / 2.0 + 20.0;
            overlap_x = min_x_gap - dx;
            overlap_y = min_y_gap - dy;

            if overlap_x > 0.0 and overlap_y > 0.0 {
                penalty = penalty + 100000.0 + overlap_x * overlap_y * 6.0;
            } elif dx < min_x_gap + 120.0 and dy < min_y_gap + 70.0 {
                penalty = penalty + max(0.0, (min_x_gap + 120.0) - dx) * 0.65 + max(0.0, (min_y_gap + 70.0) - dy) * 0.45;
            }
            oi = oi + 1;
        }

        if penalty < best_penalty {
            best_penalty = penalty;
            best_pos = {"x": cand_x, "y": cand_y};
        }
        ci = ci + 1;
    }

    return best_pos;
}

walker:pub PersistGraphLayout {
    has graphId: str,
        positions: dict = {};

    can run with Root entry {
        try {
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

        pos_map = self.positions if self.positions else {};
        updated_nodes: list = [];
        updated_count = 0;

        for node in graph_node.nodes {
            node_id = node.get("id", "");
            if node_id in pos_map {
                raw_pos = pos_map[node_id] if pos_map[node_id] else {};
                existing_pos = node.get("position", {"x": 0, "y": 0});
                next_x = 0.0;
                next_y = 0.0;

                try {
                    next_x = float(raw_pos.get("x", existing_pos.get("x", 0)));
                } except Exception {
                    next_x = float(existing_pos.get("x", 0));
                }
                try {
                    next_y = float(raw_pos.get("y", existing_pos.get("y", 0)));
                } except Exception {
                    next_y = float(existing_pos.get("y", 0));
                }

                updated_node = preserve_node_fields(node);
                updated_node["position"] = {"x": next_x, "y": next_y};
                updated_nodes.append(updated_node);
                updated_count = updated_count + 1;
                continue;
            }
            updated_nodes.append(node);
        }

        graph_node.nodes = updated_nodes;
        graph_node.updatedAt = str(int(time.time()));

        report {
            "success": True,
            "updatedCount": updated_count,
            "graph": revise_graph_payload(graph_node)
        };
        } except Exception as e {
            print(f"PersistGraphLayout ERROR: {e}");
            report {"error": str(e)};
        }
    }
}

walker:pub RestoreGraphSnapshot {
    has graphId: str,
        nodes: list = [],
        edges: list = [];

    can run with Root entry {
        try {
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

        graph_node.nodes = list(self.nodes) if self.nodes else [];
        graph_node.edges = list(self.edges) if self.edges else [];
        graph_node.updatedAt = str(int(time.time()));

        scorer = GetGraphWithScoring(graphId=self.graphId);
        scored_data = scorer.score_graph(graph_node);

        report {
            "success": True,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"RestoreGraphSnapshot ERROR: {e}");
            report {"error": str(e)};
        }
    }
}

walker:pub AddEvidenceToNode {
    has graphId: str,
        nodeId: str,
        evidenceContent: str,
        sourceUrl: str = "",
        evaluate: bool = False;

    can run with Root entry {
        try {
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

        evidence_id = f"node_evidence_{time.time_ns()}";

        # Capitalize first letter of evidence content
        ev_content = self.evidenceContent.strip();
        if len(ev_content) > 1 {
            ev_content = ev_content[0].upper() + ev_content[1:];
        } elif len(ev_content) == 1 {
            ev_content = ev_content[0].upper();
        }

        # Dedup: reject if an EVIDENCE child with matching content already supports target
        for _dup_edge in graph_node.edges {
            if _dup_edge.get("target") == self.nodeId and _dup_edge.get("type") == "SUPPORTS" {
                for _dup_n in graph_node.nodes {
                    if _dup_n["id"] == _dup_edge.get("source") and _dup_n.get("type") == "EVIDENCE" {
                        if _dup_n.get("content", "") == ev_content {
                            report {"error": "This evidence is already attached to the node.", "duplicate": True};
                            return;
                        }
                    }
                }
            }
        }

        # Fast keyword-based categorization (no LLM call = instant)
        cat_result = categorize_evidence_fast(ev_content);
        ev_category = cat_result.get("evidence_category", "logical_reasoning");
        ev_assumptions: list = cat_result.get("assumptions", []);
        ev_confidence = cat_result.get("confidence", 0.6);
        ev_node_score = cat_result.get("nodeScore", 50);
        print(f"=== Evidence categorized (fast): category={ev_category}, confidence={ev_confidence}, nodeScore={ev_node_score} ===");

        # Compute position below target node, offset to avoid overlap
        target_pos_x = 0.0;
        target_pos_y = 0.0;
        sibling_count = 0;
        for tn in graph_node.nodes {
            if tn["id"] == self.nodeId {
                tp = tn.get("position", {"x": 0, "y": 0});
                target_pos_x = float(tp.get("x", 0));
                target_pos_y = float(tp.get("y", 0));
            }
        }
        # Count existing children of this node for horizontal offset
        for te in graph_node.edges {
            if te.get("target") == self.nodeId and te.get("type") == "SUPPORTS" {
                sibling_count = sibling_count + 1;
            }
        }
        new_x = target_pos_x + (sibling_count - 1) * 250.0;
        new_y = target_pos_y + 130.0;

        # Prepare source URL
        ev_source = self.sourceUrl.strip() if self.sourceUrl else "";

        new_evidence = {
            "id": evidence_id,
            "type": "EVIDENCE",
            "content": ev_content,
            "confidence": ev_confidence,
            "isWeak": ev_confidence < 0.5,
            "issues": [],
            "llmIssueTypes": [],
            "position": {"x": new_x, "y": new_y},
            "evidence_category": ev_category,
            "assumptions": ev_assumptions,
            "nodeScore": ev_node_score,
            "sourceUrl": ev_source,
            "role": "EVIDENCE",
            "semanticRole": "EVIDENCE"
        };

        updated_nodes = list(graph_node.nodes);
        updated_nodes.append(new_evidence);
        graph_node.nodes = updated_nodes;

        new_edge = {
            "id": f"edge_{evidence_id}",
            "source": evidence_id,
            "target": self.nodeId,
            "type": "SUPPORTS",
            "role": "SUPPORTS" if is_business_graph(graph_node) else ""
        };

        updated_edges = list(graph_node.edges);
        updated_edges.append(new_edge);
        graph_node.edges = updated_edges;
        graph_node.updatedAt = str(int(time.time()));

        # If evaluate=True, run LLM evaluation on the new evidence node
        if self.evaluate {
            try {
                _ev_thesis = "";
                for _etn in graph_node.nodes {
                    if _etn["type"] == "THESIS" {
                        _ev_thesis = _etn.get("content", "");
                        break;
                    }
                }
                # Find parent node content for richer context
                _ev_parent_content = "";
                _ev_parent_type = "";
                for _epn in graph_node.nodes {
                    if _epn["id"] == self.nodeId {
                        _ev_parent_content = _epn.get("content", "");
                        _ev_parent_type = _epn.get("type", "");
                        break;
                    }
                }
                _ev_context = f"This evidence was submitted by the user to support the {_ev_parent_type} node: '{_ev_parent_content}'. The overall thesis is: '{_ev_thesis}'. Evaluate whether this evidence is relevant, logically sound, and actually supports the parent node. Flag ad hominem attacks, logical fallacies, unsupported accusations, and off-topic content as LOW confidence (0.1-0.2). Be critical.";
                raw_eval = evaluate_single_evidence(
                    evidence_text=ev_content,
                    thesis_text=_ev_thesis,
                    context_description=_ev_context
                );
                _eval_str = extract_llm_text(raw_eval).strip();
                if _eval_str.startswith("```") {
                    _ef_lines = _eval_str.split("\n");
                    _ef_lines = _ef_lines[1:];
                    if _ef_lines and _ef_lines[-1].strip().startswith("```") {
                        _ef_lines = _ef_lines[:-1];
                    }
                    _eval_str = "\n".join(_ef_lines).strip();
                }
                _eval_parsed = json.loads(_eval_str);

                _eval_cat = _eval_parsed.get("evidence_category", ev_category);
                _eval_assumptions: list = _eval_parsed.get("assumptions", []);
                _eval_conf = 0.5;
                try { _eval_conf = float(_eval_parsed.get("confidence", 0.5)); }
                except Exception { _eval_conf = 0.5; }

                if not isinstance(_eval_assumptions, list) { _eval_assumptions = []; }

                _capped: list = [];
                for _ea in _eval_assumptions {
                    _ea_s = str(_ea).strip();
                    if len(_ea_s) > 1 { _capped.append(_ea_s[0].upper() + _ea_s[1:]); }
                    elif len(_ea_s) == 1 { _capped.append(_ea_s[0].upper()); }
                    else { _capped.append(_ea_s); }
                }

                _cat_weights: dict[str, float] = {
                    "empirical_data": 0.9, "expert_testimony": 0.8,
                    "logical_reasoning": 0.6, "analogy": 0.5, "anecdotal": 0.3
                };
                _base_q = _cat_weights.get(_eval_cat, 0.6);
                _quality = _base_q - len(_capped) * 0.15;
                if _quality < 0.1 { _quality = 0.1; }
                _eval_score = int(_quality * 100);

                _upd_nodes: list = [];
                for _un in graph_node.nodes {
                    if _un["id"] == evidence_id {
                        _un["evidence_category"] = _eval_cat;
                        _un["assumptions"] = _capped;
                        _un["confidence"] = _eval_conf;
                        _un["isWeak"] = _eval_conf < 0.5;
                        _un["nodeScore"] = _eval_score;
                    }
                    _upd_nodes.append(_un);
                }
                graph_node.nodes = _upd_nodes;
                print(f"  Evaluated evidence: category={_eval_cat}, score={_eval_score}, assumptions={len(_capped)}");
            } except Exception as eval_err {
                print(f"  Evidence evaluation failed (non-fatal): {eval_err}");
            }
        }

        # Call scoring methods directly on the walker instance
        scorer = GetGraphWithScoring(graphId=self.graphId);
        scored_data = scorer.score_graph(graph_node);

        report {
            "success": True,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"AddEvidenceToNode ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub AddAssumptionToEvidence {
    has graphId: str,
        nodeId: str,
        assumptionText: str;

    can run with Root entry {
        try {
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

        for node in graph_node.nodes {
            if node["id"] == self.nodeId {
                existing_assumptions = node.get("assumptions", []);
                if not isinstance(existing_assumptions, list) {
                    existing_assumptions = [];
                }
                existing_assumptions.append(self.assumptionText);
                updated_node = preserve_node_fields(node);
                updated_node["assumptions"] = existing_assumptions;
                new_nodes: list = [];
                for n in graph_node.nodes {
                    if n["id"] == self.nodeId {
                        new_nodes.append(updated_node);
                    } else {
                        new_nodes.append(n);
                    }
                }
                graph_node.nodes = new_nodes;
                break;
            }
        }

        graph_node.updatedAt = str(int(time.time()));

        # Call scoring methods directly on the walker instance
        scorer = GetGraphWithScoring(graphId=self.graphId);
        scored_data = scorer.score_graph(graph_node);

        report {
            "success": True,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"AddAssumptionToEvidence ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub UpdateNodeContent {
    has graphId: str,
        nodeId: str,
        newContent: str,
        owner: str = "",
        dueDate: str = "",
        priority: str = "",
        taskStatus: str = "";

    can run with Root entry {
        try {
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

        # Capitalize first letter of new content
        new_text = self.newContent.strip();
        if len(new_text) > 1 {
            new_text = new_text[0].upper() + new_text[1:];
        } elif len(new_text) == 1 {
            new_text = new_text[0].upper();
        }

        for node in graph_node.nodes {
            if node["id"] == self.nodeId {
                updated_node = preserve_node_fields(node);
                updated_node["content"] = new_text;
                if self.owner or business_semantic_role(node) == "ACTION" {
                    updated_node["owner"] = self.owner.strip();
                    updated_node["owners"] = [] if not self.owner.strip() else [self.owner.strip()];
                }
                if self.dueDate or business_semantic_role(node) == "ACTION" {
                    updated_node["dueDate"] = self.dueDate.strip();
                    updated_node["due_date"] = self.dueDate.strip();
                }
                if self.priority {
                    updated_node["priority"] = self.priority.strip();
                }
                if self.taskStatus {
                    updated_node["taskStatus"] = self.taskStatus.strip();
                    updated_node["task_status"] = self.taskStatus.strip();
                    updated_node["action_status"] = self.taskStatus.strip();
                }
                new_nodes: list = [];
                for n in graph_node.nodes {
                    if n["id"] == self.nodeId {
                        new_nodes.append(updated_node);
                    } else {
                        new_nodes.append(n);
                    }
                }
                graph_node.nodes = new_nodes;
                break;
            }
        }

        graph_node.updatedAt = str(int(time.time()));

        # Call scoring methods directly on the walker instance
        scorer = GetGraphWithScoring(graphId=self.graphId);
        scored_data = scorer.score_graph(graph_node);

        report {
            "success": True,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"UpdateNodeContent ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub DeleteNode {
    has graphId: str,
        nodeId: str;

    can run with Root entry {
        try {
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

        graph_node.nodes = [n for n in graph_node.nodes if n["id"] != self.nodeId];
        graph_node.edges = [
            e for e in graph_node.edges
            if e["source"] != self.nodeId and e["target"] != self.nodeId
        ];
        graph_node.updatedAt = str(int(time.time()));

        # Call scoring methods directly on the walker instance
        scorer = GetGraphWithScoring(graphId=self.graphId);
        scored_data = scorer.score_graph(graph_node);

        report {
            "success": True,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"DeleteNode ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub AddCounterargumentNode {
    has graphId: str,
        targetNodeId: str,
        counterargContent: str;

    can run with Root entry {
        try {
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

        counter_id = f"node_counter_{time.time_ns()}";

        # Capitalize first letter of counterargument content
        ca_content = self.counterargContent.strip();
        if len(ca_content) > 1 {
            ca_content = ca_content[0].upper() + ca_content[1:];
        } elif len(ca_content) == 1 {
            ca_content = ca_content[0].upper();
        }

        # Compute position to the right of target node
        target_pos_x = 0.0;
        target_pos_y = 0.0;
        contra_count = 0;
        for tn in graph_node.nodes {
            if tn["id"] == self.targetNodeId {
                tp = tn.get("position", {"x": 0, "y": 0});
                target_pos_x = float(tp.get("x", 0));
                target_pos_y = float(tp.get("y", 0));
            }
        }
        # Count existing contradicts edges to this node for offset
        for te in graph_node.edges {
            te_role = str(te.get("role", te.get("type", ""))).upper();
            if te_role == "CONTRADICTS" { te_role = "OPPOSES"; }
            if te.get("target") == self.targetNodeId and te_role == ("OPPOSES" if is_business_graph(graph_node) else "CONTRADICTS") {
                contra_count = contra_count + 1;
            }
        }
        new_x = target_pos_x + 280.0 + (contra_count - 1) * 250.0;
        new_y = target_pos_y + 60.0;

        new_counter = {
            "id": counter_id,
            "type": "COUNTERARGUMENT",
            "content": ca_content,
            "confidence": 0.5,
            "isWeak": False,
            "issues": [],
            "llmIssueTypes": [],
            "position": {"x": new_x, "y": new_y},
            "evidence_category": "",
            "assumptions": [],
            "nodeScore": 50,
            "role": "RISK" if is_business_graph(graph_node) else "",
            "semanticRole": "RISK" if is_business_graph(graph_node) else "",
            "risk_kind": "objection" if is_business_graph(graph_node) else "",
            "severity": "medium" if is_business_graph(graph_node) else ""
        };

        updated_nodes = list(graph_node.nodes);
        updated_nodes.append(new_counter);
        graph_node.nodes = updated_nodes;

        new_edge = {
            "id": f"edge_{counter_id}",
            "source": counter_id,
            "target": self.targetNodeId,
            "type": "OPPOSES" if is_business_graph(graph_node) else "CONTRADICTS",
            "role": "OPPOSES" if is_business_graph(graph_node) else ""
        };

        updated_edges = list(graph_node.edges);
        updated_edges.append(new_edge);
        graph_node.edges = updated_edges;
        graph_node.updatedAt = str(int(time.time()));

        # Call scoring methods directly on the walker instance
        scorer = GetGraphWithScoring(graphId=self.graphId);
        scored_data = scorer.score_graph(graph_node);

        report {
            "success": True,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"AddCounterargumentNode ERROR: {e}");
            report {"error": str(e)};
        }
    }
}

walker:pub AddNextActionNode {
    has graphId: str,
        targetNodeId: str,
        actionContent: str,
        owner: str = "",
        dueDate: str = "",
        priority: str = "",
        taskStatus: str = "open";

    can run with Root entry {
        try {
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

        action_id = f"node_action_{time.time_ns()}";
        action_content = self.actionContent.strip();
        if len(action_content) > 1 {
            action_content = action_content[0].upper() + action_content[1:];
        } elif len(action_content) == 1 {
            action_content = action_content[0].upper();
        }

        target_pos_x = 0.0;
        target_pos_y = 0.0;
        target_node = None;
        action_count = 0;
        for tn in graph_node.nodes {
            if tn["id"] == self.targetNodeId {
                target_node = tn;
                tp = tn.get("position", {"x": 0, "y": 0});
                target_pos_x = float(tp.get("x", 0));
                target_pos_y = float(tp.get("y", 0));
            }
        }
        for te in graph_node.edges {
            te_role = str(te.get("role", te.get("type", ""))).upper();
            if te_role == "ADDRESSES" { te_role = "RESOLVES"; }
            if te_role == "RESOLVES" or te_role == "IMPLEMENTS" {
                action_count = action_count + 1;
            }
        }
        new_x = target_pos_x + (action_count - 1) * 220.0;
        new_y = target_pos_y + 220.0;

        new_action = {
            "id": action_id,
            "type": "CLAIM",
            "content": action_content,
            "confidence": 0.7,
            "isWeak": False,
            "issues": [],
            "llmIssueTypes": [],
            "position": {"x": new_x, "y": new_y},
            "evidence_category": "",
            "assumptions": [],
            "nodeScore": 50,
            "role": "ACTION",
            "semanticRole": "ACTION",
            "owner": self.owner.strip(),
            "owners": [] if not self.owner.strip() else [self.owner.strip()],
            "dueDate": self.dueDate.strip(),
            "due_date": self.dueDate.strip(),
            "priority": self.priority.strip(),
            "taskStatus": self.taskStatus.strip() if self.taskStatus else "open",
            "task_status": self.taskStatus.strip() if self.taskStatus else "open",
            "action_status": self.taskStatus.strip() if self.taskStatus else "open"
        };

        updated_nodes = list(graph_node.nodes);
        updated_nodes.append(new_action);
        graph_node.nodes = updated_nodes;

        new_edge = action_edge_payload(graph_node, target_node, action_id);
        updated_edges = list(graph_node.edges);
        updated_edges.append(new_edge);
        graph_node.edges = updated_edges;
        graph_node.updatedAt = str(int(time.time()));

        scorer = GetGraphWithScoring(graphId=self.graphId);
        scored_data = scorer.score_graph(graph_node);

        report {
            "success": True,
            "graph": scored_data.get("graph", revise_graph_payload(graph_node)),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"AddNextActionNode ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub AddAddressEdge {
    has graphId: str,
        defendNodeId: str,
        counterargNodeId: str,
        addressContent: str;

    can run with Root entry {
        try {
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

        evidence_id = f"node_address_{time.time_ns()}";

        # Compute position between the defended node and counterarg
        defend_x = 0.0;
        defend_y = 0.0;
        counter_x = 0.0;
        counter_y = 0.0;
        for tn in graph_node.nodes {
            if tn["id"] == self.defendNodeId {
                tp = tn.get("position", {"x": 0, "y": 0});
                defend_x = float(tp.get("x", 0));
                defend_y = float(tp.get("y", 0));
            }
            if tn["id"] == self.counterargNodeId {
                tp = tn.get("position", {"x": 0, "y": 0});
                counter_x = float(tp.get("x", 0));
                counter_y = float(tp.get("y", 0));
            }
        }
        new_x = (defend_x + counter_x) / 2.0;
        new_y = max(defend_y, counter_y) + 130.0;

        new_evidence = {
            "id": evidence_id,
            "type": "EVIDENCE",
            "content": self.addressContent,
            "confidence": 0.5,
            "isWeak": False,
            "issues": [],
            "llmIssueTypes": [],
            "position": {"x": new_x, "y": new_y},
            "evidence_category": "logical_reasoning",
            "assumptions": [],
            "nodeScore": 50,
            "role": "EVIDENCE",
            "semanticRole": "EVIDENCE"
        };

        updated_nodes = list(graph_node.nodes);
        updated_nodes.append(new_evidence);
        graph_node.nodes = updated_nodes;

        support_edge = {
            "id": f"edge_sup_{evidence_id}",
            "source": evidence_id,
            "target": self.defendNodeId,
            "type": "SUPPORTS",
            "role": "SUPPORTS" if is_business_graph(graph_node) else ""
        };

        address_edge = {
            "id": f"edge_adr_{evidence_id}",
            "source": evidence_id,
            "target": self.counterargNodeId,
            "type": "RESOLVES" if is_business_graph(graph_node) else "ADDRESSES",
            "role": "RESOLVES" if is_business_graph(graph_node) else ""
        };

        updated_edges = list(graph_node.edges);
        updated_edges.append(support_edge);
        updated_edges.append(address_edge);
        graph_node.edges = updated_edges;
        graph_node.updatedAt = str(int(time.time()));

        # LLM evaluation of the address evidence
        try {
            _addr_thesis = "";
            for _atn in graph_node.nodes {
                if _atn["type"] == "THESIS" {
                    _addr_thesis = _atn.get("content", "");
                    break;
                }
            }
            _addr_counter_text = "";
            for _acn in graph_node.nodes {
                if _acn["id"] == self.counterargNodeId {
                    _addr_counter_text = _acn.get("content", "");
                    break;
                }
            }
            _addr_context = f"This evidence was submitted by the user to address the counterargument: '{_addr_counter_text}' in support of the thesis: '{_addr_thesis}'. Evaluate whether this response is relevant, logically sound, and actually addresses the counterargument. Flag ad hominem attacks, logical fallacies, unsupported accusations, and off-topic content as LOW confidence (0.1-0.2). Be critical.";
            raw_eval = evaluate_single_evidence(
                evidence_text=self.addressContent,
                thesis_text=_addr_thesis,
                context_description=_addr_context
            );
            _eval_str = extract_llm_text(raw_eval).strip();
            if _eval_str.startswith("```") {
                _ef_lines = _eval_str.split("\n");
                _ef_lines = _ef_lines[1:];
                if _ef_lines and _ef_lines[-1].strip().startswith("```") {
                    _ef_lines = _ef_lines[:-1];
                }
                _eval_str = "\n".join(_ef_lines).strip();
            }
            _eval_parsed = json.loads(_eval_str);

            _eval_cat = _eval_parsed.get("evidence_category", "logical_reasoning");
            _eval_assumptions: list = _eval_parsed.get("assumptions", []);
            _eval_conf = 0.5;
            try { _eval_conf = float(_eval_parsed.get("confidence", 0.5)); }
            except Exception { _eval_conf = 0.5; }

            if not isinstance(_eval_assumptions, list) { _eval_assumptions = []; }

            _capped: list = [];
            for _ea in _eval_assumptions {
                _ea_s = str(_ea).strip();
                if len(_ea_s) > 1 { _capped.append(_ea_s[0].upper() + _ea_s[1:]); }
                elif len(_ea_s) == 1 { _capped.append(_ea_s[0].upper()); }
                else { _capped.append(_ea_s); }
            }

            # Update the evidence node in-place
            _upd_nodes: list = [];
            for _un in graph_node.nodes {
                if _un["id"] == evidence_id {
                    _un["evidence_category"] = _eval_cat;
                    _un["assumptions"] = _capped;
                    _un["confidence"] = _eval_conf;
                    _un["isWeak"] = _eval_conf < 0.5;
                }
                _upd_nodes.append(_un);
            }
            graph_node.nodes = _upd_nodes;
            print(f"  Address evaluated: category={_eval_cat}, confidence={_eval_conf}, assumptions={len(_capped)}");
        } except Exception as eval_err {
            print(f"  Address evaluation failed (non-fatal): {eval_err}");
        }

        # Call scoring methods directly on the walker instance
        scorer = GetGraphWithScoring(graphId=self.graphId);
        scored_data = scorer.score_graph(graph_node);

        report {
            "success": True,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"AddAddressEdge ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub EvaluateNewNode {
    has graphId: str,
        nodeId: str;

    can run with Root entry {
        try {
        print(f"=== EvaluateNewNode: graphId={self.graphId}, nodeId={self.nodeId} ===");
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

        # Find the target node and the thesis
        target_node = None;
        thesis_text = "";
        for n in graph_node.nodes {
            if n["id"] == self.nodeId {
                target_node = n;
            }
            if n["type"] == "THESIS" {
                thesis_text = n.get("content", "");
            }
        }

        if not target_node {
            report {"error": "Node not found"};
            return;
        }

        node_content = target_node.get("content", "");
        node_type = target_node.get("type", "EVIDENCE");

        # Only evaluate EVIDENCE nodes with LLM
        if node_type == "EVIDENCE" {
            # Build context
            context = f"This evidence is used to support the thesis: '{thesis_text}'";

            # Call LLM to evaluate
            raw_result = evaluate_single_evidence(
                evidence_text=node_content,
                thesis_text=thesis_text,
                context_description=context
            );

            # Parse LLM response
            parsed = {};
            try {
                raw_str = extract_llm_text(raw_result).strip();
                # Handle markdown fences
                if raw_str.startswith("```") {
                    fence_lines = raw_str.split("\n");
                    fence_lines = fence_lines[1:];
                    if fence_lines and fence_lines[-1].strip().startswith("```") {
                        fence_lines = fence_lines[:-1];
                    }
                    raw_str = "\n".join(fence_lines).strip();
                }
                parsed = json.loads(raw_str);
            } except Exception {
                parsed = {};
            }

            print(f"=== LLM evaluation result: {parsed} ===");

            # Extract evaluation results
            ev_category = parsed.get("evidence_category", "logical_reasoning");
            ev_assumptions = parsed.get("assumptions", []);
            ev_confidence = 0.5;
            try {
                ev_confidence = float(parsed.get("confidence", 0.5));
            } except Exception {
                ev_confidence = 0.5;
            }

            if not isinstance(ev_assumptions, list) {
                ev_assumptions = [];
            }

            # Capitalize assumptions
            capped_assumptions: list = [];
            for a in ev_assumptions {
                a_str = str(a).strip();
                if len(a_str) > 1 {
                    capped_assumptions.append(a_str[0].upper() + a_str[1:]);
                } elif len(a_str) == 1 {
                    capped_assumptions.append(a_str[0].upper());
                } else {
                    capped_assumptions.append(a_str);
                }
            }

            # Category quality weights
            cat_weights: dict[str, float] = {
                "empirical_data": 0.9, "expert_testimony": 0.8,
                "logical_reasoning": 0.6, "analogy": 0.5, "anecdotal": 0.3
            };
            base_quality = cat_weights.get(ev_category, 0.6);
            quality = base_quality - len(capped_assumptions) * 0.15;
            if quality < 0.1 { quality = 0.1; }
            node_score = int(quality * 100);

            # Update the node in the graph
            updated_node = preserve_node_fields(target_node);
            updated_node["confidence"] = ev_confidence;
            updated_node["isWeak"] = ev_confidence < 0.5;
            updated_node["evidence_category"] = ev_category;
            updated_node["assumptions"] = capped_assumptions;
            updated_node["nodeScore"] = node_score;

            # Replace node in graph
            new_nodes: list = [];
            for n in graph_node.nodes {
                if n["id"] == self.nodeId {
                    new_nodes.append(updated_node);
                } else {
                    new_nodes.append(n);
                }
            }
            graph_node.nodes = new_nodes;
            graph_node.updatedAt = str(int(time.time()));

            report {
                "success": True,
                "evaluatedNode": updated_node,
                "graph": {
                    "id": graph_node.id,
                    "nodes": graph_node.nodes,
                    "edges": graph_node.edges,
                    "createdAt": graph_node.createdAt,
                    "updatedAt": graph_node.updatedAt
                }
            };
        } else {
            # For non-evidence nodes, just report back without changes
            report {"success": True, "evaluatedNode": target_node};
        }
        } except Exception as e {
            print(f"EvaluateNewNode ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub GenerateCounter {
    has graphId: str,
        targetNodeId: str;

    can run with Root entry {
        try {
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

        # Find target node and thesis
        target_content = "";
        thesis_text = "";
        for n in graph_node.nodes {
            if n["id"] == self.targetNodeId {
                target_content = n.get("content", "");
            }
            if n["type"] == "THESIS" {
                thesis_text = n.get("content", "");
            }
        }

        if not target_content {
            report {"error": "Target node not found"};
            return;
        }

        # Call LLM to generate counterargument
        raw_result = generate_counterargument(
            claim_text=target_content,
            thesis_text=thesis_text
        );
        raw_str = extract_llm_text(raw_result).strip();
        if raw_str.startswith("```") {
            fence_lines = raw_str.split("\n");
            fence_lines = fence_lines[1:];
            if fence_lines and fence_lines[-1].strip().startswith("```") {
                fence_lines = fence_lines[:-1];
            }
            raw_str = "\n".join(fence_lines).strip();
        }
        parsed = json.loads(raw_str);
        ca_text = parsed.get("counterargument", "");

        if not ca_text {
            report {"error": "LLM returned empty counterargument"};
            return;
        }

        # Capitalize
        if len(ca_text) > 1 {
            ca_text = ca_text[0].upper() + ca_text[1:];
        } elif len(ca_text) == 1 {
            ca_text = ca_text[0].upper();
        }

        counter_id = f"node_counter_{time.time_ns()}";

        # Position to the right of target
        target_pos_x = 0.0;
        target_pos_y = 0.0;
        contra_count = 0;
        for tn in graph_node.nodes {
            if tn["id"] == self.targetNodeId {
                tp = tn.get("position", {"x": 0, "y": 0});
                target_pos_x = float(tp.get("x", 0));
                target_pos_y = float(tp.get("y", 0));
            }
        }
        for te in graph_node.edges {
            te_role = str(te.get("role", te.get("type", ""))).upper();
            if te_role == "CONTRADICTS" { te_role = "OPPOSES"; }
            if te.get("target") == self.targetNodeId and te_role == ("OPPOSES" if is_business_graph(graph_node) else "CONTRADICTS") {
                contra_count = contra_count + 1;
            }
        }
        new_x = target_pos_x + 280.0 + contra_count * 250.0;
        new_y = target_pos_y + 60.0;

        new_counter = {
            "id": counter_id,
            "type": "COUNTERARGUMENT",
            "content": ca_text,
            "confidence": 0.5,
            "isWeak": False,
            "issues": [],
            "llmIssueTypes": [],
            "position": {"x": new_x, "y": new_y},
            "evidence_category": "",
            "assumptions": [],
            "nodeScore": 50,
            "role": "RISK" if is_business_graph(graph_node) else "",
            "semanticRole": "RISK" if is_business_graph(graph_node) else "",
            "risk_kind": "objection" if is_business_graph(graph_node) else "",
            "severity": "medium" if is_business_graph(graph_node) else ""
        };

        updated_nodes = list(graph_node.nodes);
        updated_nodes.append(new_counter);
        graph_node.nodes = updated_nodes;

        new_edge = {
            "id": f"edge_{counter_id}",
            "source": counter_id,
            "target": self.targetNodeId,
            "type": "OPPOSES" if is_business_graph(graph_node) else "CONTRADICTS",
            "role": "OPPOSES" if is_business_graph(graph_node) else ""
        };

        updated_edges = list(graph_node.edges);
        updated_edges.append(new_edge);
        graph_node.edges = updated_edges;
        graph_node.updatedAt = str(int(time.time()));

        # Call scoring methods directly on the walker instance
        scorer = GetGraphWithScoring(graphId=self.graphId);
        scored_data = scorer.score_graph(graph_node);

        report {
            "success": True,
            "generatedText": ca_text,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"GenerateCounter ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub ClarifyNode {
    has graphId: str,
        nodeId: str;

    can run with Root entry {
        try {
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

        # Find target node and thesis
        target_node = None;
        thesis_text = "";
        for n in graph_node.nodes {
            if n["id"] == self.nodeId {
                target_node = n;
            }
            if n["type"] == "THESIS" {
                thesis_text = n.get("content", "");
            }
        }

        if not target_node {
            report {"error": "Node not found"};
            return;
        }

        node_content = target_node.get("content", "");
        node_type = target_node.get("type", "CLAIM");

        # Call LLM to generate more info
        raw_result = clarify_node_content(
            node_text=node_content,
            node_type=node_type,
            thesis_text=thesis_text
        );
        raw_str = extract_llm_text(raw_result).strip();
        if raw_str.startswith("```") {
            fence_lines = raw_str.split("\n");
            fence_lines = fence_lines[1:];
            if fence_lines and fence_lines[-1].strip().startswith("```") {
                fence_lines = fence_lines[:-1];
            }
            raw_str = "\n".join(fence_lines).strip();
        }
        parsed = json.loads(raw_str);
        more_info = parsed.get("moreInfo", "");
        source_hint = parsed.get("sourceHint", "");

        if not more_info {
            report {"error": "LLM returned empty info"};
            return;
        }

        # Capitalize
        if len(more_info) > 1 {
            more_info = more_info[0].upper() + more_info[1:];
        } elif len(more_info) == 1 {
            more_info = more_info[0].upper();
        }

        # Append source hint to moreInfo if present
        if source_hint {
            more_info = more_info + "\n\n📚 Source: " + source_hint;
        }

        # Store moreInfo on the node without replacing content
        updated_node = preserve_node_fields(target_node);
        updated_node["moreInfo"] = more_info;

        new_nodes: list = [];
        for n in graph_node.nodes {
            if n["id"] == self.nodeId {
                new_nodes.append(updated_node);
            } else {
                new_nodes.append(n);
            }
        }
        graph_node.nodes = new_nodes;
        graph_node.updatedAt = str(int(time.time()));

        # Call scoring methods directly on the walker instance
        scorer = GetGraphWithScoring(graphId=self.graphId);
        scored_data = scorer.score_graph(graph_node);

        report {
            "success": True,
            "moreInfo": more_info,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"ClarifyNode ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub InvestigateNode {
    has graphId: str,
        nodeId: str,
        addAsEvidence: bool = False,
        selectedResultIndex: int = -1,
        selectedTitle: str = "",
        selectedUrl: str = "";

    can run with Root entry {
        try {
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

        # Find target node
        target_node = None;
        for n in graph_node.nodes {
            if n["id"] == self.nodeId {
                target_node = n;
                break;
            }
        }

        if not target_node {
            report {"error": "Node not found"};
            return;
        }

        node_content = target_node.get("content", "");
        node_type = target_node.get("type", "CLAIM");
        existing_source = target_node.get("sourceUrl", "");

        # Get thesis for context
        thesis_text = "";
        for n in graph_node.nodes {
            if n["type"] == "THESIS" {
                thesis_text = n.get("content", "");
                break;
            }
        }

        # Phase 2 fast path: if client passed selectedTitle, skip search entirely
        if self.selectedResultIndex >= 0 and self.selectedTitle {
            article_title_direct = self.selectedTitle;
            print(f"  User picked (direct): '{article_title_direct}'");

            encoded_title_d = urllib.parse.quote(article_title_direct);
            extract_url_d = f"https://en.wikipedia.org/w/api.php?action=query&titles={encoded_title_d}&prop=extracts&exintro=1&explaintext=1&format=json";
            extract_req_d = urllib.request.Request(extract_url_d, headers={"User-Agent": "MaizeMind/1.0"});
            extract_resp_d = urllib.request.urlopen(extract_req_d, timeout=10);
            extract_data_d = json.loads(extract_resp_d.read().decode("utf-8"));

            pages_d = extract_data_d.get("query", {}).get("pages", {});
            summary_d = "";
            for page_id_d in pages_d {
                summary_d = pages_d[page_id_d].get("extract", "");
                break;
            }

            if len(summary_d) > 500 {
                cut_d = summary_d[:500];
                last_period_d = cut_d.rfind(".");
                if last_period_d > 200 {
                    summary_d = cut_d[:last_period_d + 1];
                } else {
                    summary_d = cut_d + "...";
                }
            }

            if self.selectedUrl {
                source_url_d = self.selectedUrl;
            } else {
                wiki_title_d = article_title_direct.replace(" ", "_");
                source_url_d = f"https://en.wikipedia.org/wiki/{urllib.parse.quote(wiki_title_d)}";
            }

            updated_node_d = preserve_node_fields(target_node);
            updated_node_d["moreInfo"] = summary_d;
            updated_node_d["sourceUrl"] = source_url_d;

            new_nodes_d: list = [];
            for n_d in graph_node.nodes {
                if n_d["id"] == self.nodeId {
                    new_nodes_d.append(updated_node_d);
                } else {
                    new_nodes_d.append(n_d);
                }
            }
            graph_node.nodes = new_nodes_d;
            graph_node.updatedAt = str(int(time.time()));

            if self.addAsEvidence and summary_d {
                # Dedup: skip if an EVIDENCE child with same content already SUPPORTS target
                _existing_ev_contents: list = [];
                for _ee in graph_node.edges {
                    if _ee.get("target") == self.nodeId and _ee.get("type") == "SUPPORTS" {
                        for _en in graph_node.nodes {
                            if _en["id"] == _ee.get("source") and _en.get("type") == "EVIDENCE" {
                                _existing_ev_contents.append(_en.get("content", ""));
                            }
                        }
                    }
                }

                ev_content_d = summary_d;
                first_dot_d = summary_d.find(".");
                if first_dot_d > 10 and first_dot_d < 200 {
                    ev_content_d = summary_d[:first_dot_d + 1];
                } elif len(summary_d) > 120 {
                    ev_content_d = summary_d[:120] + "...";
                }

                _is_dup_ev = False;
                for _exc in _existing_ev_contents {
                    if _exc == ev_content_d {
                        _is_dup_ev = True;
                        break;
                    }
                }

                if not _is_dup_ev {
                    ev_id_d = f"node_evidence_{time.time_ns()}";
                    cat_result_d = categorize_evidence_fast(summary_d);
                    ev_category_d = cat_result_d.get("evidence_category", "logical_reasoning");
                    ev_assumptions_d: list = cat_result_d.get("assumptions", []);
                    ev_confidence_d = cat_result_d.get("confidence", 0.6);
                    ev_node_score_d = cat_result_d.get("nodeScore", 50);

                    t_pos_d = target_node.get("position", {"x": 0, "y": 0});
                    ev_x_d = float(t_pos_d.get("x", 0));
                    ev_y_d = float(t_pos_d.get("y", 0)) + 130.0;

                    ev_node_d = {
                        "id": ev_id_d,
                        "type": "EVIDENCE",
                        "content": ev_content_d,
                        "confidence": ev_confidence_d,
                        "isWeak": ev_confidence_d < 0.5,
                        "issues": [],
                        "llmIssueTypes": [],
                        "position": {"x": ev_x_d, "y": ev_y_d},
                        "evidence_category": ev_category_d,
                        "assumptions": ev_assumptions_d,
                        "nodeScore": ev_node_score_d,
                        "sourceUrl": source_url_d,
                        "moreInfo": summary_d,
                        "role": "EVIDENCE",
                        "semanticRole": "EVIDENCE"
                    };
                    updated_nodes_d = list(graph_node.nodes);
                    updated_nodes_d.append(ev_node_d);
                    graph_node.nodes = updated_nodes_d;
                    nw_edge_d = {
                        "id": f"edge_{ev_id_d}",
                        "source": ev_id_d,
                        "target": self.nodeId,
                        "type": "SUPPORTS",
                        "role": "SUPPORTS" if is_business_graph(graph_node) else ""
                    };
                    updated_edges_d = list(graph_node.edges);
                    updated_edges_d.append(nw_edge_d);
                    graph_node.edges = updated_edges_d;
                    graph_node.updatedAt = str(int(time.time()));
                    print(f"  Added evidence node {ev_id_d} from Wikipedia source");
                } else {
                    print(f"  Skipped duplicate evidence (already a child of target node)");
                }
            }

            scorer_d = GetGraphWithScoring(graphId=self.graphId);
            scored_data_d = scorer_d.score_graph(graph_node);

            report {
                "success": True,
                "moreInfo": summary_d,
                "sourceUrl": source_url_d,
                "graph": scored_data_d.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
                "score": scored_data_d.get("score", {}),
                "issues": scored_data_d.get("issues", []),
                "nextActions": scored_data_d.get("nextActions", [])
            };
            return;
        }

        # Use LLM to extract smart search keywords
        raw_keywords = extract_search_keywords(
            node_text=node_content,
            node_type=node_type,
            thesis_text=thesis_text
        );
        search_query = extract_llm_text(raw_keywords).strip().strip('"').strip("'");
        # Fallback if LLM returns empty
        if not search_query or len(search_query) < 3 {
            search_query = node_content[:80];
        }
        print(f"InvestigateNode search query: {search_query}");
        encoded_query = urllib.parse.quote(search_query);

        # Step 1: Search Wikipedia (fetch 5 results for better selection)
        search_url = f"https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch={encoded_query}&format=json&utf8=1&srlimit=5";
        search_req = urllib.request.Request(search_url, headers={"User-Agent": "MaizeMind/1.0"});
        search_resp = urllib.request.urlopen(search_req, timeout=10);
        search_data = json.loads(search_resp.read().decode("utf-8"));

        search_results = search_data.get("query", {}).get("search", []);
        if not search_results {
            report {"error": "No Wikipedia articles found for this topic"};
            return;
        }

        # Collect ALL sourceUrls already used in this graph
        _existing_urls: list = [];
        for _eun in graph_node.nodes {
            _eu_url = _eun.get("sourceUrl", "");
            if _eu_url and _eu_url not in _existing_urls {
                _existing_urls.append(_eu_url);
            }
        }

        # Filter out articles whose Wikipedia URL is already used in the graph
        if _existing_urls {
            filtered_results: list = [];
            for sr in search_results {
                sr_title_slug = sr.get("title", "").replace(" ", "_");
                sr_wiki_url = f"https://en.wikipedia.org/wiki/{urllib.parse.quote(sr_title_slug)}";
                _is_dup = False;
                for _eu in _existing_urls {
                    if sr_title_slug in _eu or _eu == sr_wiki_url {
                        _is_dup = True;
                        break;
                    }
                }
                if not _is_dup {
                    filtered_results.append(sr);
                }
            }
            if not filtered_results {
                report {
                    "success": True,
                    "already_sourced": True,
                    "moreInfo": target_node.get("moreInfo", ""),
                    "sourceUrl": existing_source,
                    "message": "All relevant Wikipedia sources are already used in your graph."
                };
                return;
            }
            search_results = filtered_results;
            print(f"  Filtered out {len(_existing_urls)} existing sources, {len(search_results)} candidates remain");
        }

        # Take top 3 results
        top_results: list = [];
        _tri = 0;
        while _tri < len(search_results) and _tri < 3 {
            top_results.append(search_results[_tri]);
            _tri = _tri + 1;
        }

        # ── Phase 1: Return 3 results for user to pick ──
        if self.selectedResultIndex < 0 {
            wiki_results: list = [];
            _wri = 0;
            while _wri < len(top_results) {
                sr = top_results[_wri];
                sr_title = sr.get("title", "");
                sr_snippet = sr.get("snippet", "").replace("<span class=\"searchmatch\">", "").replace("</span>", "");

                # Fetch extract summary for each result
                enc_title = urllib.parse.quote(sr_title);
                ext_url = f"https://en.wikipedia.org/w/api.php?action=query&titles={enc_title}&prop=extracts&exintro=1&explaintext=1&format=json";
                ext_req = urllib.request.Request(ext_url, headers={"User-Agent": "MaizeMind/1.0"});
                ext_resp = urllib.request.urlopen(ext_req, timeout=10);
                ext_data = json.loads(ext_resp.read().decode("utf-8"));

                ext_pages = ext_data.get("query", {}).get("pages", {});
                ext_summary = "";
                for pid in ext_pages {
                    ext_summary = ext_pages[pid].get("extract", "");
                    break;
                }

                # Truncate to ~300 chars at sentence boundary
                if len(ext_summary) > 300 {
                    cut = ext_summary[:300];
                    last_period = cut.rfind(".");
                    if last_period > 100 {
                        ext_summary = cut[:last_period + 1];
                    } else {
                        ext_summary = cut + "...";
                    }
                }

                wiki_title = sr_title.replace(" ", "_");
                wiki_url = f"https://en.wikipedia.org/wiki/{urllib.parse.quote(wiki_title)}";

                wiki_results.append({
                    "title": sr_title,
                    "summary": ext_summary,
                    "url": wiki_url,
                    "snippet": sr_snippet
                });
                _wri = _wri + 1;
            }

            print(f"  Returning {len(wiki_results)} Wikipedia results for user selection");
            report {
                "success": True,
                "phase": "results",
                "wikiResults": wiki_results
            };
            return;
        }

        # ── Phase 2: User picked a result — apply it ──
        pick_idx = self.selectedResultIndex;
        if pick_idx < 0 or pick_idx >= len(top_results) {
            pick_idx = 0;
        }

        article_title = top_results[pick_idx]["title"];
        print(f"  User picked: '{article_title}' (index {pick_idx})");

        # Fetch full extract for selected result
        encoded_title = urllib.parse.quote(article_title);
        extract_url = f"https://en.wikipedia.org/w/api.php?action=query&titles={encoded_title}&prop=extracts&exintro=1&explaintext=1&format=json";
        extract_req = urllib.request.Request(extract_url, headers={"User-Agent": "MaizeMind/1.0"});
        extract_resp = urllib.request.urlopen(extract_req, timeout=10);
        extract_data = json.loads(extract_resp.read().decode("utf-8"));

        pages = extract_data.get("query", {}).get("pages", {});
        summary = "";
        for page_id in pages {
            summary = pages[page_id].get("extract", "");
            break;
        }

        # Truncate summary to ~500 chars at sentence boundary
        if len(summary) > 500 {
            cut = summary[:500];
            last_period = cut.rfind(".");
            if last_period > 200 {
                summary = cut[:last_period + 1];
            } else {
                summary = cut + "...";
            }
        }

        # Build Wikipedia URL
        wiki_title = article_title.replace(" ", "_");
        source_url = f"https://en.wikipedia.org/wiki/{urllib.parse.quote(wiki_title)}";

        # Update node with investigation results
        updated_node = preserve_node_fields(target_node);
        updated_node["moreInfo"] = summary;
        updated_node["sourceUrl"] = source_url;

        new_nodes: list = [];
        for n in graph_node.nodes {
            if n["id"] == self.nodeId {
                new_nodes.append(updated_node);
            } else {
                new_nodes.append(n);
            }
        }
        graph_node.nodes = new_nodes;
        graph_node.updatedAt = str(int(time.time()));

        # If addAsEvidence, also create an evidence node with the Wikipedia content
        if self.addAsEvidence and summary {
            ev_id = f"node_evidence_{time.time_ns()}";
            cat_result = categorize_evidence_fast(summary);
            ev_category = cat_result.get("evidence_category", "logical_reasoning");
            ev_assumptions: list = cat_result.get("assumptions", []);
            ev_confidence = cat_result.get("confidence", 0.6);
            ev_node_score = cat_result.get("nodeScore", 50);

            # Position below target node
            t_pos = target_node.get("position", {"x": 0, "y": 0});
            ev_x = float(t_pos.get("x", 0));
            ev_y = float(t_pos.get("y", 0)) + 130.0;

            # Truncate to first sentence for the node title
            ev_content = summary;
            first_dot = summary.find(".");
            if first_dot > 10 and first_dot < 200 {
                ev_content = summary[:first_dot + 1];
            } elif len(summary) > 120 {
                ev_content = summary[:120] + "...";
            }

            ev_node = {
                "id": ev_id,
                "type": "EVIDENCE",
                "content": ev_content,
                "confidence": ev_confidence,
                "isWeak": ev_confidence < 0.5,
                "issues": [],
                "llmIssueTypes": [],
                "position": {"x": ev_x, "y": ev_y},
                "evidence_category": ev_category,
                "assumptions": ev_assumptions,
                "nodeScore": ev_node_score,
                "sourceUrl": source_url,
                "moreInfo": summary,
                "role": "EVIDENCE",
                "semanticRole": "EVIDENCE"
            };
            updated_nodes = list(graph_node.nodes);
            updated_nodes.append(ev_node);
            graph_node.nodes = updated_nodes;
            nw_edge = {
                "id": f"edge_{ev_id}",
                "source": ev_id,
                "target": self.nodeId,
                "type": "SUPPORTS",
                "role": "SUPPORTS" if is_business_graph(graph_node) else ""
            };
            updated_edges = list(graph_node.edges);
            updated_edges.append(nw_edge);
            graph_node.edges = updated_edges;
            graph_node.updatedAt = str(int(time.time()));
            print(f"  Added evidence node {ev_id} from Wikipedia source");
        }

        # Return full scored result
        scorer = GetGraphWithScoring(graphId=self.graphId);
        scored_data = scorer.score_graph(graph_node);

        report {
            "success": True,
            "moreInfo": summary,
            "sourceUrl": source_url,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"InvestigateNode ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub ExpandBranch {
    has graphId: str,
        nodeId: str;

    can run with Root entry {
        try {
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

        # Find target node and thesis
        target_node = None;
        thesis_text = "";
        for n in graph_node.nodes {
            if n["id"] == self.nodeId {
                target_node = n;
            }
            if n["type"] == "THESIS" {
                thesis_text = n.get("content", "");
            }
        }

        if not target_node {
            report {"error": "Node not found"};
            return;
        }

        node_content = target_node.get("content", "");
        node_type = target_node.get("type", "CLAIM");

        # Call LLM to generate branches
        raw_result = expand_branch(
            node_text=node_content,
            node_type=node_type,
            thesis_text=thesis_text
        );
        raw_str = extract_llm_text(raw_result).strip();
        if raw_str.startswith("```") {
            fence_lines = raw_str.split("\n");
            fence_lines = fence_lines[1:];
            if fence_lines and fence_lines[-1].strip().startswith("```") {
                fence_lines = fence_lines[:-1];
            }
            raw_str = "\n".join(fence_lines).strip();
        }
        parsed = json.loads(raw_str);
        branches = parsed.get("branches", []);

        if not branches {
            report {"error": "LLM returned empty branches"};
            return;
        }

        # Get target position for layout
        target_pos_x = 0.0;
        target_pos_y = 0.0;
        for tn in graph_node.nodes {
            if tn["id"] == self.nodeId {
                tp = tn.get("position", {"x": 0, "y": 0});
                target_pos_x = float(tp.get("x", 0));
                target_pos_y = float(tp.get("y", 0));
            }
        }

        now_ts = int(time.time());
        branch_idx = 0;
        for b in branches {
            if branch_idx >= 3 { break; }  # Max 3 branches
            b_content = b.get("content", "");
            b_type_raw = b.get("type", "claim").upper();
            if b_type_raw == "EVIDENCE" {
                b_type = "EVIDENCE";
            } else {
                b_type = "CLAIM";
            }

            if not b_content { branch_idx = branch_idx + 1; continue; }

            # Capitalize
            if len(b_content) > 1 {
                b_content = b_content[0].upper() + b_content[1:];
            } elif len(b_content) == 1 {
                b_content = b_content[0].upper();
            }

            # Use LLM-provided confidence if available, else fast categorizer
            b_raw_conf = b.get("confidence", 0.5);
            try {
                b_confidence = float(b_raw_conf);
            } except Exception {
                b_confidence = 0.5;
            }
            if b_confidence > 1.0 { b_confidence = 1.0; }
            if b_confidence < 0.1 { b_confidence = 0.1; }

            b_category = "";
            b_node_score = int(b_confidence * 100);
            if b_type == "EVIDENCE" {
                cat_res = categorize_evidence_fast(b_content);
                b_category = cat_res.get("evidence_category", "logical_reasoning");
                # Use LLM confidence but cap by category quality
                cat_weights: dict[str, float] = {
                    "empirical_data": 0.9, "expert_testimony": 0.8,
                    "logical_reasoning": 0.6, "analogy": 0.5, "anecdotal": 0.3
                };
                cat_quality = cat_weights.get(b_category, 0.6);
                combined = cat_quality * 0.4 + b_confidence * 0.6;
                b_node_score = int(combined * 100);
            }

            branch_role = "";
            if b_type == "EVIDENCE" {
                branch_role = "EVIDENCE";
            } elif is_business_graph(graph_node) {
                target_role = business_semantic_role(target_node);
                if target_role == "OPEN_QUESTION" or target_role == "RISK" {
                    branch_role = "ACTION";
                } else {
                    branch_role = "OPTION";
                }
            }

            branch_id = f"node_branch_{now_ts}_{branch_idx}";
            chosen_pos = choose_expand_position(
                graph_node=graph_node,
                target_node=target_node,
                branch_role=branch_role,
                branch_type=b_type,
                branch_content=b_content,
                target_x=target_pos_x,
                target_y=target_pos_y
            );
            new_x = float(chosen_pos["x"]) if "x" in chosen_pos else target_pos_x;
            new_y = float(chosen_pos["y"]) if "y" in chosen_pos else (target_pos_y + 145.0);

            new_node = {
                "id": branch_id,
                "type": b_type,
                "content": b_content,
                "confidence": b_confidence,
                "isWeak": b_confidence < 0.5,
                "issues": [],
                "llmIssueTypes": [],
                "position": {"x": new_x, "y": new_y},
                "evidence_category": b_category,
                "assumptions": [],
                "nodeScore": b_node_score,
                "sourceUrl": "",
                "role": branch_role,
                "semanticRole": branch_role
            };
            updated_nodes = list(graph_node.nodes);
            updated_nodes.append(new_node);
            graph_node.nodes = updated_nodes;

            edge_type = "SUPPORTS";
            edge_role = "SUPPORTS";
            edge_source = branch_id;
            edge_target = self.nodeId;
            if is_business_graph(graph_node) and target_node {
                target_role = business_semantic_role(target_node);
                if branch_role == "OPTION" and target_role == "DECISION" {
                    edge_type = "HAS_OPTION";
                    edge_role = "HAS_OPTION";
                    edge_source = self.nodeId;
                    edge_target = branch_id;
                } elif branch_role == "ACTION" {
                    action_edge = action_edge_payload(graph_node, target_node, branch_id);
                    edge_type = action_edge["type"] if "type" in action_edge else "RESOLVES";
                    edge_role = action_edge["role"] if "role" in action_edge else edge_type;
                    edge_source = action_edge["source"] if "source" in action_edge else branch_id;
                    edge_target = action_edge["target"] if "target" in action_edge else self.nodeId;
                }
            }

            new_edge = {
                "id": f"edge_{branch_id}",
                "source": edge_source,
                "target": edge_target,
                "type": edge_type,
                "role": edge_role if is_business_graph(graph_node) else ""
            };
            updated_edges = list(graph_node.edges);
            updated_edges.append(new_edge);
            graph_node.edges = updated_edges;
            branch_idx = branch_idx + 1;
        }

        graph_node.updatedAt = str(int(time.time()));

        # Call scoring methods directly on the walker instance
        scorer = GetGraphWithScoring(graphId=self.graphId);
        scored_data = scorer.score_graph(graph_node);

        report {
            "success": True,
            "branchCount": branch_idx,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"ExpandBranch ERROR: {e}");
            report {"error": str(e)};
        }
    }
}
