"""Walkers for generating and scoring argument graphs."""

import from graph.argument_graph_nodes { ArgumentGraph }
import from src.graph_generator { Document, generate_argument_graph }

walker:pub GenerateArgumentGraph {
    has notes: str,
        userId: str,
        mode: str = "education_argument",
        template: str = "";

    can run with Root entry {
        print("=== GenerateArgumentGraph ENTERED ===");
        print(f"=== userId={self.userId}, notes length={len(self.notes)} ===");
        try {
        import time;
        graph_id = f"graph_{int(time.time())}";

        docs: list[Document] = [];
        # Retry up to 2 times if LLM returns empty
        result = generate_argument_graph(self.notes, docs, [], [], self.mode, self.template);
        result_nodes = result["nodes"] if "nodes" in result else [];
        print(f"  [First attempt] Got {len(result_nodes)} nodes");
        if not result_nodes or len(result_nodes) == 0 {
            print("  [RETRY] LLM returned empty, retrying...");
            result = generate_argument_graph(self.notes, docs, [], [], self.mode, self.template);
            result_nodes = result["nodes"] if "nodes" in result else [];
            print(f"  [Retry] Got {len(result_nodes)} nodes");
        }
        raw_nodes = result["nodes"] if "nodes" in result else [];
        raw_edges = result["edges"] if "edges" in result else [];
        graph_mode = result["graph_mode"] if "graph_mode" in result else (result["graphMode"] if "graphMode" in result else self.mode);
        graph_template = result["template"] if "template" in result else self.template;
        graph_title = result["title"] if "title" in result else "";
        graph_summary = result["summaryText"] if "summaryText" in result else "";
        schema_version = result["schema_version"] if "schema_version" in result else "";
        board_id = result["board_id"] if "board_id" in result else graph_id;
        primary_decision_id = result["primary_decision_id"] if "primary_decision_id" in result else "";
        meeting_meta = result["meeting"] if "meeting" in result and isinstance(result["meeting"], dict) else {};

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
                "nodeScore": 50,
                "role": n.get("role", n.get("semanticRole", "")),
                "semanticRole": n.get("semanticRole", n.get("role", "")),
                "source_span_ids": list(n.get("source_span_ids", [])) if isinstance(n.get("source_span_ids", []), list) else [],
                "speaker_ids": list(n.get("speaker_ids", [])) if isinstance(n.get("speaker_ids", []), list) else [],
                "origin": n.get("origin", ""),
                "question": n.get("question", ""),
                "decision_status": n.get("decision_status", n.get("status", "")),
                "resolution_text": n.get("resolution_text", ""),
                "scope": n.get("scope", ""),
                "time_horizon": n.get("time_horizon", ""),
                "option_status": n.get("option_status", ""),
                "evidence_kind": n.get("evidence_kind", ""),
                "criterion_tags": list(n.get("criterion_tags", [])) if isinstance(n.get("criterion_tags", []), list) else [],
                "risk_kind": n.get("risk_kind", ""),
                "severity": n.get("severity", ""),
                "is_blocker": n.get("is_blocker", False),
                "assumption_status": n.get("assumption_status", ""),
                "question_status": n.get("question_status", ""),
                "owner": n.get("owner", ""),
                "owners": list(n.get("owners", [])) if isinstance(n.get("owners", []), list) else ([] if not n.get("owner", "") else [n.get("owner", "")]),
                "dueDate": n.get("dueDate", n.get("due_date", "")),
                "due_date": n.get("due_date", n.get("dueDate", "")),
                "priority": n.get("priority", ""),
                "taskStatus": n.get("taskStatus", n.get("task_status", n.get("action_status", ""))),
                "task_status": n.get("task_status", n.get("taskStatus", n.get("action_status", ""))),
                "action_status": n.get("action_status", n.get("taskStatus", n.get("task_status", "")))
            });
        }

        fe_edges: list[dict] = [];
        for (i, e) in enumerate(raw_edges) {
            raw_etype = e.get("type", "supports").lower();
            raw_role = str(e.get("role", raw_etype)).upper();
            fe_etype = edge_type_map.get(raw_etype, "SUPPORTS");
            if graph_mode == "business_meeting_decision" {
                fe_etype = raw_role if raw_role else raw_etype.upper();
            }
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
                "source": e.get("source_id", e.get("from_id", "")),
                "target": e.get("target_id", e.get("to_id", "")),
                "type": fe_etype,
                "role": raw_role if raw_role else fe_etype,
                "weight": e_weight,
                "confidence": e.get("confidence", e_weight),
                "reasoning_type": e_reasoning
            });
        }

        if graph_mode == "business_meeting_decision" {
            business_positions = self.build_business_layout(fe_nodes, fe_edges);
            for node_data in fe_nodes {
                node_id = node_data.get("id", "");
                if node_id in business_positions {
                    node_data["position"] = business_positions[node_id];
                }
            }
        }

        new_graph = (root ++> ArgumentGraph(
            id=graph_id,
            nodes=fe_nodes,
            edges=fe_edges,
            graphMode=graph_mode,
            graph_mode=graph_mode,
            schema_version=schema_version,
            board_id=board_id,
            primary_decision_id=primary_decision_id,
            meeting=meeting_meta,
            template=graph_template,
            title=graph_title,
            summary=graph_summary,
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
                "graphMode": graph_mode,
                "graph_mode": graph_mode,
                "schema_version": schema_version,
                "board_id": board_id,
                "primary_decision_id": primary_decision_id,
                "meeting": meeting_meta,
                "template": graph_template,
                "title": graph_title,
                "summary": graph_summary,
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

    """Sentence-case: capitalize first letter of each sentence."""
    def capitalize_text(text: str) -> str {      
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

    def business_semantic_role(node_data: dict) -> str {
        role = str(node_data.get("role", node_data.get("semanticRole", ""))).upper().strip();
        if role == "NEXT_ACTION" { role = "ACTION"; }
        if role { return role; }
        ntype = str(node_data.get("type", "CLAIM")).upper().strip();
        if ntype == "THESIS" { return "DECISION"; }
        if ntype == "EVIDENCE" { return "EVIDENCE"; }
        if ntype == "COUNTERARGUMENT" { return "RISK"; }
        return "OPTION";
    }

    def business_edge_role(edge_data: dict) -> str {
        raw_role = str(edge_data.get("role", edge_data.get("type", ""))).upper().strip();
        if raw_role == "CONTRADICTS" { return "OPPOSES"; }
        if raw_role == "ADDRESSES" { return "RESOLVES"; }
        if raw_role == "NEXT_ACTION" { return "ACTION"; }
        return raw_role;
    }

    def build_business_layout(nodes: list[dict], edges: list[dict]) -> dict {
        positions: dict = {};
        if len(nodes) == 0 { return positions; }

        center_x = 640.0;
        decision_y = 120.0;
        option_y = 320.0;
        right_lane_x = 980.0;
        left_lane_x = 260.0;
        rail_gap_y = 118.0;

        decision_ids: list = [];
        option_ids: list = [];
        evidence_ids: list = [];
        risk_ids: list = [];
        question_ids: list = [];
        action_ids: list = [];
        assumption_ids: list = [];
        other_ids: list = [];

        ni = 0;
        while ni < len(nodes) {
            node_id = nodes[ni].get("id", "");
            role = self.business_semantic_role(nodes[ni]);
            if role == "DECISION" {
                decision_ids.append(node_id);
            } elif role == "OPTION" {
                option_ids.append(node_id);
            } elif role == "EVIDENCE" {
                evidence_ids.append(node_id);
            } elif role == "RISK" {
                risk_ids.append(node_id);
            } elif role == "OPEN_QUESTION" {
                question_ids.append(node_id);
            } elif role == "ACTION" {
                action_ids.append(node_id);
            } elif role == "ASSUMPTION" {
                assumption_ids.append(node_id);
            } else {
                other_ids.append(node_id);
            }
            ni = ni + 1;
        }

        decision_id = "";
        if len(decision_ids) > 0 {
            decision_id = decision_ids[0];
        } elif len(nodes) > 0 {
            decision_id = nodes[0].get("id", "");
        }
        if decision_id {
            positions[decision_id] = {"x": center_x, "y": decision_y};
        }

        option_count = len(option_ids);
        if option_count == 0 and len(other_ids) > 0 {
            option_ids = list(other_ids);
            option_count = len(option_ids);
            other_ids = [];
        }
        oi = 0;
        while oi < option_count {
            option_x = center_x + (oi - (option_count - 1) / 2.0) * 280.0;
            positions[option_ids[oi]] = {"x": option_x, "y": option_y};
            oi = oi + 1;
        }

        max_y_used = option_y;
        right_lane_y = option_y;
        left_lane_y = option_y;

        option_evidence_map: dict = {};
        risk_target_map: dict = {};
        question_target_map: dict = {};
        action_target_map: dict = {};
        ei = 0;
        while ei < len(edges) {
            edge_type = self.business_edge_role(edges[ei]);
            src = edges[ei].get("source", "");
            tgt = edges[ei].get("target", "");
            if edge_type == "SUPPORTS" {
                bucket: list = list(option_evidence_map[tgt]) if tgt in option_evidence_map else [];
                bucket.append(src);
                option_evidence_map[tgt] = bucket;
            } elif edge_type == "OPPOSES" or edge_type == "BLOCKS" {
                risk_target_map[src] = tgt;
                if edge_type == "BLOCKS" {
                    question_target_map[src] = tgt;
                }
            } elif edge_type == "RESOLVES" or edge_type == "IMPLEMENTS" {
                action_target_map[src] = tgt;
            }
            ei = ei + 1;
        }

        if len(option_ids) > 0 {
            min_option_x = positions[option_ids[0]]["x"];
            max_option_x = positions[option_ids[0]]["x"];
            oi = 0;
            while oi < len(option_ids) {
                pos_x = positions[option_ids[oi]]["x"];
                if pos_x < min_option_x { min_option_x = pos_x; }
                if pos_x > max_option_x { max_option_x = pos_x; }
                oi = oi + 1;
            }
            right_lane_x = max_option_x + 340.0;
            left_lane_x = min_option_x - 340.0;
        }

        oi = 0;
        while oi < len(option_ids) {
            option_id = option_ids[oi];
            child_ids = list(option_evidence_map[option_id]) if option_id in option_evidence_map else [];
            row_index = 0;
            ci = 0;
            while ci < len(child_ids) {
                child_id = child_ids[ci];
                if child_id in evidence_ids or child_id in assumption_ids {
                    child_x = positions[option_id]["x"] + ((row_index % 2) * 120.0 - 60.0);
                    child_y = option_y + 170.0 + int(row_index / 2) * 124.0;
                    positions[child_id] = {"x": child_x, "y": child_y};
                    if child_y > max_y_used { max_y_used = child_y; }
                    row_index = row_index + 1;
                }
                ci = ci + 1;
            }
            oi = oi + 1;
        }

        ri = 0;
        while ri < len(risk_ids) {
            risk_id = risk_ids[ri];
            target_id = risk_target_map[risk_id] if risk_id in risk_target_map else decision_id;
            target_y = positions[target_id]["y"] if target_id in positions else right_lane_y;
            positions[risk_id] = {
                "x": right_lane_x,
                "y": target_y + (ri - (len(risk_ids) - 1) / 2.0) * rail_gap_y
            };
            if positions[risk_id]["y"] > max_y_used { max_y_used = positions[risk_id]["y"]; }
            ri = ri + 1;
        }

        qi = 0;
        while qi < len(question_ids) {
            target_id = question_target_map[question_ids[qi]] if question_ids[qi] in question_target_map else "";
            target_y = positions[target_id]["y"] if target_id in positions else left_lane_y;
            positions[question_ids[qi]] = {
                "x": left_lane_x,
                "y": target_y + (qi - (len(question_ids) - 1) / 2.0) * rail_gap_y
            };
            if positions[question_ids[qi]]["y"] > max_y_used { max_y_used = positions[question_ids[qi]]["y"]; }
            qi = qi + 1;
        }

        ai = 0;
        while ai < len(assumption_ids) {
            positions[assumption_ids[ai]] = {
                "x": left_lane_x,
                "y": left_lane_y + (len(question_ids) + ai) * rail_gap_y
            };
            if positions[assumption_ids[ai]]["y"] > max_y_used { max_y_used = positions[assumption_ids[ai]]["y"]; }
            ai = ai + 1;
        }

        action_y = max_y_used + 180.0;
        action_count = len(action_ids);
        ai = 0;
        while ai < action_count {
            action_x = center_x + (ai - (action_count - 1) / 2.0) * 260.0;
            if action_ids[ai] in action_target_map {
                target_id = action_target_map[action_ids[ai]];
                if target_id in positions {
                    action_x = positions[target_id]["x"];
                }
            }
            positions[action_ids[ai]] = {"x": action_x, "y": action_y};
            ai = ai + 1;
        }

        oi = 0;
        while oi < len(other_ids) {
            positions[other_ids[oi]] = {
                "x": center_x + (oi - (len(other_ids) - 1) / 2.0) * 240.0,
                "y": action_y + 140.0
            };
            oi = oi + 1;
        }

        return positions;
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

        graph_mode = graph_node.graph_mode if hasattr(graph_node, "graph_mode") and graph_node.graph_mode else (graph_node.graphMode if hasattr(graph_node, "graphMode") else "education_argument");
        if graph_mode == "business_meeting_decision" {
            score = self.calculate_business_score(graph_node.nodes, graph_node.edges);
            issues = self.identify_business_issues(graph_node.nodes, graph_node.edges, score);
            next_actions = self.build_business_next_actions(graph_node.nodes, graph_node.edges, issues);
            self.annotate_business_nodes(graph_node.nodes, graph_node.edges, issues);
        } else {
            score = self.calculate_score(graph_node.nodes, graph_node.edges);
            issues = self.identify_issues(graph_node.nodes, graph_node.edges, score);
            next_actions = self.build_next_actions(issues);
            self.annotate_nodes(graph_node.nodes, graph_node.edges, issues);
        }

        report {
            "graph": {
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
            },
            "score": score,
            "issues": issues,
            "nextActions": next_actions
        };
    }

    def score_graph(graph_node: obj) -> dict {
        nodes = graph_node.nodes;
        edges = graph_node.edges;
        graph_mode = graph_node.graph_mode if hasattr(graph_node, "graph_mode") and graph_node.graph_mode else (graph_node.graphMode if hasattr(graph_node, "graphMode") else "education_argument");
        if graph_mode == "business_meeting_decision" {
            score = self.calculate_business_score(nodes, edges);
            issues = self.identify_business_issues(nodes, edges, score);
            next_actions = self.build_business_next_actions(nodes, edges, issues);
            self.annotate_business_nodes(nodes, edges, issues);
        } else {
            score = self.calculate_score(nodes, edges);
            issues = self.identify_issues(nodes, edges, score);
            next_actions = self.build_next_actions(issues);
            self.annotate_nodes(nodes, edges, issues);
        }
        return {
            "graph": {
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
            },
            "score": score,
            "issues": issues,
            "nextActions": next_actions
        };
    }

    def score_graph_snapshot(graph_node: obj) -> dict {
        nodes = graph_node.nodes;
        edges = graph_node.edges;
        graph_mode = graph_node.graph_mode if hasattr(graph_node, "graph_mode") and graph_node.graph_mode else (graph_node.graphMode if hasattr(graph_node, "graphMode") else "education_argument");
        if graph_mode == "business_meeting_decision" {
            score = self.calculate_business_score(nodes, edges);
            issues = self.identify_business_issues(nodes, edges, score);
            next_actions = self.build_business_next_actions(nodes, edges, issues);
        } else {
            score = self.calculate_score(nodes, edges);
            issues = self.identify_issues(nodes, edges, score);
            next_actions = self.build_next_actions(issues);
        }
        return {
            "score": score,
            "issues": issues,
            "nextActions": next_actions
        };
    }

    def score_graph_legacy_snapshot(graph_node: obj) -> dict {
        graph_mode = graph_node.graph_mode if hasattr(graph_node, "graph_mode") and graph_node.graph_mode else (graph_node.graphMode if hasattr(graph_node, "graphMode") else "education_argument");
        if graph_mode == "business_meeting_decision" {
            return {
                "available": False,
                "reason": "Legacy comparator is only available for education_argument graphs."
            };
        }

        nodes = graph_node.nodes;
        edges = graph_node.edges;
        score = self.calculate_score_legacy(nodes, edges);
        issues = self.identify_issues_legacy(nodes, edges, score);
        next_actions = self.build_next_actions_legacy(issues);
        return {
            "available": True,
            "score": score,
            "issues": issues,
            "nextActions": next_actions
        };
    }

    def compare_score_versions(graph_node: obj) -> dict {
        graph_mode = graph_node.graph_mode if hasattr(graph_node, "graph_mode") and graph_node.graph_mode else (graph_node.graphMode if hasattr(graph_node, "graphMode") else "education_argument");
        current_result = self.score_graph_snapshot(graph_node);
        legacy_result = self.score_graph_legacy_snapshot(graph_node);
        if not legacy_result.get("available", False) {
            return {
                "graphMode": graph_mode,
                "current": current_result,
                "legacyAvailable": False,
                "legacy": None,
                "legacyNote": legacy_result.get("reason", ""),
                "delta": {}
            };
        }

        current_score = current_result.get("score", {});
        legacy_score = legacy_result.get("score", {});
        current_issues = current_result.get("issues", []);
        legacy_issues = legacy_result.get("issues", []);
        current_actions = current_result.get("nextActions", []);
        legacy_actions = legacy_result.get("nextActions", []);

        return {
            "graphMode": graph_mode,
            "current": current_result,
            "legacyAvailable": True,
            "legacy": legacy_result,
            "legacyNote": "",
            "delta": {
                "overall": int(self.to_float(current_score.get("overall", 0), 0.0) - self.to_float(legacy_score.get("overall", 0), 0.0)),
                "issueCount": len(current_issues) - len(legacy_issues),
                "nextActionCount": len(current_actions) - len(legacy_actions),
                "passesBarChanged": bool(current_score.get("passesBar", False)) != bool(legacy_score.get("passesBar", False))
            }
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

    def evidence_quality_legacy(node_data: dict) -> float {
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

    def claim_support_score_legacy(nodes: list, edges: list, claim_id: str) -> float {
        total_support = 0.0;
        evidence_count = 0;
        for e in edges {
            if e.get("type", "") == "SUPPORTS" and e.get("target", "") == claim_id {
                src_node = self.get_node(nodes, e.get("source", ""));
                if src_node and src_node.get("type", "") == "EVIDENCE" {
                    evidence_count = evidence_count + 1;
                    total_support = total_support + self.edge_weight(e) * self.evidence_quality_legacy(src_node);
                }
            }
        }
        if evidence_count == 0 {
            return 0.0;
        }
        if total_support > 1.0 { total_support = 1.0; }
        return self.clamp01(total_support);
    }

    def has_assumption_legacy(nodes: list, edges: list, claim_id: str) -> bool {
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

    def claim_connected_to_thesis_legacy(nodes: list, edges: list, claim_id: str, thesis_ids: list) -> bool {
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

    def contradiction_unresolved_legacy(nodes: list, edges: list, contradiction_edge: dict) -> bool {
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

    def get_thesis_ids_legacy(nodes: list, edges: list) -> list {
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

    def calculate_score_legacy(nodes: list, edges: list) -> dict {
        claims = self.get_claims(nodes);
        total_claims = len(claims);
        total_nodes = len(nodes);

        thesis_ids = self.get_thesis_ids_legacy(nodes, edges);
        contradictions = [e for e in edges if e.get("type", "") == "CONTRADICTS"];
        total_contradictions = len(contradictions);
        unresolved_contradictions = 0;
        for ce in contradictions {
            if self.contradiction_unresolved_legacy(nodes, edges, ce) {
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

        support_sum = 0.0;
        unsupported_claims = 0;
        thesis_supported = True;
        if len(thesis_ids) == 0 {
            thesis_supported = False;
        }
        for c in claims {
            cid = c.get("id", "");
            c_support = self.claim_support_score_legacy(nodes, edges, cid);
            support_sum = support_sum + c_support;
            if c_support < 0.10 {
                unsupported_claims = unsupported_claims + 1;
            }
            if cid in thesis_ids and c_support < 0.25 {
                thesis_supported = False;
            }
        }
        support_quality = self.clamp01(support_sum / max(1, total_claims));

        logical_penalty = 0.0;
        claims_needing_premise = 0;
        weak_inference_claims = 0;
        vague_claims = 0;
        for c in claims {
            cid = c.get("id", "");
            if self.has_issue_type(c, "missing_premise") and not self.has_assumption_legacy(nodes, edges, cid) {
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
            if not self.claim_connected_to_thesis_legacy(nodes, edges, cid, thesis_ids) {
                disconnected_claims = disconnected_claims + 1;
            }
        }

        orphan_ratio = orphan_nodes / max(1, total_nodes);
        disconnected_ratio = disconnected_claims / max(1, total_claims);
        coherence = self.clamp01(1.0 - (0.7 * orphan_ratio + 0.3 * disconnected_ratio));

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

    def identify_issues_legacy(nodes: list, edges: list, score: dict) -> list {
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
            c_support = self.claim_support_score_legacy(nodes, edges, cid);

            if c_support < 0.10 {
                issues.append({
                    "id": f"legacy_issue_{issue_index}",
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
                    "id": f"legacy_issue_{issue_index}",
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

            if self.has_issue_type(c, "missing_premise") and not self.has_assumption_legacy(nodes, edges, cid) {
                issues.append({
                    "id": f"legacy_issue_{issue_index}",
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
                    "id": f"legacy_issue_{issue_index}",
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
                    "id": f"legacy_issue_{issue_index}",
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
            if not self.contradiction_unresolved_legacy(nodes, edges, ce) {
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
                "id": f"legacy_issue_{issue_index}",
                "nodeId": issue_node_id,
                "severity": "high",
                "type": "unresolved_contradiction",
                "description": "A contradiction is unaddressed",
                "suggestedAction": "Add a response that addresses this counterargument, or mark it as acknowledged.",
                "area": "Counterargument Handling",
                "estimatedLift": counter_unit + 2
            });
            issue_index = issue_index + 1;
        }

        thesis_ids = self.get_thesis_ids_legacy(nodes, edges);
        for c in claims {
            cid = c.get("id", "");
            if not self.claim_connected_to_thesis_legacy(nodes, edges, cid, thesis_ids) {
                issues.append({
                    "id": f"legacy_issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "medium",
                    "type": "disconnected_claim",
                    "description": "This claim is disconnected from the main thesis path",
                    "suggestedAction": "Link this claim to the thesis or a parent claim so it supports the argument.",
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
                    "id": f"legacy_issue_{issue_index}",
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

        sorted_issues = self.sort_legacy_issues_by_priority(issues);
        return sorted_issues[:12];
    }

    def legacy_severity_weight(severity: str) -> int {
        sev = severity.lower().strip();
        if sev == "high" { return 300; }
        if sev == "medium" { return 200; }
        return 100;
    }

    def legacy_issue_priority(issue: dict) -> int {
        sev_w = self.legacy_severity_weight(issue.get("severity", "low"));
        lift = int(self.to_float(issue.get("estimatedLift", 0), 0.0));
        return sev_w + lift * 5;
    }

    def sort_legacy_issues_by_priority(issues: list) -> list {
        sorted_list: list = list(issues);
        i = 0;
        while i < len(sorted_list) {
            best_idx = i;
            j = i + 1;
            while j < len(sorted_list) {
                if self.legacy_issue_priority(sorted_list[j]) > self.legacy_issue_priority(sorted_list[best_idx]) {
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

    def build_next_actions_legacy(issues: list) -> list {
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
                "id": f"legacy_next_{action_count + 1}",
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
                    "id": f"legacy_next_{action_count + 1}",
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

    def semantic_role(node_data: dict) -> str {
        if not node_data { return ""; }
        role = str(node_data.get("role", node_data.get("semanticRole", ""))).upper().strip();
        if role == "NEXT_ACTION" { role = "ACTION"; }
        if role { return role; }
        ntype = str(node_data.get("type", "")).upper().strip();
        if ntype == "THESIS" { return "DECISION"; }
        if ntype == "EVIDENCE" { return "EVIDENCE"; }
        if ntype == "COUNTERARGUMENT" { return "RISK"; }
        return "OPTION";
    }

    def edge_role(edge_data: dict) -> str {
        if not edge_data { return ""; }
        role = str(edge_data.get("role", edge_data.get("type", ""))).upper().strip();
        if role == "CONTRADICTS" { return "OPPOSES"; }
        if role == "ADDRESSES" { return "RESOLVES"; }
        return role;
    }

    def nodes_with_role(nodes: list, role: str) -> list {
        result: list = [];
        ri = 0;
        target = role.upper().strip();
        while ri < len(nodes) {
            if self.semantic_role(nodes[ri]) == target {
                result.append(nodes[ri]);
            }
            ri = ri + 1;
        }
        return result;
    }

    def target_ids_for_edge_type(edges: list, source_id: str, edge_type: str) -> list {
        result: list = [];
        ei = 0;
        while ei < len(edges) {
            if edges[ei].get("source", "") == source_id and edges[ei].get("type", "") == edge_type {
                result.append(edges[ei].get("target", ""));
            }
            ei = ei + 1;
        }
        return result;
    }

    def target_ids_for_edge_role(edges: list, source_id: str, edge_role: str) -> list {
        result: list = [];
        target_role = edge_role.upper().strip();
        ei = 0;
        while ei < len(edges) {
            if edges[ei].get("source", "") == source_id and self.edge_role(edges[ei]) == target_role {
                result.append(edges[ei].get("target", ""));
            }
            ei = ei + 1;
        }
        return result;
    }

    def source_ids_for_edge_type(edges: list, target_id: str, edge_type: str) -> list {
        result: list = [];
        ei = 0;
        while ei < len(edges) {
            if edges[ei].get("target", "") == target_id and edges[ei].get("type", "") == edge_type {
                result.append(edges[ei].get("source", ""));
            }
            ei = ei + 1;
        }
        return result;
    }

    def source_ids_for_edge_role(edges: list, target_id: str, edge_role: str) -> list {
        result: list = [];
        target_role = edge_role.upper().strip();
        ei = 0;
        while ei < len(edges) {
            if edges[ei].get("target", "") == target_id and self.edge_role(edges[ei]) == target_role {
                result.append(edges[ei].get("source", ""));
            }
            ei = ei + 1;
        }
        return result;
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

        ev_cat = str(node_data.get("evidence_category", "")).lower().strip();
        ev_kind = str(node_data.get("evidence_kind", "")).lower().strip();
        content = str(node_data.get("content", "")).strip();
        source_url = str(node_data.get("sourceUrl", "")).strip();
        source_spans = node_data.get("source_span_ids", []);
        speaker_ids = node_data.get("speaker_ids", []);
        conf = self.clamp01(self.to_float(node_data.get("confidence", 0.5), 0.5));

        source_quality = 0.35;
        if source_url {
            source_quality = 1.0;
        } elif isinstance(source_spans, list) and len(source_spans) > 0 {
            source_quality = 0.8;
        } elif ev_kind in ["metric", "fact", "precedent"] or ev_cat in ["empirical_data", "expert_testimony"] {
            source_quality = 0.75;
        } elif isinstance(speaker_ids, list) and len(speaker_ids) > 0 {
            source_quality = 0.6;
        } elif ev_kind == "stakeholder_observation" or ev_cat == "anecdotal" {
            source_quality = 0.45;
        }

        content_l = content.lower();
        specificity = 0.2;
        if self.has_numeric_signal(content) { specificity = specificity + 0.35; }
        if self.text_has_any(content_l, ["%", "increase", "decrease", "timeline", "quarter", "month", "week", "year", "deadline", "pilot", "study", "report", "review", "survey", "data"]) {
            specificity = specificity + 0.25;
        }
        if self.text_has_any(content_l, ["because", "compared", "versus", "vs", "already", "completed", "cost", "legal", "compliance", "customer"]) {
            specificity = specificity + 0.20;
        }
        specificity = self.clamp01(specificity);

        traceability = 0.0;
        if source_url {
            traceability = 1.0;
        } elif isinstance(source_spans, list) and len(source_spans) > 0 {
            traceability = 0.8;
        } elif isinstance(speaker_ids, list) and len(speaker_ids) > 0 {
            traceability = 0.5;
        }

        assumptions = node_data.get("assumptions", []);
        assumption_count = len(assumptions) if isinstance(assumptions, list) else 0;
        assumption_penalty = min(0.18, assumption_count * 0.04);

        quality = (
            0.40 * source_quality +
            0.25 * specificity +
            0.20 * traceability +
            0.15 * conf
        ) - assumption_penalty;
        return self.clamp01(quality);
    }

    def has_numeric_signal(text: str) -> bool {
        if not text { return False; }
        ti = 0;
        while ti < len(text) {
            ch = text[ti];
            if ch >= "0" and ch <= "9" {
                return True;
            }
            ti = ti + 1;
        }
        return False;
    }

    def text_has_any(text: str, keywords: list) -> bool {
        if not text or not keywords { return False; }
        li = str(text).lower();
        ki = 0;
        while ki < len(keywords) {
            if str(keywords[ki]).lower() in li {
                return True;
            }
            ki = ki + 1;
        }
        return False;
    }

    def normalized_text_signature(text: str) -> str {
        sig = str(text).lower();
        sig = sig.replace(",", " ").replace(".", " ").replace(";", " ").replace(":", " ");
        sig = sig.replace("(", " ").replace(")", " ").replace("/", " ").replace("-", " ");
        sig = sig.replace("?", " ").replace("!", " ").replace("\"", " ").replace("'", " ");
        return " ".join([tok for tok in sig.split(" ") if tok.strip()]);
    }

    def token_list(text: str) -> list {
        raw = self.normalized_text_signature(text).split(" ");
        tokens: list = [];
        ti = 0;
        while ti < len(raw) {
            tok = raw[ti].strip();
            if tok and tok not in ["the", "and", "for", "with", "this", "that", "from", "into", "have", "will", "been", "only", "than", "then", "they", "their", "our", "your", "about", "because"] {
                tokens.append(tok);
            }
            ti = ti + 1;
        }
        return tokens;
    }

    def token_overlap_ratio(text_a: str, text_b: str) -> float {
        toks_a = self.token_list(text_a);
        toks_b = self.token_list(text_b);
        if len(toks_a) == 0 or len(toks_b) == 0 { return 0.0; }

        matched: list = [];
        overlap = 0;
        ai = 0;
        while ai < len(toks_a) {
            tok = toks_a[ai];
            if tok in toks_b and tok not in matched {
                matched.append(tok);
                overlap = overlap + 1;
            }
            ai = ai + 1;
        }
        denom = len(toks_a);
        if len(toks_b) < denom { denom = len(toks_b); }
        return self.clamp01(overlap / max(1, denom));
    }

    def node_specificity_score(node_data: dict) -> float {
        if not node_data { return 0.0; }
        text = str(node_data.get("content", node_data.get("text", ""))).strip();
        if not text { return 0.0; }

        score = 0.35;
        word_count = len(self.token_list(text));
        if word_count >= 5 { score = score + 0.20; }
        if word_count >= 9 { score = score + 0.10; }
        if self.has_numeric_signal(text) { score = score + 0.15; }
        if self.text_has_any(text.lower(), ["because", "whether", "should", "launch", "pilot", "reduce", "increase", "compare", "legal", "compliance", "customer", "cost", "timeline"]) {
            score = score + 0.12;
        }
        if self.text_has_any(text.lower(), ["something", "stuff", "things", "better", "good", "bad", "issue", "problem"]) {
            score = score - 0.12;
        }
        return self.clamp01(score);
    }

    def edge_validity_score(nodes: list, edges: list, is_business_mode: bool = False) -> float {
        if len(edges) == 0 { return 1.0; }
        valid = 0;
        ei = 0;
        while ei < len(edges) {
            edge_item = edges[ei];
            src = self.get_node(nodes, edge_item.get("source", ""));
            tgt = self.get_node(nodes, edge_item.get("target", ""));
            if not src or not tgt {
                ei = ei + 1;
                continue;
            }
            er = self.edge_role(edge_item);
            src_role = self.semantic_role(src);
            tgt_role = self.semantic_role(tgt);
            src_type = str(src.get("type", "")).upper();
            tgt_type = str(tgt.get("type", "")).upper();

            if is_business_mode {
                if er == "HAS_OPTION" and src_role == "DECISION" and tgt_role == "OPTION" { valid = valid + 1; }
                elif er == "SUPPORTS" and src_role == "EVIDENCE" and (tgt_role == "OPTION" or tgt_role == "DECISION") { valid = valid + 1; }
                elif er == "OPPOSES" and src_role == "RISK" and (tgt_role == "OPTION" or tgt_role == "DECISION") { valid = valid + 1; }
                elif er == "DEPENDS_ON" and src_role == "ASSUMPTION" and (tgt_role == "OPTION" or tgt_role == "DECISION") { valid = valid + 1; }
                elif er == "BLOCKS" and src_role == "OPEN_QUESTION" and (tgt_role == "OPTION" or tgt_role == "DECISION") { valid = valid + 1; }
                elif er == "RESOLVES" and src_role == "ACTION" and tgt_role == "OPEN_QUESTION" { valid = valid + 1; }
                elif er == "IMPLEMENTS" and src_role == "ACTION" and tgt_role == "DECISION" { valid = valid + 1; }
            } else {
                if er == "SUPPORTS" and (src_type == "EVIDENCE" or src_type == "CLAIM") and (tgt_type == "CLAIM" or tgt_type == "THESIS") {
                    valid = valid + 1;
                } elif er == "OPPOSES" and src_type == "COUNTERARGUMENT" and (tgt_type == "CLAIM" or tgt_type == "THESIS") {
                    valid = valid + 1;
                } elif er == "RESOLVES" and (src_type == "CLAIM" or src_type == "EVIDENCE") and tgt_type == "COUNTERARGUMENT" {
                    valid = valid + 1;
                }
            }
            ei = ei + 1;
        }
        return self.clamp01(valid / max(1, len(edges)));
    }
    
    """Find all weak node IDs via evidence quality + upward propagation."""
    def find_weak_nodes(nodes: list, edges: list) -> list {
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
            if (e.get("type", "") == "SUPPORTS" or self.edge_role(e) == "SUPPORTS") and e.get("target", "") == claim_id {
                src_id = e.get("source", "");
                src_node = self.get_node(nodes, src_id);
                if src_node and src_node.get("type", "") == "EVIDENCE" {
                    return True;
                }
            }
        }
        return False;
    }

    def claim_support_score_internal(nodes: list, edges: list, claim_id: str, visited: list) -> float {
        if claim_id in visited {
            return 0.0;
        }
        next_visited = list(visited);
        next_visited.append(claim_id);

        total_support = 0.0;
        evidence_count = 0;
        claim_supporter_scores: list[float] = [];
        for e in edges {
            if self.edge_role(e) == "SUPPORTS" and e.get("target", "") == claim_id {
                src_node = self.get_node(nodes, e.get("source", ""));
                if src_node and src_node.get("type", "") == "EVIDENCE" {
                    evidence_count = evidence_count + 1;
                    total_support = total_support + self.edge_weight(e) * self.evidence_quality(src_node);
                } elif src_node and src_node.get("type", "") in ["CLAIM", "THESIS"] {
                    claim_supporter_scores.append(
                        self.claim_support_score_internal(nodes, edges, src_node.get("id", ""), next_visited)
                    );
                }
            }
        }
        if evidence_count > 0 {
            avg_quality = self.clamp01(total_support / max(1, evidence_count));
            return self.clamp01(0.55 + 0.45 * avg_quality);
        }
        if len(claim_supporter_scores) > 0 {
            supporter_sum = 0.0;
            si = 0;
            while si < len(claim_supporter_scores) {
                supporter_sum = supporter_sum + claim_supporter_scores[si];
                si = si + 1;
            }
            avg_supporter = self.clamp01(supporter_sum / max(1, len(claim_supporter_scores)));
            base_credit = 0.28 + 0.52 * avg_supporter;
            if self.has_assumption(nodes, edges, claim_id) {
                base_credit = base_credit + 0.08;
            }
            return self.clamp01(base_credit);
        }
        return 0.0;
    }

    def claim_support_score(nodes: list, edges: list, claim_id: str) -> float {
        return self.claim_support_score_internal(nodes, edges, claim_id, []);
    }

    """Check if a claim has assumptions — looks at supporting evidence nodes' assumptions lists."""
    def has_assumption(nodes: list, edges: list, claim_id: str) -> bool {
        for e in edges {
            if (e.get("type", "") == "SUPPORTS" or self.edge_role(e) == "DEPENDS_ON") and e.get("target", "") == claim_id {
                src_node = self.get_node(nodes, e.get("source", ""));
                if src_node and (src_node.get("type", "") == "EVIDENCE" or self.semantic_role(src_node) == "ASSUMPTION") {
                    assumptions = src_node.get("assumptions", []);
                    if isinstance(assumptions, list) and len(assumptions) > 0 {
                        return True;
                    }
                    if self.semantic_role(src_node) == "ASSUMPTION" {
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
                et = self.edge_role(e);
                if et not in ["SUPPORTS", "RESOLVES", "OPPOSES"] {
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
            if self.edge_role(e) == "RESOLVES" {
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

    def calculate_business_score(nodes: list, edges: list) -> dict {
        decisions = self.nodes_with_role(nodes, "DECISION");
        options = self.nodes_with_role(nodes, "OPTION");
        evidence_nodes = self.nodes_with_role(nodes, "EVIDENCE");
        risks = self.nodes_with_role(nodes, "RISK");
        assumptions = self.nodes_with_role(nodes, "ASSUMPTION");
        questions = self.nodes_with_role(nodes, "OPEN_QUESTION");
        actions = self.nodes_with_role(nodes, "ACTION");
        clear_decision = len(decisions) == 1;
        discussion_only = not clear_decision;
        decision_node = decisions[0] if clear_decision else None;
        decision_id = decision_node.get("id", "") if decision_node else "";

        decision_present = 1.0 if clear_decision else (0.4 if len(decisions) > 1 else 0.0);
        decision_status = str(decision_node.get("decision_status", decision_node.get("status", ""))).strip().lower() if decision_node else "";
        status_present = 1.0 if decision_status else 0.0;
        decision_specificity = self.node_specificity_score(decision_node) if decision_node else 0.0;
        decision_framing = self.clamp01(0.50 * decision_present + 0.20 * status_present + 0.30 * decision_specificity);

        option_count = len(options);
        option_count_score = 0.0;
        if option_count == 1 {
            option_count_score = 0.40;
        } elif option_count == 2 {
            option_count_score = 0.80;
        } elif option_count >= 3 and option_count <= 4 {
            option_count_score = 1.0;
        } elif option_count > 4 {
            option_count_score = 0.90;
        }

        duplicate_pairs = 0;
        pair_count = 0;
        oi = 0;
        while oi < len(options) {
            oj = oi + 1;
            while oj < len(options) {
                pair_count = pair_count + 1;
                left_text = options[oi].get("content", "");
                right_text = options[oj].get("content", "");
                overlap = self.token_overlap_ratio(left_text, right_text);
                left_sig = self.normalized_text_signature(left_text);
                right_sig = self.normalized_text_signature(right_text);
                if overlap >= 0.75 or (left_sig and right_sig and (left_sig in right_sig or right_sig in left_sig) and overlap >= 0.55) {
                    duplicate_pairs = duplicate_pairs + 1;
                }
                oj = oj + 1;
            }
            oi = oi + 1;
        }
        duplicate_option_rate = duplicate_pairs / max(1, pair_count) if pair_count > 0 else 0.0;

        comparison_supported = 0;
        supported_option_count = 0;
        evidence_quality_sum = 0.0;
        evidence_link_count = 0;
        selected_or_leading_ids: list = [];
        oi = 0;
        while oi < len(options) {
            option_status = str(options[oi].get("option_status", "")).strip().lower();
            option_id = options[oi].get("id", "");
            if option_status in ["selected", "leading"] {
                selected_or_leading_ids.append(option_id);
            }

            supporters = self.source_ids_for_edge_role(edges, option_id, "SUPPORTS");
            opposers = self.source_ids_for_edge_role(edges, option_id, "OPPOSES");
            has_option_evidence = False;
            si = 0;
            while si < len(supporters) {
                support_node = self.get_node(nodes, supporters[si]);
                if support_node and self.semantic_role(support_node) == "EVIDENCE" {
                    evidence_quality_sum = evidence_quality_sum + self.evidence_quality(support_node);
                    evidence_link_count = evidence_link_count + 1;
                    has_option_evidence = True;
                }
                si = si + 1;
            }
            if has_option_evidence {
                supported_option_count = supported_option_count + 1;
            }
            if has_option_evidence or len(opposers) > 0 {
                comparison_supported = comparison_supported + 1;
            }
            oi = oi + 1;
        }
        if len(selected_or_leading_ids) == 0 and option_count > 0 {
            selected_or_leading_ids = [options[0].get("id", "")];
        }
        comparison_coverage = comparison_supported / max(1, option_count) if option_count > 0 else 0.0;
        option_set_quality = self.clamp01(0.40 * option_count_score + 0.30 * (1.0 - duplicate_option_rate) + 0.30 * comparison_coverage);

        decision_support_coverage = 0.0;
        if len(selected_or_leading_ids) > 0 {
            leading_supported = 0;
            li = 0;
            while li < len(selected_or_leading_ids) {
                if self.has_evidence_support(nodes, edges, selected_or_leading_ids[li]) {
                    leading_supported = leading_supported + 1;
                }
                li = li + 1;
            }
            decision_support_coverage = leading_supported / max(1, len(selected_or_leading_ids));
        } elif option_count > 0 {
            decision_support_coverage = supported_option_count / max(1, option_count);
        } elif decision_id and self.has_evidence_support(nodes, edges, decision_id) {
            decision_support_coverage = 1.0;
        }

        option_evidence_coverage = supported_option_count / max(1, option_count) if option_count > 0 else decision_support_coverage;
        avg_evidence_quality = evidence_quality_sum / max(1, evidence_link_count) if evidence_link_count > 0 else (
            self.evidence_quality(evidence_nodes[0]) if len(evidence_nodes) > 0 else 0.0
        );
        evidence_strength = self.clamp01(
            0.30 * decision_support_coverage +
            0.50 * avg_evidence_quality +
            0.20 * option_evidence_coverage
        );

        mitigated_risks = 0;
        risks_on_options = 0;
        ri = 0;
        while ri < len(risks) {
            risk_id = risks[ri].get("id", "");
            risk_targets = self.target_ids_for_edge_role(edges, risk_id, "OPPOSES");
            if len(risk_targets) > 0 { risks_on_options = risks_on_options + 1; }
            if len(self.source_ids_for_edge_role(edges, risk_id, "RESOLVES")) > 0 {
                mitigated_risks = mitigated_risks + 1;
            }
            ri = ri + 1;
        }
        risk_presence_score = 0.5 if (len(risks) == 0 and option_count > 0) else (1.0 if len(risks) > 0 else 0.0);
        option_risk_coverage = risks_on_options / max(1, option_count) if option_count > 0 else (1.0 if len(risks) > 0 else 0.0);
        mitigation_rate = mitigated_risks / max(1, len(risks)) if len(risks) > 0 else 1.0;
        risk_objection_handling = self.clamp01(0.30 * risk_presence_score + 0.30 * option_risk_coverage + 0.40 * mitigation_rate);

        assumption_visibility = 1.0;
        if len(assumptions) > 0 {
            assumption_score_sum = 0.0;
            ai = 0;
            while ai < len(assumptions) {
                a_status = str(assumptions[ai].get("assumption_status", "")).strip().lower();
                if a_status == "validated" {
                    assumption_score_sum = assumption_score_sum + 1.0;
                } elif a_status == "explicit" {
                    assumption_score_sum = assumption_score_sum + 0.75;
                } elif a_status == "implicit" or a_status == "unverified" {
                    assumption_score_sum = assumption_score_sum + 0.35;
                } elif a_status == "invalidated" {
                    assumption_score_sum = assumption_score_sum + 0.0;
                } else {
                    assumption_score_sum = assumption_score_sum + 0.55;
                }
                ai = ai + 1;
            }
            assumption_visibility = self.clamp01(assumption_score_sum / max(1, len(assumptions)));
        }

        question_handling_rate = 1.0;
        if len(questions) > 0 {
            question_score_sum = 0.0;
            qi = 0;
            while qi < len(questions) {
                qid = questions[qi].get("id", "");
                q_status = str(questions[qi].get("question_status", "")).strip().lower();
                resolved = len(self.source_ids_for_edge_role(edges, qid, "RESOLVES")) > 0;
                if resolved or q_status == "answered" {
                    question_score_sum = question_score_sum + 1.0;
                } elif q_status == "parked" {
                    question_score_sum = question_score_sum + 0.45;
                } else {
                    question_score_sum = question_score_sum + 0.0;
                }
                qi = qi + 1;
            }
            question_handling_rate = self.clamp01(question_score_sum / max(1, len(questions)));
        }
        assumption_question_handling = self.clamp01(0.35 * assumption_visibility + 0.65 * question_handling_rate);

        unresolved_items = 0;
        ri = 0;
        while ri < len(risks) {
            if len(self.source_ids_for_edge_role(edges, risks[ri].get("id", ""), "RESOLVES")) == 0 {
                unresolved_items = unresolved_items + 1;
            }
            ri = ri + 1;
        }
        qi = 0;
        while qi < len(questions) {
            if len(self.source_ids_for_edge_role(edges, questions[qi].get("id", ""), "RESOLVES")) == 0 {
                unresolved_items = unresolved_items + 1;
            }
            qi = qi + 1;
        }

        action_presence = 1.0 if len(actions) > 0 else 0.0;
        owner_rate = 0.0;
        due_date_rate = 0.0;
        task_status_rate = 0.0;
        if len(actions) > 0 {
            owned = 0;
            dated = 0;
            statused = 0;
            ai = 0;
            while ai < len(actions) {
                owner_count = len(actions[ai].get("owners", [])) if isinstance(actions[ai].get("owners", []), list) else 0;
                if owner_count == 0 and str(actions[ai].get("owner", "")).strip() {
                    owner_count = 1;
                }
                if owner_count > 0 { owned = owned + 1; }
                if str(actions[ai].get("due_date", actions[ai].get("dueDate", ""))).strip() { dated = dated + 1; }
                action_status = str(actions[ai].get("action_status", actions[ai].get("task_status", actions[ai].get("taskStatus", "")))).strip();
                if action_status { statused = statused + 1; }
                ai = ai + 1;
            }
            owner_rate = owned / max(1, len(actions));
            due_date_rate = dated / max(1, len(actions));
            task_status_rate = statused / max(1, len(actions));
        }
        actionability_ownership = 1.0 if (unresolved_items == 0 and len(actions) == 0) else self.clamp01(
            0.20 * action_presence +
            0.40 * owner_rate +
            0.30 * due_date_rate +
            0.10 * task_status_rate
        );

        orphan_nodes = 0;
        ni = 0;
        while ni < len(nodes) {
            if self.node_degree(edges, nodes[ni].get("id", "")) == 0 {
                orphan_nodes = orphan_nodes + 1;
            }
            ni = ni + 1;
        }
        orphan_ratio = orphan_nodes / max(1, len(nodes));

        trace_points = 0.0;
        trace_items = 0;
        ei = 0;
        while ei < len(evidence_nodes) {
            evidence_item = evidence_nodes[ei];
            trace_items = trace_items + 1;
            if str(evidence_item.get("sourceUrl", "")).strip() {
                trace_points = trace_points + 1.0;
            } elif isinstance(evidence_item.get("source_span_ids", []), list) and len(evidence_item.get("source_span_ids", [])) > 0 {
                trace_points = trace_points + 0.8;
            } elif isinstance(evidence_item.get("speaker_ids", []), list) and len(evidence_item.get("speaker_ids", [])) > 0 {
                trace_points = trace_points + 0.5;
            }
            ei = ei + 1;
        }
        ai = 0;
        while ai < len(actions) {
            trace_items = trace_items + 1;
            action_trace = 0.0;
            owner_count = len(actions[ai].get("owners", [])) if isinstance(actions[ai].get("owners", []), list) else 0;
            if owner_count == 0 and str(actions[ai].get("owner", "")).strip() {
                owner_count = 1;
            }
            if owner_count > 0 { action_trace = action_trace + 0.5; }
            if str(actions[ai].get("due_date", actions[ai].get("dueDate", ""))).strip() { action_trace = action_trace + 0.5; }
            trace_points = trace_points + action_trace;
            ai = ai + 1;
        }
        traceability_score = trace_points / max(1, trace_items) if trace_items > 0 else 0.65;
        edge_validity = self.edge_validity_score(nodes, edges, True);
        traceability_hygiene = self.clamp01(0.35 * traceability_score + 0.35 * (1.0 - orphan_ratio) + 0.30 * edge_validity);

        raw_overall = int(100 * (
            0.15 * decision_framing +
            0.15 * option_set_quality +
            0.20 * evidence_strength +
            0.15 * risk_objection_handling +
            0.10 * assumption_question_handling +
            0.15 * actionability_ownership +
            0.10 * traceability_hygiene
        ));

        critical_blockers = 0;
        major_blockers = 0;
        moderate_blockers = 0;

        if clear_decision and len(selected_or_leading_ids) > 0 {
            supported_leading = 0;
            li = 0;
            while li < len(selected_or_leading_ids) {
                if self.has_evidence_support(nodes, edges, selected_or_leading_ids[li]) {
                    supported_leading = supported_leading + 1;
                }
                li = li + 1;
            }
            if supported_leading == 0 {
                critical_blockers = critical_blockers + 1;
            }
        }

        ri = 0;
        while ri < len(risks) {
            risk_node = risks[ri];
            risk_id = risk_node.get("id", "");
            risk_severity = str(risk_node.get("severity", "")).strip().lower();
            risk_blocker = bool(risk_node.get("is_blocker", False));
            if len(self.source_ids_for_edge_role(edges, risk_id, "RESOLVES")) == 0 and (risk_severity == "high" or risk_blocker) {
                critical_blockers = critical_blockers + 1;
            }
            ri = ri + 1;
        }

        qi = 0;
        while qi < len(questions) {
            question_node = questions[qi];
            question_id = question_node.get("id", "");
            if bool(question_node.get("is_blocker", False)) and len(self.source_ids_for_edge_role(edges, question_id, "RESOLVES")) == 0 {
                critical_blockers = critical_blockers + 1;
            }
            qi = qi + 1;
        }

        ai = 0;
        while ai < len(actions) {
            action_node = actions[ai];
            action_id = action_node.get("id", "");
            owner_count = len(action_node.get("owners", [])) if isinstance(action_node.get("owners", []), list) else 0;
            if owner_count == 0 and str(action_node.get("owner", "")).strip() {
                owner_count = 1;
            }
            has_due = bool(str(action_node.get("due_date", action_node.get("dueDate", ""))).strip());
            resolves_any = len(self.target_ids_for_edge_role(edges, action_id, "RESOLVES")) > 0;
            implements_any = len(self.target_ids_for_edge_role(edges, action_id, "IMPLEMENTS")) > 0;
            if (resolves_any or (implements_any and decision_status in ["tentative", "final"])) and (owner_count == 0 or not has_due) {
                critical_blockers = critical_blockers + 1;
            }
            ai = ai + 1;
        }

        if option_count <= 1 {
            major_blockers = major_blockers + 1;
        }
        unsupported_ratio = 1.0 - option_evidence_coverage if option_count > 0 else 1.0;
        if unsupported_ratio > 0.50 {
            major_blockers = major_blockers + 1;
        }
        if evidence_link_count == 0 {
            major_blockers = major_blockers + 1;
        }
        if len(actions) > 0 and owner_rate < 0.50 {
            major_blockers = major_blockers + 1;
        }
        if orphan_ratio > 0.35 {
            major_blockers = major_blockers + 1;
        }

        if len(actions) > 0 and due_date_rate < 0.50 {
            moderate_blockers = moderate_blockers + 1;
        }
        if duplicate_option_rate > 0.30 {
            moderate_blockers = moderate_blockers + 1;
        }
        if len(assumptions) > 0 {
            unresolved_assumptions = 0;
            ai = 0;
            while ai < len(assumptions) {
                assumption_status = str(assumptions[ai].get("assumption_status", "")).strip().lower();
                if assumption_status not in ["validated", "explicit"] {
                    unresolved_assumptions = unresolved_assumptions + 1;
                }
                ai = ai + 1;
            }
            if unresolved_assumptions > 0 {
                moderate_blockers = moderate_blockers + 1;
            }
        }

        blocker_cap = 100;
        if critical_blockers > 0 {
            blocker_cap = 59;
        } elif major_blockers > 0 {
            blocker_cap = 69;
        } elif moderate_blockers > 0 {
            blocker_cap = 79;
        }

        overall = raw_overall;
        if discussion_only {
            overall = 0;
        } elif overall > blocker_cap {
            overall = blocker_cap;
        }

        readiness_status = "NOT_READY";
        if discussion_only {
            readiness_status = "DISCUSSION_ONLY";
        } elif overall >= 85 and critical_blockers == 0 and major_blockers == 0 {
            readiness_status = "READY";
        } elif overall >= 70 and critical_blockers == 0 {
            readiness_status = "NEEDS_FOLLOW_UP";
        }

        return {
            "overall": overall,
            "decisionClarity": int(decision_framing * 100),
            "decisionFraming": int(decision_framing * 100),
            "optionCoverage": int(option_set_quality * 100),
            "optionSetQuality": int(option_set_quality * 100),
            "evidenceStrength": int(evidence_strength * 100),
            "riskCoverage": int(risk_objection_handling * 100),
            "riskObjectionHandling": int(risk_objection_handling * 100),
            "openQuestionHandling": int(assumption_question_handling * 100),
            "assumptionQuestionHandling": int(assumption_question_handling * 100),
            "actionability": int(actionability_ownership * 100),
            "actionabilityOwnership": int(actionability_ownership * 100),
            "traceabilityHygiene": int(traceability_hygiene * 100),
            "readinessStatus": readiness_status,
            "discussionOnly": discussion_only,
            "blockerCap": blocker_cap,
            "criticalBlockers": critical_blockers,
            "majorBlockers": major_blockers,
            "moderateBlockers": moderate_blockers,
            "decisionCount": len(decisions),
            "optionCount": len(options),
            "riskCount": len(risks),
            "openQuestionCount": len(questions),
            "nextActionCount": len(actions),
            "hasMajorBlocker": critical_blockers > 0 or major_blockers > 0,
            "orphanNodes": orphan_nodes
        };
    }

    def identify_business_issues(nodes: list, edges: list, score: dict) -> list {
        issues: list[dict] = [];
        issue_index = 1;
        decisions = self.nodes_with_role(nodes, "DECISION");
        options = self.nodes_with_role(nodes, "OPTION");
        risks = self.nodes_with_role(nodes, "RISK");
        assumptions = self.nodes_with_role(nodes, "ASSUMPTION");
        questions = self.nodes_with_role(nodes, "OPEN_QUESTION");
        actions = self.nodes_with_role(nodes, "ACTION");

        decision_id = decisions[0].get("id", "") if len(decisions) > 0 else "";
        if len(decisions) != 1 {
            issues.append({
                "id": f"issue_{issue_index}",
                "nodeId": decision_id,
                "severity": "critical",
                "type": "no_clear_decision",
                "description": "No single primary decision is clearly framed yet",
                "suggestedAction": "Define one primary decision before closing the meeting.",
                "area": "Decision Framing",
                "estimatedLift": 18,
                "centralityMultiplier": 1.2,
                "urgencyMultiplier": 1.2
            });
            issue_index = issue_index + 1;
        }

        if len(options) <= 1 {
            issues.append({
                "id": f"issue_{issue_index}",
                "nodeId": decision_id if decision_id else (options[0].get("id", "") if len(options) > 0 else ""),
                "severity": "major",
                "type": "only_one_option_considered",
                "description": "The board does not yet compare enough meaningful options",
                "suggestedAction": "Add at least one materially different option so the decision can be compared.",
                "area": "Option Set Quality",
                "estimatedLift": 14,
                "centralityMultiplier": 1.2
            });
            issue_index = issue_index + 1;
        }

        duplicate_pairs = 0;
        pair_count = 0;
        oi = 0;
        while oi < len(options) {
            oj = oi + 1;
            while oj < len(options) {
                pair_count = pair_count + 1;
                overlap = self.token_overlap_ratio(options[oi].get("content", ""), options[oj].get("content", ""));
                if overlap >= 0.75 {
                    duplicate_pairs = duplicate_pairs + 1;
                }
                oj = oj + 1;
            }
            oi = oi + 1;
        }
        duplicate_rate = duplicate_pairs / max(1, pair_count) if pair_count > 0 else 0.0;
        if duplicate_rate > 0.30 {
            issues.append({
                "id": f"issue_{issue_index}",
                "nodeId": options[0].get("id", "") if len(options) > 0 else decision_id,
                "severity": "moderate",
                "type": "duplicate_option",
                "description": "Some options look too similar to support a real comparison",
                "suggestedAction": "Merge duplicate options or rewrite them so each option is materially distinct.",
                "area": "Option Set Quality",
                "estimatedLift": 8
            });
            issue_index = issue_index + 1;
        }

        comparison_supported = 0;
        selected_or_leading_ids: list = [];
        oi = 0;
        while oi < len(options) {
            option_node = options[oi];
            option_id = option_node.get("id", "");
            option_status = str(option_node.get("option_status", "")).strip().lower();
            if option_status in ["selected", "leading"] {
                selected_or_leading_ids.append(option_id);
            }

            has_evidence = False;
            supporters = self.source_ids_for_edge_role(edges, option_id, "SUPPORTS");
            si = 0;
            while si < len(supporters) {
                support_node = self.get_node(nodes, supporters[si]);
                if support_node and self.semantic_role(support_node) == "EVIDENCE" and self.evidence_quality(support_node) >= 0.45 {
                    has_evidence = True;
                    break;
                }
                si = si + 1;
            }
            has_risk = len(self.source_ids_for_edge_role(edges, option_id, "OPPOSES")) > 0;
            if has_evidence or has_risk {
                comparison_supported = comparison_supported + 1;
            }

            if not has_evidence {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": option_id,
                    "severity": "critical" if option_status in ["selected", "leading"] else "major",
                    "type": "unsupported_leading_option" if option_status in ["selected", "leading"] else "weak_option_comparison",
                    "description": "This option does not have enough concrete support yet",
                    "suggestedAction": "Add evidence, metrics, or source-backed support so this option can be compared credibly.",
                    "area": "Evidence Strength",
                    "estimatedLift": 11,
                    "centralityMultiplier": 1.2 if option_status in ["selected", "leading"] else 1.0
                });
                issue_index = issue_index + 1;
            }
            oi = oi + 1;
        }
        if len(selected_or_leading_ids) == 0 and len(options) > 0 {
            selected_or_leading_ids = [options[0].get("id", "")];
        }
        if len(options) > 1 and comparison_supported / max(1, len(options)) < 0.5 {
            issues.append({
                "id": f"issue_{issue_index}",
                "nodeId": decision_id if decision_id else options[0].get("id", ""),
                "severity": "major",
                "type": "weak_option_comparison",
                "description": "Too few options have enough support or risk coverage to compare them well",
                "suggestedAction": "Add support or downside coverage so the main options can be compared side by side.",
                "area": "Option Set Quality",
                "estimatedLift": 10,
                "centralityMultiplier": 1.2
            });
            issue_index = issue_index + 1;
        }

        ri = 0;
        while ri < len(risks) {
            risk_node = risks[ri];
            risk_id = risk_node.get("id", "");
            risk_severity = str(risk_node.get("severity", "")).strip().lower();
            is_blocker = bool(risk_node.get("is_blocker", False));
            resolved = len(self.source_ids_for_edge_role(edges, risk_id, "RESOLVES")) > 0;
            if not resolved {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": risk_id,
                    "severity": "critical" if (risk_severity == "high" or is_blocker) else "major",
                    "type": "unmitigated_high_risk" if (risk_severity == "high" or is_blocker) else "unresolved_risk",
                    "description": "A risk or objection remains open without a mitigation or response",
                    "suggestedAction": "Add a mitigation plan, owner, or evidence that addresses this risk directly.",
                    "area": "Risk / Objection Handling",
                    "estimatedLift": 15,
                    "urgencyMultiplier": 1.2 if (risk_severity == "high" or is_blocker) else 1.0
                });
                issue_index = issue_index + 1;
            }
            ri = ri + 1;
        }

        qi = 0;
        while qi < len(questions) {
            question_node = questions[qi];
            question_id = question_node.get("id", "");
            resolved = len(self.source_ids_for_edge_role(edges, question_id, "RESOLVES")) > 0;
            is_blocker = bool(question_node.get("is_blocker", False));
            if not resolved {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": question_id,
                    "severity": "critical" if is_blocker else "major",
                    "type": "blocking_open_question" if is_blocker else "open_question_without_followup",
                    "description": "An open question still lacks a clear follow-up path",
                    "suggestedAction": "Create a next action, owner, or evidence plan that closes this question.",
                    "area": "Assumption / Open Question Handling",
                    "estimatedLift": 12,
                    "urgencyMultiplier": 1.2 if is_blocker else 1.0
                });
                issue_index = issue_index + 1;
            }
            qi = qi + 1;
        }

        ai = 0;
        while ai < len(assumptions) {
            assumption_node = assumptions[ai];
            assumption_id = assumption_node.get("id", "");
            assumption_status = str(assumption_node.get("assumption_status", "")).strip().lower();
            if assumption_status not in ["validated", "explicit"] {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": assumption_id,
                    "severity": "moderate",
                    "type": "unvalidated_assumption",
                    "description": "A key assumption is still implicit or unverified",
                    "suggestedAction": "Make the assumption explicit and add evidence or a follow-up plan to validate it.",
                    "area": "Assumption / Open Question Handling",
                    "estimatedLift": 8
                });
                issue_index = issue_index + 1;
            }
            ai = ai + 1;
        }

        ai = 0;
        while ai < len(actions) {
            action_node = actions[ai];
            action_id = action_node.get("id", "");
            owner_list = action_node.get("owners", []);
            has_owner = len(owner_list) > 0 if isinstance(owner_list, list) else False;
            if not has_owner and str(action_node.get("owner", "")).strip() {
                has_owner = True;
            }
            has_due = bool(str(action_node.get("due_date", action_node.get("dueDate", ""))).strip());
            resolves_any = len(self.target_ids_for_edge_role(edges, action_id, "RESOLVES")) > 0;
            implements_any = len(self.target_ids_for_edge_role(edges, action_id, "IMPLEMENTS")) > 0;
            if not has_owner {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": action_id,
                    "severity": "critical" if (resolves_any or implements_any) else "major",
                    "type": "missing_owner",
                    "description": "A next action is missing an owner",
                    "suggestedAction": "Assign one clear owner so this follow-up can actually move.",
                    "area": "Actionability / Ownership",
                    "estimatedLift": 9,
                    "urgencyMultiplier": 1.2 if (resolves_any or implements_any) else 1.0
                });
                issue_index = issue_index + 1;
            }
            if not has_due {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": action_id,
                    "severity": "critical" if resolves_any else "moderate",
                    "type": "missing_due_date",
                    "description": "A next action is missing a due date",
                    "suggestedAction": "Add a due date so the team knows when this follow-up should close.",
                    "area": "Actionability / Ownership",
                    "estimatedLift": 7,
                    "urgencyMultiplier": 1.2 if resolves_any else 1.0
                });
                issue_index = issue_index + 1;
            }
            ai = ai + 1;
        }

        if len(actions) == 0 and (len(risks) > 0 or len(questions) > 0) {
            issues.append({
                "id": f"issue_{issue_index}",
                "nodeId": decision_id,
                "severity": "critical",
                "type": "missing_next_action",
                "description": "The board still has unresolved items but no concrete next action",
                "suggestedAction": "Add at least one concrete next action with an owner and due date before closing the board.",
                "area": "Actionability / Ownership",
                "estimatedLift": 15,
                "centralityMultiplier": 1.2,
                "urgencyMultiplier": 1.2
            });
            issue_index = issue_index + 1;
        }

        ni = 0;
        while ni < len(nodes) {
            node_id = nodes[ni].get("id", "");
            if self.node_degree(edges, node_id) == 0 {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": node_id,
                    "severity": "low",
                    "type": "orphan_board_node",
                    "description": "This board item is disconnected from the main decision structure",
                    "suggestedAction": "Connect this item to the decision or remove it if it is not part of the board.",
                    "area": "Traceability / Hygiene",
                    "estimatedLift": 5
                });
                issue_index = issue_index + 1;
            }
            ni = ni + 1;
        }

        return self.sort_issues_by_priority(issues)[:14];
    }

    def build_business_next_actions(nodes: list, edges: list, issues: list) -> list {
        actions: list[dict] = [];
        used_nodes: list[str] = [];
        ai = 0;
        while ai < len(issues) and len(actions) < 5 {
            issue = issues[ai];
            node_id = issue.get("nodeId", "");
            if node_id and node_id in used_nodes {
                ai = ai + 1;
                continue;
            }
            suggestion = issue.get("suggestedAction", "");
            if issue.get("type", "") == "missing_owner" {
                suggestion = "Assign one clear owner to this action.";
            } elif issue.get("type", "") == "missing_due_date" {
                suggestion = "Set a due date for this action.";
            } elif issue.get("type", "") == "unmitigated_high_risk" {
                suggestion = "Create a mitigation plan with an owner and deadline for this risk.";
            } elif issue.get("type", "") == "blocking_open_question" {
                suggestion = "Add a follow-up action that closes this blocker question.";
            } elif issue.get("type", "") == "unsupported_leading_option" or issue.get("type", "") == "weak_option_comparison" {
                suggestion = "Add evidence that makes the main options easier to compare.";
            }
            actions.append({
                "id": f"next_{len(actions) + 1}",
                "nodeId": node_id,
                "action": suggestion,
                "issueType": issue.get("type", ""),
                "rank": len(actions) + 1,
                "severity": issue.get("severity", "moderate"),
                "area": issue.get("area", ""),
                "expectedLift": int(self.to_float(issue.get("estimatedLift", 0), 0.0))
            });
            if node_id { used_nodes.append(node_id); }
            ai = ai + 1;
        }
        return actions;
    }

    def annotate_business_nodes(nodes: list, edges: list, issues: list) -> None {
        issue_map: dict[str, list[dict]] = {};
        ii = 0;
        while ii < len(issues) {
            node_id = issues[ii].get("nodeId", "");
            if node_id {
                if node_id not in issue_map {
                    issue_map[node_id] = [];
                }
                bucket = list(issue_map[node_id]);
                bucket.append(issues[ii]);
                issue_map[node_id] = bucket;
            }
            ii = ii + 1;
        }

        ni = 0;
        while ni < len(nodes) {
            node_id = nodes[ni].get("id", "");
            role = self.semantic_role(nodes[ni]);
            node_issues = list(issue_map[node_id]) if node_id in issue_map else [];
            nodes[ni]["issues"] = node_issues;
            nodes[ni]["isWeak"] = len(node_issues) > 0;

            if role == "DECISION" or role == "OPTION" {
                support_quality = self.claim_support_score(nodes, edges, node_id);
                risk_penalty = 0;
                incoming_risks = self.source_ids_for_edge_role(edges, node_id, "OPPOSES");
                ri = 0;
                while ri < len(incoming_risks) {
                    if len(self.source_ids_for_edge_role(edges, incoming_risks[ri], "RESOLVES")) == 0 {
                        risk_penalty = risk_penalty + 18;
                    }
                    ri = ri + 1;
                }
                raw_score = int(support_quality * 100) - risk_penalty;
                if role == "DECISION" and raw_score < 35 { raw_score = 35; }
                if raw_score < 0 { raw_score = 0; }
                nodes[ni]["nodeScore"] = raw_score;
            } elif role == "EVIDENCE" {
                nodes[ni]["nodeScore"] = int(self.evidence_quality(nodes[ni]) * 100);
            } elif role == "RISK" or role == "OPEN_QUESTION" {
                addressed = len(self.source_ids_for_edge_role(edges, node_id, "RESOLVES")) > 0;
                nodes[ni]["nodeScore"] = 78 if addressed else 48;
            } elif role == "ACTION" {
                owner_bonus = 20 if ((isinstance(nodes[ni].get("owners", []), list) and len(nodes[ni].get("owners", [])) > 0) or str(nodes[ni].get("owner", "")).strip()) else 0;
                due_bonus = 20 if str(nodes[ni].get("due_date", nodes[ni].get("dueDate", ""))).strip() else 0;
                nodes[ni]["nodeScore"] = 45 + owner_bonus + due_bonus;
            } else {
                nodes[ni]["nodeScore"] = 55;
            }
            ni = ni + 1;
        }
    }

    def calculate_score(nodes: list, edges: list) -> dict {
        claims = self.get_claims(nodes);
        total_claims = len(claims);
        total_nodes = len(nodes);

        thesis_ids = self.get_thesis_ids(nodes, edges);
        contradictions = [e for e in edges if self.edge_role(e) == "OPPOSES"];
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

        unsupported_claims = 0;
        disconnected_claims = 0;
        claims_needing_premise = 0;
        weak_inference_claims = 0;
        vague_claims = 0;
        thesis_supported = len(thesis_ids) > 0;

        root_serving_claim_ids: list = [];
        ci = 0;
        while ci < len(claims) {
            cid = claims[ci].get("id", "");
            if cid in thesis_ids or self.claim_connected_to_thesis(nodes, edges, cid, thesis_ids) {
                root_serving_claim_ids.append(cid);
            } else {
                disconnected_claims = disconnected_claims + 1;
            }
            ci = ci + 1;
        }
        if len(root_serving_claim_ids) == 0 {
            root_serving_claim_ids = list(thesis_ids);
        }

        support_sum = 0.0;
        unsupported_inference_count = 0;
        rci = 0;
        while rci < len(root_serving_claim_ids) {
            cid = root_serving_claim_ids[rci];
            c_support = self.claim_support_score(nodes, edges, cid);
            support_sum = support_sum + c_support;
            if c_support < 0.10 {
                unsupported_claims = unsupported_claims + 1;
            }
            if cid in thesis_ids and c_support < 0.25 {
                thesis_supported = False;
            }

            direct_evidence = self.has_evidence_support(nodes, edges, cid);
            claim_supporters = 0;
            supporters = self.source_ids_for_edge_role(edges, cid, "SUPPORTS");
            si = 0;
            while si < len(supporters) {
                src_node = self.get_node(nodes, supporters[si]);
                if src_node and src_node.get("type", "") in ["CLAIM", "THESIS"] {
                    claim_supporters = claim_supporters + 1;
                }
                si = si + 1;
            }
            if claim_supporters > 0 and not direct_evidence and not self.has_assumption(nodes, edges, cid) and c_support < 0.55 {
                unsupported_inference_count = unsupported_inference_count + 1;
                claims_needing_premise = claims_needing_premise + 1;
            }
            rci = rci + 1;
        }
        root_support_coverage = self.clamp01(support_sum / max(1, len(root_serving_claim_ids)));

        root_evidence_quality_sum = 0.0;
        root_evidence_count = 0;
        evidence_categories: list = [];
        ni = 0;
        while ni < len(nodes) {
            node_item = nodes[ni];
            if node_item.get("type", "") == "EVIDENCE" {
                node_id = node_item.get("id", "");
                targets = self.target_ids_for_edge_role(edges, node_id, "SUPPORTS");
                is_root_evidence = False;
                ti = 0;
                while ti < len(targets) {
                    if targets[ti] in root_serving_claim_ids {
                        is_root_evidence = True;
                        break;
                    }
                    ti = ti + 1;
                }
                if is_root_evidence {
                    root_evidence_quality_sum = root_evidence_quality_sum + self.evidence_quality(node_item);
                    root_evidence_count = root_evidence_count + 1;
                    ev_cat = str(node_item.get("evidence_category", "")).strip().lower();
                    if ev_cat and ev_cat not in evidence_categories {
                        evidence_categories.append(ev_cat);
                    }
                }
            }
            ni = ni + 1;
        }
        avg_evidence_quality = root_evidence_quality_sum / max(1, root_evidence_count) if root_evidence_count > 0 else 0.0;
        evidence_diversity = self.clamp01(len(evidence_categories) / 3.0);
        evidence_quality = self.clamp01(0.85 * avg_evidence_quality + 0.15 * evidence_diversity);

        counter_presence = 1.0 if total_contradictions > 0 else 0.35;
        counter_resolution = 0.5;
        if total_contradictions > 0 {
            counter_resolution = self.clamp01(1.0 - (unresolved_contradictions / max(1, total_contradictions)));
        }
        dialectical_handling = self.clamp01(0.35 * counter_presence + 0.65 * counter_resolution);

        orphan_nodes = 0;
        ni = 0;
        while ni < len(nodes) {
            if self.node_degree(edges, nodes[ni].get("id", "")) == 0 {
                orphan_nodes = orphan_nodes + 1;
            }
            ni = ni + 1;
        }
        orphan_ratio = orphan_nodes / max(1, total_nodes);
        disconnected_ratio = disconnected_claims / max(1, total_claims) if total_claims > 0 else 0.0;

        reachable_nonroot = 0;
        visited: list = [];
        queue: list = [];
        ti = 0;
        while ti < len(thesis_ids) {
            queue.append(thesis_ids[ti]);
            visited.append(thesis_ids[ti]);
            ti = ti + 1;
        }
        qi = 0;
        while qi < len(queue) {
            cur = queue[qi];
            ei = 0;
            while ei < len(edges) {
                er = self.edge_role(edges[ei]);
                if er in ["SUPPORTS", "OPPOSES", "RESOLVES"] {
                    nxt = "";
                    if edges[ei].get("source", "") == cur {
                        nxt = edges[ei].get("target", "");
                    } elif edges[ei].get("target", "") == cur {
                        nxt = edges[ei].get("source", "");
                    }
                    if nxt and nxt not in visited {
                        visited.append(nxt);
                        queue.append(nxt);
                    }
                }
                ei = ei + 1;
            }
            qi = qi + 1;
        }
        vi = 0;
        while vi < len(visited) {
            if visited[vi] not in thesis_ids {
                reachable_nonroot = reachable_nonroot + 1;
            }
            vi = vi + 1;
        }
        root_reachability = reachable_nonroot / max(1, total_nodes - len(thesis_ids));
        edge_validity = self.edge_validity_score(nodes, edges, False);
        structural_coherence = self.clamp01(0.45 * root_reachability + 0.35 * (1.0 - orphan_ratio) + 0.20 * edge_validity);

        unsupported_inference_rate = unsupported_inference_count / max(1, len(root_serving_claim_ids));
        assumption_explicitness = self.clamp01(1.0 - unsupported_inference_rate);

        thesis_clarity = self.node_specificity_score(self.get_node(nodes, thesis_ids[0])) if len(thesis_ids) > 0 else 0.0;
        if thesis_clarity < 0.45 {
            vague_claims = vague_claims + 1;
        }

        overall = int(100 * (
            0.25 * root_support_coverage +
            0.20 * evidence_quality +
            0.20 * dialectical_handling +
            0.15 * structural_coherence +
            0.10 * assumption_explicitness +
            0.10 * thesis_clarity
        ));

        if len(thesis_ids) == 0 and overall > 30 {
            overall = 30;
        }
        if overall < 0 { overall = 0; }
        if overall > 100 { overall = 100; }

        passes_bar = (
            overall >= 80 and
            thesis_supported and
            unresolved_contradictions == 0
        );

        return {
            "overall": overall,
            "support": int(root_support_coverage * 100),
            "premise": int(assumption_explicitness * 100),
            "coherence": int(structural_coherence * 100),
            "counterargument": int(dialectical_handling * 100),
            "consistency": int(dialectical_handling * 100),
            "rootSupportCoverage": int(root_support_coverage * 100),
            "evidenceQuality": int(evidence_quality * 100),
            "dialecticalHandling": int(dialectical_handling * 100),
            "structuralCoherence": int(structural_coherence * 100),
            "assumptionExplicitness": int(assumption_explicitness * 100),
            "thesisClarity": int(thesis_clarity * 100),
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
        issues: list[dict] = [];
        issue_index = 1;
        thesis_ids = self.get_thesis_ids(nodes, edges);
        if len(thesis_ids) == 0 {
            issues.append({
                "id": f"issue_{issue_index}",
                "nodeId": "",
                "severity": "critical",
                "type": "no_thesis",
                "description": "There is no clear thesis or central claim to evaluate yet",
                "suggestedAction": "Add one clear thesis so the graph has a review target.",
                "area": "Root / Framing",
                "estimatedLift": 18,
                "centralityMultiplier": 1.2,
                "urgencyMultiplier": 1.2
            });
            issue_index = issue_index + 1;
        } else {
            thesis_node = self.get_node(nodes, thesis_ids[0]);
            thesis_clarity = self.node_specificity_score(thesis_node);
            thesis_support = self.claim_support_score(nodes, edges, thesis_ids[0]);
            if thesis_clarity < 0.55 {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": thesis_ids[0],
                    "severity": "moderate",
                    "type": "vague_thesis",
                    "description": "The thesis is too vague to evaluate cleanly",
                    "suggestedAction": "Rewrite the thesis in more concrete, reviewable terms.",
                    "area": "Root / Framing",
                    "estimatedLift": 9,
                    "centralityMultiplier": 1.2
                });
                issue_index = issue_index + 1;
            }
            if thesis_support < 0.25 {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": thesis_ids[0],
                    "severity": "major",
                    "type": "unsupported_thesis",
                    "description": "The thesis does not yet have enough visible support",
                    "suggestedAction": "Add evidence or a stronger support chain for the main thesis.",
                    "area": "Support Quality",
                    "estimatedLift": 15,
                    "centralityMultiplier": 1.2,
                    "urgencyMultiplier": 1.2
                });
                issue_index = issue_index + 1;
            }
        }

        contradictions = [e for e in edges if self.edge_role(e) == "OPPOSES"];
        if len(contradictions) == 0 {
            issues.append({
                "id": f"issue_{issue_index}",
                "nodeId": thesis_ids[0] if len(thesis_ids) > 0 else "",
                "severity": "moderate",
                "type": "missing_counterargument",
                "description": "The graph does not surface a counterargument yet",
                "suggestedAction": "Add at least one meaningful counterargument to test the thesis.",
                "area": "Dialectic / Risk",
                "estimatedLift": 8
            });
            issue_index = issue_index + 1;
        }

        ci = 0;
        while ci < len(claims) {
            claim_node = claims[ci];
            cid = claim_node.get("id", "");
            ctype = "thesis" if cid in thesis_ids else "claim";
            c_support = self.claim_support_score(nodes, edges, cid);
            is_root_serving = cid in thesis_ids or self.claim_connected_to_thesis(nodes, edges, cid, thesis_ids);

            if cid not in thesis_ids and not is_root_serving {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "moderate",
                    "type": "disconnected_claim",
                    "description": "This claim is disconnected from the main thesis path",
                    "suggestedAction": "Connect this claim to the thesis or a parent claim so it supports the argument.",
                    "area": "Structure / Coherence",
                    "estimatedLift": 7
                });
                issue_index = issue_index + 1;
            }

            if c_support < 0.10 and cid not in thesis_ids {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "major" if is_root_serving else "moderate",
                    "type": "unsupported_claim",
                    "description": f"This {ctype} does not yet have supporting evidence",
                    "suggestedAction": "Add at least one evidence node that directly supports this claim.",
                    "area": "Support Quality",
                    "estimatedLift": 11,
                    "centralityMultiplier": 1.2 if is_root_serving else 1.0
                });
                issue_index = issue_index + 1;
            } elif c_support < 0.55 {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "moderate",
                    "type": "weak_evidence",
                    "description": f"This {ctype} relies on weak or thin support",
                    "suggestedAction": "Strengthen this point with more concrete or better sourced evidence.",
                    "area": "Evidence Quality",
                    "estimatedLift": 8,
                    "centralityMultiplier": 1.2 if is_root_serving else 1.0
                });
                issue_index = issue_index + 1;
            }

            supporters = self.source_ids_for_edge_role(edges, cid, "SUPPORTS");
            has_claim_supporter = False;
            si = 0;
            while si < len(supporters) {
                src_node = self.get_node(nodes, supporters[si]);
                if src_node and src_node.get("type", "") in ["CLAIM", "THESIS"] {
                    has_claim_supporter = True;
                    break;
                }
                si = si + 1;
            }
            if has_claim_supporter and not self.has_evidence_support(nodes, edges, cid) and not self.has_assumption(nodes, edges, cid) and c_support < 0.55 {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "moderate",
                    "type": "missing_assumption",
                    "description": f"This {ctype} depends on an unstated assumption",
                    "suggestedAction": "Add an assumption node or evidence that makes the reasoning jump explicit.",
                    "area": "Uncertainty Handling",
                    "estimatedLift": 8,
                    "centralityMultiplier": 1.2 if is_root_serving else 1.0
                });
                issue_index = issue_index + 1;
            }
            ci = ci + 1;
        }

        cei = 0;
        while cei < len(contradictions) {
            if self.contradiction_unresolved(nodes, edges, contradictions[cei]) {
                issue_node_id = contradictions[cei].get("source", "");
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": issue_node_id,
                    "severity": "major",
                    "type": "unresolved_counterargument",
                    "description": "A counterargument is still unaddressed",
                    "suggestedAction": "Add a response, rebuttal, or acknowledgement that deals with this counterargument.",
                    "area": "Dialectic / Risk",
                    "estimatedLift": 12,
                    "urgencyMultiplier": 1.1
                });
                issue_index = issue_index + 1;
            }
            cei = cei + 1;
        }

        ni = 0;
        while ni < len(nodes) {
            nid = nodes[ni].get("id", "");
            ntype = nodes[ni].get("type", "");
            if self.node_degree(edges, nid) == 0 and ntype in ["CLAIM", "EVIDENCE", "COUNTERARGUMENT", "THESIS"] {
                issues.append({
                    "id": f"issue_{issue_index}",
                    "nodeId": nid,
                    "severity": "low",
                    "type": "orphan_node",
                    "description": "This node is isolated from the main argument graph",
                    "suggestedAction": "Connect this node to a relevant claim or remove it if it is not helping the argument.",
                    "area": "Structure / Coherence",
                    "estimatedLift": 5
                });
                issue_index = issue_index + 1;
            }
            ni = ni + 1;
        }

        sorted_issues = self.sort_issues_by_priority(issues);
        return sorted_issues[:14];
    }

    def severity_weight(severity: str) -> float {
        sev = severity.lower().strip();
        if sev == "critical" { return 3.0; }
        if sev == "major" { return 2.0; }
        if sev == "moderate" { return 1.0; }
        return 0.5;
    }

    def issue_dimension_weight(issue: dict) -> float {
        area = str(issue.get("area", "")).strip();
        if area == "Support Quality" { return 0.25; }
        if area == "Evidence Quality" or area == "Evidence Strength" { return 0.20; }
        if area == "Dialectic / Risk" { return 0.20; }
        if area == "Structure / Coherence" { return 0.15; }
        if area == "Uncertainty Handling" { return 0.10; }
        if area == "Root / Framing" or area == "Decision Framing" { return 0.15; }
        if area == "Option Set Quality" { return 0.15; }
        if area == "Risk / Objection Handling" { return 0.15; }
        if area == "Assumption / Open Question Handling" { return 0.10; }
        if area == "Actionability / Ownership" { return 0.15; }
        if area == "Traceability / Hygiene" { return 0.10; }
        return 0.10;
    }

    def issue_effort_estimate(issue_type: str) -> float {
        itype = issue_type.lower().strip();
        if itype in ["missing_owner", "missing_due_date", "orphan_node", "orphan_board_node"] { return 0.5; }
        if itype in ["disconnected_claim", "duplicate_option"] { return 1.0; }
        if itype in ["weak_evidence", "unsupported_claim", "unsupported_thesis", "unsupported_leading_option", "weak_option_comparison", "missing_assumption", "unvalidated_assumption"] { return 1.5; }
        return 2.0;
    }

    def issue_priority(issue: dict) -> int {
        sev_w = self.severity_weight(issue.get("severity", "low"));
        dim_w = self.issue_dimension_weight(issue);
        centrality = self.to_float(issue.get("centralityMultiplier", 1.0), 1.0);
        urgency = self.to_float(issue.get("urgencyMultiplier", 1.0), 1.0);
        effort = self.issue_effort_estimate(issue.get("type", ""));
        if effort < 0.5 { effort = 0.5; }
        return int((sev_w * dim_w * centrality * urgency / effort) * 1000);
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
        while i < len(issues) and action_count < 4 {
            issue = issues[i];
            node_id = issue.get("nodeId", "");
            if node_id and node_id in used_nodes {
                i = i + 1;
                continue;
            }
            if node_id {
                used_nodes.append(node_id);
            }
            suggestion = issue.get("suggestedAction", "");
            if issue.get("type", "") == "unsupported_thesis" {
                suggestion = "Add the strongest missing support directly under the thesis.";
            } elif issue.get("type", "") == "missing_counterargument" {
                suggestion = "Add one serious counterargument that tests the main thesis.";
            } elif issue.get("type", "") == "missing_assumption" {
                suggestion = "Surface the hidden assumption or add evidence that closes the logic gap.";
            }
            actions.append({
                "id": f"next_{action_count + 1}",
                "nodeId": node_id,
                "action": suggestion,
                "issueType": issue.get("type", ""),
                "rank": action_count + 1,
                "severity": issue.get("severity", "moderate"),
                "area": issue.get("area", ""),
                "expectedLift": int(self.to_float(issue.get("estimatedLift", 0), 0.0))
            });
            action_count = action_count + 1;
            i = i + 1;
        }

        # Fill remaining slots if uniqueness filtering left fewer than 4
        i = 0;
        while i < len(issues) and action_count < 4 {
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
                    "severity": issue.get("severity", "moderate"),
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
                    if self.edge_role(e) == "OPPOSES" and e.get("target", "") == nid {
                        counter_src_id = e.get("source", "");
                        is_addressed = False;
                        for e2 in edges {
                            if self.edge_role(e2) == "RESOLVES" and e2.get("target", "") == counter_src_id {
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
                # Find all addressing nodes and compute quality-weighted score
                address_quality_sum = 0.0;
                address_count = 0;
                for e in edges {
                    if self.edge_role(e) == "RESOLVES" and e.get("target", "") == nid {
                        addr_node = self.get_node(nodes, e.get("source", ""));
                        if addr_node {
                            addr_type = addr_node.get("type", "");
                            if addr_type == "EVIDENCE" {
                                address_count = address_count + 1;
                                address_quality_sum = address_quality_sum + self.evidence_quality(addr_node);
                            } else {
                                # Claims/other nodes addressing a counterargument get a baseline quality
                                address_count = address_count + 1;
                                address_quality_sum = address_quality_sum + 0.5;
                            }
                        }
                    }
                }
                if address_count > 0 {
                    avg_addr_quality = address_quality_sum / address_count;
                    n["nodeScore"] = int(avg_addr_quality * 100);
                } else {
                    n["nodeScore"] = 55;
                }
            }
        }
    }
}
