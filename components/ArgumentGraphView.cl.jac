"""SVG argument graph: D3-style force-directed layout, draggable nodes, pan, zoom, themed.
   Uses the exact same force model and parameters as d3-force from the mockup,
   implemented natively in Jac for full compatibility with the client compiler.
   All loops use while+index to avoid Jac compiler dict-iteration issues."""

import from .ArgumentNodeComponent { ArgumentNodeComponent }


def:pub ArgumentGraphView(props: any) -> JsxElement {
    nodes       = list(props.nodes) if props.nodes else [];
    edges       = list(props.edges) if props.edges else [];
    onNodeClick = props.onNodeClick if props.onNodeClick else None;
    onGhostAccept = props.onGhostAccept if props.onGhostAccept else None;
    savedNodePositions = props.layoutHints if props.layoutHints else {};
    onNodePositionsChange = props.onNodePositionsChange if props.onNodePositionsChange else None;
    onLayoutResolved = props.onLayoutResolved if props.onLayoutResolved else None;
    selectedNodeId = props.selectedNodeId if props.selectedNodeId else None;
    focusBranch = props.focusBranch if props.focusBranch else None;
    graphMode = props.graphMode if props.graphMode else "education_argument";

    NODE_W   = 200;
    NODE_H   = 80;

    EDGE_COLORS = {
        "SUPPORTS": "#10b981",
        "HAS_OPTION": "#3b82f6",
        "OPPOSES": "#ef4444",
        "CONTRADICTS": "#ef4444",
        "DEPENDS_ON": "#64748b",
        "BLOCKS": "#d97706",
        "RESOLVES": "#0f766e",
        "IMPLEMENTS": "#0057B7",
        "ADDRESSES": "#0057B7"
    };
    EDGE_LABELS = {
        "SUPPORTS": "SUP",
        "HAS_OPTION": "OPT",
        "OPPOSES": "RISK",
        "CONTRADICTS": "CON",
        "DEPENDS_ON": "DEP",
        "BLOCKS": "Q",
        "RESOLVES": "ACT",
        "IMPLEMENTS": "DO",
        "ADDRESSES": "ADR"
    };
    # Reasoning type labels for edge display
    REASONING_LABELS = {
        "deductive": "logic", "inductive": "infer",
        "causal": "cause", "correlational": "corr.",
        "analogical": "analog"
    };

    has nodePositions: dict    = {},
        draggingNodeId: str    = None,
        dragDidMove: bool      = False,
        dragStartClientX: float = 0.0,
        dragStartClientY: float = 0.0,
        nodeDragOffsetX: float = 0.0,
        nodeDragOffsetY: float = 0.0,
        isPanning: bool        = False,
        panStartX: float       = 0.0,
        panStartY: float       = 0.0,
        viewX: float           = 40.0,
        viewY: float           = 40.0,
        scale: float           = 1.0;

    def estimateNodeBox(nodeItem: dict) -> dict {
        node_content = nodeItem["content"] if "content" in nodeItem else "";
        max_chars = 26;
        line_count = 1;
        if len(node_content) > max_chars {
            words = node_content.split(" ");
            cur = "";
            lines: list = [];
            for w in words {
                test = (cur + " " + w).trim() if cur else w;
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
        return {"w": NODE_W * 1.0, "h": max(70.0, 32.0 + line_count * 17.0 + 12.0)};
    }

    def getNodeBox(nid: str) -> dict {
        fi = 0;
        while fi < len(nodes) {
            if nodes[fi]["id"] == nid {
                return estimateNodeBox(nodes[fi]);
            }
            fi = fi + 1;
        }
        return {"w": NODE_W * 1.0, "h": NODE_H * 1.0};
    }

    def positionsChanged(next_positions: dict, prev_positions: dict) -> bool {
        ni = 0;
        while ni < len(nodes) {
            node_id = nodes[ni]["id"];
            is_ghost = nodes[ni]["isGhost"] if "isGhost" in nodes[ni] else False;
            if is_ghost {
                ni = ni + 1;
                continue;
            }
            if node_id not in next_positions or node_id not in prev_positions {
                return True;
            }

            next_pos = next_positions[node_id] if next_positions[node_id] else {"x": 0, "y": 0};
            prev_pos = prev_positions[node_id] if prev_positions[node_id] else {"x": 0, "y": 0};
            next_x = float(next_pos["x"]) if "x" in next_pos else 0.0;
            next_y = float(next_pos["y"]) if "y" in next_pos else 0.0;
            prev_x = float(prev_pos["x"]) if "x" in prev_pos else 0.0;
            prev_y = float(prev_pos["y"]) if "y" in prev_pos else 0.0;
            if abs(next_x - prev_x) > 0.5 or abs(next_y - prev_y) > 0.5 {
                return True;
            }
            ni = ni + 1;
        }
        return False;
    }

    def clampAroundAnchor(value: float, anchor: float, limit: float) -> float {
        delta = value - anchor;
        if delta > limit { return anchor + limit; }
        if delta < 0.0 - limit { return anchor - limit; }
        return value;
    }

    def isNodeLocked(nodeId: str) -> bool {
        ni = 0;
        while ni < len(nodes) {
            if nodes[ni]["id"] == nodeId {
                return nodes[ni]["layoutLocked"] if "layoutLocked" in nodes[ni] else False;
            }
            ni = ni + 1;
        }
        return False;
    }

    def semanticRole(nodeItem: dict) -> str {
        role = str(nodeItem["role"]).upper() if "role" in nodeItem and nodeItem["role"] else "";
        if not role {
            role = str(nodeItem["semanticRole"]).upper() if "semanticRole" in nodeItem and nodeItem["semanticRole"] else "";
        }
        if role == "NEXT_ACTION" { role = "ACTION"; }
        if role { return role; }
        node_type = nodeItem["type"] if "type" in nodeItem else "";
        if node_type == "THESIS" { return "DECISION"; }
        if node_type == "EVIDENCE" { return "EVIDENCE"; }
        if node_type == "COUNTERARGUMENT" { return "RISK"; }
        return "OPTION";
    }

    def edgeRole(edgeItem: dict) -> str {
        raw_role = str(edgeItem["role"]).upper() if "role" in edgeItem and edgeItem["role"] else (str(edgeItem["type"]).upper() if "type" in edgeItem and edgeItem["type"] else "");
        if raw_role == "CONTRADICTS" { return "OPPOSES"; }
        if raw_role == "ADDRESSES" { return "RESOLVES"; }
        return raw_role;
    }

    def branchLinkedNodeId(edgeItem: dict, currentId: str) -> str {
        edge_type = edgeRole(edgeItem);
        if (edgeItem["target"] if "target" in edgeItem else "") == currentId {
            if edge_type == "SUPPORTS" or edge_type == "RESOLVES" or edge_type == "OPPOSES" or edge_type == "BLOCKS" or edge_type == "DEPENDS_ON" or edge_type == "IMPLEMENTS" {
                return edgeItem["source"] if "source" in edgeItem else "";
            }
        } elif (edgeItem["source"] if "source" in edgeItem else "") == currentId {
            if edge_type == "HAS_OPTION" {
                return edgeItem["target"] if "target" in edgeItem else "";
            }
        }
        return "";
    }

    def computeBranchIds(rootId: str) -> list {
        result: list = [];
        if not rootId { return result; }
        queue: list = [rootId];
        result.append(rootId);
        qi = 0;
        while qi < len(queue) {
            current_id = queue[qi];
            ei = 0;
            while ei < len(edges) {
                linked_id = branchLinkedNodeId(edges[ei], current_id);
                if linked_id and linked_id not in result {
                    result.append(linked_id);
                    queue.append(linked_id);
                }
                ei = ei + 1;
            }
            qi = qi + 1;
        }
        return result;
    }

    def isBranchNodeId(nodeId: str) -> bool {
        if not focusBranch { return True; }
        branch_ids = computeBranchIds(focusBranch);
        return nodeId in branch_ids;
    }

    def findNodeById(nodeId: str) -> dict {
        ni = 0;
        while ni < len(nodes) {
            if nodes[ni]["id"] == nodeId {
                return nodes[ni];
            }
            ni = ni + 1;
        }
        return {};
    }

    def firstEdgeTarget(sourceId: str, edgeType: str) -> str {
        ei = 0;
        while ei < len(edges) {
            edge_item = edges[ei];
            item_type = edgeRole(edge_item);
            if (edge_item["source"] if "source" in edge_item else "") == sourceId and item_type == edgeType {
                return edge_item["target"] if "target" in edge_item else "";
            }
            ei = ei + 1;
        }
        return "";
    }

    def spreadDenseLayerNeighbors(raw_positions: dict, id_list: list, depth_list: list) -> dict {
        result: dict = {};
        if not raw_positions { return result; }

        ri = 0;
        while ri < len(id_list) {
            node_id = id_list[ri];
            if node_id in raw_positions {
                pos = raw_positions[node_id] if raw_positions[node_id] else {"x": 0, "y": 0};
                result[node_id] = {
                    "x": float(pos["x"]) if "x" in pos else 0.0,
                    "y": float(pos["y"]) if "y" in pos else 0.0
                };
            }
            ri = ri + 1;
        }

        max_depth = 0;
        di = 0;
        while di < len(depth_list) {
            if depth_list[di] > max_depth { max_depth = depth_list[di]; }
            di = di + 1;
        }

        layer = 0;
        while layer <= max_depth {
            layer_ids: list = [];
            li = 0;
            while li < len(id_list) {
                if depth_list[li] == layer and id_list[li] in result {
                    layer_ids.append(id_list[li]);
                }
                li = li + 1;
            }

            li = 0;
            while li < len(layer_ids) {
                lj = li + 1;
                while lj < len(layer_ids) {
                    left_id = layer_ids[li];
                    right_id = layer_ids[lj];
                    left_x = result[left_id]["x"] if left_id in result else 0.0;
                    right_x = result[right_id]["x"] if right_id in result else 0.0;
                    if right_x < left_x {
                        tmp_id = layer_ids[li];
                        layer_ids[li] = layer_ids[lj];
                        layer_ids[lj] = tmp_id;
                    }
                    lj = lj + 1;
                }
                li = li + 1;
            }

            pass_idx = 0;
            while pass_idx < 3 {
                li = 1;
                while li < len(layer_ids) {
                    prev_id = layer_ids[li - 1];
                    curr_id = layer_ids[li];
                    prev_box = getNodeBox(prev_id);
                    curr_box = getNodeBox(curr_id);
                    min_gap = (prev_box["w"] + curr_box["w"]) / 2.0 + 12.0;
                    gap = result[curr_id]["x"] - result[prev_id]["x"];
                    if gap < min_gap {
                        needed = min_gap - gap;
                        prev_locked = isNodeLocked(prev_id);
                        curr_locked = isNodeLocked(curr_id);
                        prev_share = 0.22 if prev_locked else 0.55;
                        curr_share = 0.22 if curr_locked else 0.85;
                        share_total = prev_share + curr_share;
                        result[prev_id]["x"] = result[prev_id]["x"] - needed * (prev_share / share_total);
                        result[curr_id]["x"] = result[curr_id]["x"] + needed * (curr_share / share_total);
                    }
                    li = li + 1;
                }
                pass_idx = pass_idx + 1;
            }
            layer = layer + 1;
        }

        return result;
    }

    def resolveOverlapPositions(raw_positions: dict) -> dict {
        result: dict = {};
        if not raw_positions { return result; }

        ni = 0;
        while ni < len(nodes) {
            node_id = nodes[ni]["id"];
            if node_id in raw_positions {
                pos = raw_positions[node_id] if raw_positions[node_id] else {"x": 0, "y": 0};
                result[node_id] = {
                    "x": float(pos["x"]) if "x" in pos else 0.0,
                    "y": float(pos["y"]) if "y" in pos else 0.0
                };
            }
            ni = ni + 1;
        }

        pass_idx = 0;
        while pass_idx < 8 {
            any_moved = False;
            ia = 0;
            while ia < len(nodes) {
                node_a = nodes[ia];
                id_a = node_a["id"] if "id" in node_a else "";
                if (not id_a) or id_a not in result {
                    ia = ia + 1;
                    continue;
                }

                pos_a = result[id_a];
                box_a = getNodeBox(id_a);
                locked_a = node_a["layoutLocked"] if "layoutLocked" in node_a else False;
                stable_a = id_a in savedNodePositions;
                generated_a = ("position" in node_a) and (not stable_a);
                mobility_a = 0.18 if locked_a else (0.55 if stable_a else (1.25 if generated_a else 1.0));

                ib = ia + 1;
                while ib < len(nodes) {
                    node_b = nodes[ib];
                    id_b = node_b["id"] if "id" in node_b else "";
                    if (not id_b) or id_b not in result {
                        ib = ib + 1;
                        continue;
                    }

                    pos_b = result[id_b];
                    box_b = getNodeBox(id_b);
                    locked_b = node_b["layoutLocked"] if "layoutLocked" in node_b else False;
                    stable_b = id_b in savedNodePositions;
                    generated_b = ("position" in node_b) and (not stable_b);
                    mobility_b = 0.18 if locked_b else (0.55 if stable_b else (1.25 if generated_b else 1.0));

                    dx = pos_b["x"] - pos_a["x"];
                    dy = pos_b["y"] - pos_a["y"];
                    extra_gap_x = 18.0 if generated_a or generated_b else 10.0;
                    extra_gap_y = 14.0 if generated_a or generated_b else 8.0;
                    min_x_gap = (box_a["w"] + box_b["w"]) / 2.0 + extra_gap_x;
                    min_y_gap = (box_a["h"] + box_b["h"]) / 2.0 + extra_gap_y;
                    overlap_x = min_x_gap - abs(dx);
                    overlap_y = min_y_gap - abs(dy);

                    if overlap_x > 0.0 and overlap_y > 0.0 {
                        total_mobility = mobility_a + mobility_b;
                        share_a = mobility_a / total_mobility if total_mobility > 0.0 else 0.5;
                        share_b = mobility_b / total_mobility if total_mobility > 0.0 else 0.5;

                        if overlap_x <= overlap_y {
                            push_x = overlap_x + 2.0;
                            dir_x = 1.0 if dx >= 0.0 else -1.0;
                            pos_a["x"] = pos_a["x"] - dir_x * push_x * share_a;
                            pos_b["x"] = pos_b["x"] + dir_x * push_x * share_b;
                        } else {
                            push_y = overlap_y + 2.0;
                            dir_y = 1.0 if dy >= 0.0 else -1.0;
                            pos_a["y"] = pos_a["y"] - dir_y * push_y * share_a;
                            pos_b["y"] = pos_b["y"] + dir_y * push_y * share_b;
                        }

                        result[id_a] = pos_a;
                        result[id_b] = pos_b;
                        any_moved = True;
                    }
                    ib = ib + 1;
                }
                ia = ia + 1;
            }

            if not any_moved { break; }
            pass_idx = pass_idx + 1;
        }

        return result;
    }

    def applyFocusedBranchClearance(raw_positions: dict) -> dict {
        result: dict = {};
        if not raw_positions { return result; }

        ni = 0;
        while ni < len(nodes) {
            node_id = nodes[ni]["id"] if "id" in nodes[ni] else "";
            if node_id and node_id in raw_positions {
                pos = raw_positions[node_id] if raw_positions[node_id] else {"x": 0, "y": 0};
                result[node_id] = {
                    "x": float(pos["x"]) if "x" in pos else 0.0,
                    "y": float(pos["y"]) if "y" in pos else 0.0
                };
            }
            ni = ni + 1;
        }

        if not focusBranch { return result; }

        branch_ids = computeBranchIds(focusBranch);
        if len(branch_ids) == 0 { return result; }

        pass_idx = 0;
        while pass_idx < 6 {
            any_moved = False;
            ia = 0;
            while ia < len(nodes) {
                node_a = nodes[ia];
                id_a = node_a["id"] if "id" in node_a else "";
                if (not id_a) or id_a not in result or ("isGhost" in node_a and node_a["isGhost"]) {
                    ia = ia + 1;
                    continue;
                }
                in_branch_a = id_a in branch_ids;

                ib = ia + 1;
                while ib < len(nodes) {
                    node_b = nodes[ib];
                    id_b = node_b["id"] if "id" in node_b else "";
                    if (not id_b) or id_b not in result or ("isGhost" in node_b and node_b["isGhost"]) {
                        ib = ib + 1;
                        continue;
                    }
                    in_branch_b = id_b in branch_ids;
                    if in_branch_a == in_branch_b {
                        ib = ib + 1;
                        continue;
                    }

                    focus_id = id_a if in_branch_a else id_b;
                    other_id = id_b if in_branch_a else id_a;
                    focus_node = node_a if in_branch_a else node_b;
                    other_node = node_b if in_branch_a else node_a;

                    focus_pos = result[focus_id];
                    other_pos = result[other_id];
                    focus_box = getNodeBox(focus_id);
                    other_box = getNodeBox(other_id);

                    dx = other_pos["x"] - focus_pos["x"];
                    dy = other_pos["y"] - focus_pos["y"];
                    min_x_gap = (focus_box["w"] + other_box["w"]) / 2.0 + 44.0;
                    min_y_gap = (focus_box["h"] + other_box["h"]) / 2.0 + 28.0;
                    overlap_x = min_x_gap - abs(dx);
                    overlap_y = min_y_gap - abs(dy);

                    if overlap_x > 0.0 and overlap_y > 0.0 {
                        focus_locked = focus_node["layoutLocked"] if "layoutLocked" in focus_node else False;
                        other_locked = other_node["layoutLocked"] if "layoutLocked" in other_node else False;
                        focus_stable = focus_id in savedNodePositions;
                        other_stable = other_id in savedNodePositions;

                        focus_mobility = 0.14 if focus_locked else (0.32 if focus_stable else 0.55);
                        other_mobility = 0.12 if other_locked else (0.95 if other_stable else 1.25);
                        mobility_total = focus_mobility + other_mobility;
                        focus_share = focus_mobility / mobility_total if mobility_total > 0.0 else 0.25;
                        other_share = other_mobility / mobility_total if mobility_total > 0.0 else 0.75;

                        if abs(dx) >= abs(dy) or abs(dy) < 36.0 {
                            dir_x = 1.0 if dx >= 0.0 else -1.0;
                            push_x = overlap_x + 6.0;
                            focus_pos["x"] = focus_pos["x"] - dir_x * push_x * focus_share;
                            other_pos["x"] = other_pos["x"] + dir_x * push_x * other_share;
                        } else {
                            dir_y = 1.0 if dy >= 0.0 else -1.0;
                            push_y = overlap_y + 6.0;
                            focus_pos["y"] = focus_pos["y"] - dir_y * push_y * focus_share;
                            other_pos["y"] = other_pos["y"] + dir_y * push_y * other_share;
                        }

                        result[focus_id] = focus_pos;
                        result[other_id] = other_pos;
                        any_moved = True;
                    }

                    ib = ib + 1;
                }

                ia = ia + 1;
            }

            if not any_moved { break; }
            pass_idx = pass_idx + 1;
        }

        return result;
    }

    can with entry {
        n_count = len(nodes);
        if n_count == 0 { return; }

        if graphMode == "business_meeting_decision" {
            raw_positions: dict = {};
            center_x = 640.0;
            decision_y = 120.0;
            options_y = 310.0;
            evidence_y = 500.0;
            action_y = 760.0;
            question_x = 170.0;
            risk_x = 1110.0;
            option_spacing = 250.0;
            lane_spacing = 118.0;

            real_nodes: list = [];
            ghost_nodes: list = [];
            ni = 0;
            while ni < n_count {
                ghost_flag = nodes[ni]["isGhost"] if "isGhost" in nodes[ni] else False;
                if ghost_flag {
                    ghost_nodes.append(nodes[ni]);
                } else {
                    real_nodes.append(nodes[ni]);
                }
                ni = ni + 1;
            }

            decision_nodes: list = [];
            option_nodes: list = [];
            evidence_nodes: list = [];
            risk_nodes: list = [];
            question_nodes: list = [];
            assumption_nodes: list = [];
            action_nodes: list = [];
            fallback_nodes: list = [];

            ni = 0;
            while ni < len(real_nodes) {
                role = semanticRole(real_nodes[ni]);
                if role == "DECISION" {
                    decision_nodes.append(real_nodes[ni]);
                } elif role == "OPTION" {
                    option_nodes.append(real_nodes[ni]);
                } elif role == "EVIDENCE" {
                    evidence_nodes.append(real_nodes[ni]);
                } elif role == "RISK" {
                    risk_nodes.append(real_nodes[ni]);
                } elif role == "OPEN_QUESTION" {
                    question_nodes.append(real_nodes[ni]);
                } elif role == "ASSUMPTION" {
                    assumption_nodes.append(real_nodes[ni]);
                } elif role == "ACTION" {
                    action_nodes.append(real_nodes[ni]);
                } else {
                    fallback_nodes.append(real_nodes[ni]);
                }
                ni = ni + 1;
            }

            if len(decision_nodes) == 0 and len(option_nodes) > 0 {
                decision_nodes.append(option_nodes[0]);
                trimmed_options: list = [];
                toi = 1;
                while toi < len(option_nodes) {
                    trimmed_options.append(option_nodes[toi]);
                    toi = toi + 1;
                }
                option_nodes = trimmed_options;
            }

            def placeNode(nodeItem: dict, x: float, y: float) -> None {
                node_id = nodeItem["id"] if "id" in nodeItem else "";
                if not node_id { return; }
                if isNodeLocked(node_id) and node_id in savedNodePositions {
                    raw_positions[node_id] = savedNodePositions[node_id];
                    return;
                }
                raw_positions[node_id] = {"x": x, "y": y};
            }

            if len(decision_nodes) > 0 {
                placeNode(decision_nodes[0], center_x, decision_y);
            }

            option_count = len(option_nodes);
            oi = 0;
            while oi < option_count {
                option_x = center_x + (oi - (option_count - 1) / 2.0) * option_spacing;
                placeNode(option_nodes[oi], option_x, options_y);
                oi = oi + 1;
            }

            evidence_group_counts: dict = {};
            ei = 0;
            while ei < len(evidence_nodes) {
                ev_node = evidence_nodes[ei];
                ev_id = ev_node["id"] if "id" in ev_node else "";
                ev_target = firstEdgeTarget(ev_id, "SUPPORTS");
                ev_target_pos = raw_positions[ev_target] if ev_target in raw_positions else {"x": center_x, "y": options_y};
                bucket_key = ev_target if ev_target else "decision";
                bucket_index = int(evidence_group_counts[bucket_key]) if bucket_key in evidence_group_counts else 0;
                evidence_group_counts[bucket_key] = bucket_index + 1;
                ev_x = (float(ev_target_pos["x"]) if "x" in ev_target_pos else center_x) + (bucket_index - 0.5) * 210.0;
                ev_y = (float(ev_target_pos["y"]) if "y" in ev_target_pos else options_y) + 180.0;
                placeNode(ev_node, ev_x, ev_y);
                ei = ei + 1;
            }

            qi = 0;
            while qi < len(question_nodes) {
                question_id = question_nodes[qi]["id"] if "id" in question_nodes[qi] else "";
                block_target = firstEdgeTarget(question_id, "BLOCKS");
                block_target_pos = raw_positions[block_target] if block_target in raw_positions else {"x": question_x, "y": 240.0 + qi * lane_spacing};
                placeNode(question_nodes[qi], question_x, float(block_target_pos["y"]) if "y" in block_target_pos else (240.0 + qi * lane_spacing));
                qi = qi + 1;
            }

            ai = 0;
            while ai < len(assumption_nodes) {
                assumption_id = assumption_nodes[ai]["id"] if "id" in assumption_nodes[ai] else "";
                dep_target = firstEdgeTarget(assumption_id, "DEPENDS_ON");
                dep_target_pos = raw_positions[dep_target] if dep_target in raw_positions else {"x": question_x, "y": 240.0 + (len(question_nodes) + ai) * lane_spacing};
                placeNode(assumption_nodes[ai], question_x, float(dep_target_pos["y"]) if "y" in dep_target_pos else (240.0 + (len(question_nodes) + ai) * lane_spacing));
                ai = ai + 1;
            }

            risk_group_counts: dict = {};
            ri = 0;
            while ri < len(risk_nodes) {
                risk_node = risk_nodes[ri];
                risk_id = risk_node["id"] if "id" in risk_node else "";
                risk_target = firstEdgeTarget(risk_id, "OPPOSES");
                risk_target_pos = raw_positions[risk_target] if risk_target in raw_positions else {"x": center_x, "y": options_y};
                risk_key = risk_target if risk_target else "decision";
                risk_index = int(risk_group_counts[risk_key]) if risk_key in risk_group_counts else 0;
                risk_group_counts[risk_key] = risk_index + 1;
                risk_y = (float(risk_target_pos["y"]) if "y" in risk_target_pos else options_y) + (risk_index - 0.5) * lane_spacing;
                placeNode(risk_node, risk_x, risk_y);
                ri = ri + 1;
            }

            fallback_y = evidence_y + 180.0;
            fi = 0;
            while fi < len(fallback_nodes) {
                fallback_x = center_x + (fi - (len(fallback_nodes) - 1) / 2.0) * option_spacing;
                placeNode(fallback_nodes[fi], fallback_x, fallback_y);
                fi = fi + 1;
            }

            action_group_counts: dict = {};
            aci = 0;
            while aci < len(action_nodes) {
                action_node = action_nodes[aci];
                action_id = action_node["id"] if "id" in action_node else "";
                action_target = firstEdgeTarget(action_id, "RESOLVES");
                if not action_target {
                    action_target = firstEdgeTarget(action_id, "IMPLEMENTS");
                }
                action_target_pos = raw_positions[action_target] if action_target in raw_positions else {"x": center_x, "y": evidence_y};
                action_key = action_target if action_target else "decision";
                action_index = int(action_group_counts[action_key]) if action_key in action_group_counts else 0;
                action_group_counts[action_key] = action_index + 1;
                action_x = float(action_target_pos["x"]) if "x" in action_target_pos else center_x;
                action_y_local = max(action_y, (float(action_target_pos["y"]) if "y" in action_target_pos else evidence_y) + 220.0 + action_index * 86.0);
                placeNode(action_node, action_x, action_y_local);
                aci = aci + 1;
            }

            gi = 0;
            while gi < len(ghost_nodes) {
                ghost_node = ghost_nodes[gi];
                ghost_id = ghost_node["id"] if "id" in ghost_node else "";
                ghost_target = ghost_node["ghostTarget"] if "ghostTarget" in ghost_node else "";
                ghost_target_pos = raw_positions[ghost_target] if ghost_target in raw_positions else {"x": risk_x - 260.0, "y": options_y};
                raw_positions[ghost_id] = {
                    "x": (float(ghost_target_pos["x"]) if "x" in ghost_target_pos else risk_x - 260.0) + 330.0,
                    "y": (float(ghost_target_pos["y"]) if "y" in ghost_target_pos else options_y) + gi * 92.0
                };
                gi = gi + 1;
            }

            positions = resolveOverlapPositions(raw_positions);
            positions = applyFocusedBranchClearance(positions);
            positions = resolveOverlapPositions(positions);
            nodePositions = positions;
            if onLayoutResolved and positionsChanged(positions, savedNodePositions) {
                onLayoutResolved(positions);
            }
            return;
        }

        # Real graph nodes determine the main layered layout.
        # Suggested ghost nodes are positioned after layout as anchored callouts.
        ids: list = [];
        xs: list = [];
        ys: list = [];
        vxs: list = [];
        vys: list = [];
        txs: list = [];
        tys: list = [];
        depths: list = [];
        isGhostNode: list = [];
        halfWs: list = [];
        halfHs: list = [];
        hasStableAnchor: list = [];
        hasGraphPosition: list = [];
        isLockedNode: list = [];
        seededXs: list = [];
        seededYs: list = [];

        ni = 0;
        while ni < n_count {
            node_item = nodes[ni];
            node_box = estimateNodeBox(node_item);
            ghost_flag = node_item["isGhost"] if "isGhost" in node_item else False;
            node_id = node_item["id"];
            has_stable_anchor = node_id in savedNodePositions;
            node_has_position = "position" in node_item;
            seeded_pos = savedNodePositions[node_id] if has_stable_anchor else (node_item["position"] if node_has_position else {"x": 0.0, "y": 0.0});
            ids.append(node_item["id"]);
            xs.append(float(seeded_pos["x"]));
            ys.append(float(seeded_pos["y"]));
            vxs.append(0.0);
            vys.append(0.0);
            txs.append(0.0);
            tys.append(0.0);
            depths.append(-1);
            isGhostNode.append(ghost_flag);
            halfWs.append(node_box["w"] / 2.0);
            halfHs.append(node_box["h"] / 2.0);
            hasStableAnchor.append(has_stable_anchor);
            hasGraphPosition.append(node_has_position or has_stable_anchor);
            isLockedNode.append(node_item["layoutLocked"] if "layoutLocked" in node_item else False);
            seededXs.append(float(seeded_pos["x"]));
            seededYs.append(float(seeded_pos["y"]));
            ni = ni + 1;
        }

        root_idx = 0;
        ri = 0;
        while ri < n_count {
            if not isGhostNode[ri] and nodes[ri]["type"] == "THESIS" { root_idx = ri; break; }
            ri = ri + 1;
        }
        if isGhostNode[root_idx] {
            ri = 0;
            while ri < n_count {
                if not isGhostNode[ri] {
                    root_idx = ri;
                    break;
                }
                ri = ri + 1;
            }
        }

        depths[root_idx] = 0;
        bfs_queue: list = [root_idx];
        bqi = 0;
        while bqi < len(bfs_queue) {
            ci = bfs_queue[bqi];
            cur_id = ids[ci];
            cur_d = depths[ci];
            ei = 0;
            while ei < len(edges) {
                nb_id = "";
                edge_type = edgeRole(edges[ei]);
                is_ghost_edge = edges[ei]["isGhost"] if "isGhost" in edges[ei] else False;
                if not is_ghost_edge and (edge_type == "SUPPORTS" or edge_type == "RESOLVES") {
                    if edges[ei]["source"] == cur_id { nb_id = edges[ei]["target"]; }
                    elif edges[ei]["target"] == cur_id { nb_id = edges[ei]["source"]; }
                }
                if nb_id {
                    nbi = 0;
                    while nbi < n_count {
                        if ids[nbi] == nb_id and (not isGhostNode[nbi]) and depths[nbi] == -1 {
                            depths[nbi] = cur_d + 1;
                            bfs_queue.append(nbi);
                            break;
                        }
                        nbi = nbi + 1;
                    }
                }
                ei = ei + 1;
            }
            bqi = bqi + 1;
        }

        max_d = 0;
        mi = 0;
        while mi < n_count {
            if (not isGhostNode[mi]) and depths[mi] > max_d { max_d = depths[mi]; }
            mi = mi + 1;
        }
        mi = 0;
        while mi < n_count {
            if (not isGhostNode[mi]) and depths[mi] == -1 { depths[mi] = max_d + 1; }
            mi = mi + 1;
        }

        max_layer = 0;
        mi = 0;
        while mi < n_count {
            if (not isGhostNode[mi]) and depths[mi] > max_layer { max_layer = depths[mi]; }
            mi = mi + 1;
        }

        layer = 0;
        current_y = 0.0;
        while layer <= max_layer {
            count = 0;
            layer_max_h = 70.0;
            ci = 0;
            while ci < n_count {
                if (not isGhostNode[ci]) and depths[ci] == layer {
                    count = count + 1;
                    if halfHs[ci] * 2.0 > layer_max_h { layer_max_h = halfHs[ci] * 2.0; }
                }
                ci = ci + 1;
            }
            idx = 0;
            ci = 0;
            while ci < n_count {
                if (not isGhostNode[ci]) and depths[ci] == layer {
                    default_x = (idx - (count - 1) / 2.0) * 248.0;
                    txs[ci] = seededXs[ci] if hasGraphPosition[ci] else default_x;
                    tys[ci] = seededYs[ci] if hasGraphPosition[ci] else current_y;
                    if not hasGraphPosition[ci] {
                        xs[ci] = txs[ci];
                        ys[ci] = tys[ci];
                    }
                    idx = idx + 1;
                }
                ci = ci + 1;
            }
            current_y = current_y + layer_max_h + 82.0;
            layer = layer + 1;
        }

        force_si: list = [];
        force_ti: list = [];
        ei = 0;
        while ei < len(edges) {
            src = edges[ei]["source"];
            tgt = edges[ei]["target"];
            edge_type = edgeRole(edges[ei]);
            is_ghost_edge = edges[ei]["isGhost"] if "isGhost" in edges[ei] else False;
            if not is_ghost_edge and (edge_type == "SUPPORTS" or edge_type == "RESOLVES") {
                si = -1;
                ti = -1;
                fi = 0;
                while fi < n_count {
                    if ids[fi] == src and (not isGhostNode[fi]) { si = fi; }
                    if ids[fi] == tgt and (not isGhostNode[fi]) { ti = fi; }
                    fi = fi + 1;
                }
                if si >= 0 and ti >= 0 {
                    force_si.append(si);
                    force_ti.append(ti);
                }
            }
            ei = ei + 1;
        }

        degs: list = [];
        di = 0;
        while di < n_count { degs.append(0); di = di + 1; }
        ei = 0;
        while ei < len(force_si) {
            degs[force_si[ei]] = degs[force_si[ei]] + 1;
            degs[force_ti[ei]] = degs[force_ti[ei]] + 1;
            ei = ei + 1;
        }

        alpha = 0.3;
        tick = 0;
        while tick < 150 {
            alpha = alpha * 0.88;

            ei = 0;
            while ei < len(force_si) {
                si = force_si[ei];
                ti = force_ti[ei];
                dx = xs[ti] + vxs[ti] - xs[si] - vxs[si];
                dy = ys[ti] + vys[ti] - ys[si] - vys[si];
                dist = (dx * dx + dy * dy) ** 0.5;
                if dist < 0.001 { dist = 0.001; }
                strength = (dist - 170.0) / dist * alpha * 0.05;
                fx = dx * strength;
                fy = dy * strength;
                mobility_si = 0.28 if isLockedNode[si] else 1.0;
                mobility_ti = 0.28 if isLockedNode[ti] else 1.0;
                total_deg = degs[si] + degs[ti];
                bias = degs[ti] / total_deg if total_deg > 0 else 0.5;
                total_mobility = mobility_si + mobility_ti;
                share_si = mobility_si / total_mobility if total_mobility > 0.0 else 0.5;
                share_ti = mobility_ti / total_mobility if total_mobility > 0.0 else 0.5;
                vxs[ti] = vxs[ti] - fx * bias * share_ti;
                vys[ti] = vys[ti] - fy * bias * share_ti;
                vxs[si] = vxs[si] + fx * (1.0 - bias) * share_si;
                vys[si] = vys[si] + fy * (1.0 - bias) * share_si;
                ei = ei + 1;
            }

            ia = 0;
            while ia < n_count {
                if isGhostNode[ia] { ia = ia + 1; continue; }
                ib = ia + 1;
                while ib < n_count {
                    if isGhostNode[ib] { ib = ib + 1; continue; }
                    dx = xs[ib] - xs[ia];
                    dy = ys[ib] - ys[ia];
                    dist_sq = dx * dx + dy * dy;
                    if dist_sq < 90000.0 and dist_sq > 0.01 {
                        dist = dist_sq ** 0.5;
                        w = -80.0 * alpha / dist;
                        ux = dx / dist;
                        uy = dy / dist;
                        mobility_a = 0.18 if isLockedNode[ia] else (0.55 if hasStableAnchor[ia] else (1.25 if hasGraphPosition[ia] else 1.0));
                        mobility_b = 0.18 if isLockedNode[ib] else (0.55 if hasStableAnchor[ib] else (1.25 if hasGraphPosition[ib] else 1.0));
                        total_mobility = mobility_a + mobility_b;
                        share_a = mobility_a / total_mobility if total_mobility > 0.0 else 0.5;
                        share_b = mobility_b / total_mobility if total_mobility > 0.0 else 0.5;
                        vxs[ia] = vxs[ia] + ux * w * share_a;
                        vys[ia] = vys[ia] + uy * w * share_a;
                        vxs[ib] = vxs[ib] - ux * w * share_b;
                        vys[ib] = vys[ib] - uy * w * share_b;
                    }
                    ib = ib + 1;
                }
                ia = ia + 1;
            }

            ia = 0;
            while ia < n_count {
                if isGhostNode[ia] { ia = ia + 1; continue; }
                ib = ia + 1;
                while ib < n_count {
                    if isGhostNode[ib] { ib = ib + 1; continue; }
                    dx = xs[ib] - xs[ia];
                    dy = ys[ib] - ys[ia];
                    pair_pad_x = 24.0 if ((not hasStableAnchor[ia] and hasGraphPosition[ia]) or (not hasStableAnchor[ib] and hasGraphPosition[ib])) else 12.0;
                    pair_pad_y = 18.0 if ((not hasStableAnchor[ia] and hasGraphPosition[ia]) or (not hasStableAnchor[ib] and hasGraphPosition[ib])) else 12.0;
                    overlap_x = (halfWs[ia] + halfWs[ib] + pair_pad_x) - abs(dx);
                    overlap_y = (halfHs[ia] + halfHs[ib] + pair_pad_y) - abs(dy);
                    if overlap_x > 0.0 and overlap_y > 0.0 {
                        mobility_a = 0.18 if isLockedNode[ia] else (0.5 if hasStableAnchor[ia] else (1.35 if hasGraphPosition[ia] else 1.0));
                        mobility_b = 0.18 if isLockedNode[ib] else (0.5 if hasStableAnchor[ib] else (1.35 if hasGraphPosition[ib] else 1.0));
                        total_mobility = mobility_a + mobility_b;
                        share_a = mobility_a / total_mobility if total_mobility > 0.0 else 0.5;
                        share_b = mobility_b / total_mobility if total_mobility > 0.0 else 0.5;
                        if overlap_x < overlap_y {
                            push_x = overlap_x * 0.5;
                            if dx >= 0.0 {
                                vxs[ib] = vxs[ib] + push_x * share_b;
                                vxs[ia] = vxs[ia] - push_x * share_a;
                            } else {
                                vxs[ib] = vxs[ib] - push_x * share_b;
                                vxs[ia] = vxs[ia] + push_x * share_a;
                            }
                        } else {
                            push_y = overlap_y * 0.5;
                            if dy >= 0.0 {
                                vys[ib] = vys[ib] + push_y * share_b;
                                vys[ia] = vys[ia] - push_y * share_a;
                            } else {
                                vys[ib] = vys[ib] - push_y * share_b;
                                vys[ia] = vys[ia] + push_y * share_a;
                            }
                        }
                    }
                    ib = ib + 1;
                }
                ia = ia + 1;
            }

            pi = 0;
            while pi < n_count {
                if not isGhostNode[pi] {
                    anchor_strength_x = 0.2 if isLockedNode[pi] else (0.12 if hasStableAnchor[pi] else (0.035 if hasGraphPosition[pi] else 0.08));
                    anchor_strength_y = 0.34 if isLockedNode[pi] else (0.22 if hasStableAnchor[pi] else (0.06 if hasGraphPosition[pi] else 0.3));
                    vxs[pi] = vxs[pi] + (txs[pi] - xs[pi]) * anchor_strength_x * alpha;
                    vys[pi] = vys[pi] + (tys[pi] - ys[pi]) * anchor_strength_y * alpha;
                }
                pi = pi + 1;
            }

            pi = 0;
            while pi < n_count {
                if not isGhostNode[pi] {
                    drag = 0.42 if isLockedNode[pi] else (0.32 if hasStableAnchor[pi] else (0.28 if hasGraphPosition[pi] else 0.25));
                    vxs[pi] = vxs[pi] * drag;
                    vys[pi] = vys[pi] * drag;
                    xs[pi] = xs[pi] + vxs[pi];
                    ys[pi] = ys[pi] + vys[pi];

                    if isLockedNode[pi] {
                        xs[pi] = clampAroundAnchor(xs[pi], txs[pi], 44.0);
                        ys[pi] = clampAroundAnchor(ys[pi], tys[pi], 44.0);
                    } elif hasStableAnchor[pi] {
                        xs[pi] = clampAroundAnchor(xs[pi], txs[pi], 110.0);
                        ys[pi] = clampAroundAnchor(ys[pi], tys[pi], 96.0);
                    } elif hasGraphPosition[pi] {
                        xs[pi] = clampAroundAnchor(xs[pi], txs[pi], 220.0);
                        ys[pi] = clampAroundAnchor(ys[pi], tys[pi], 190.0);
                    }
                }
                pi = pi + 1;
            }

            tick = tick + 1;
        }

        min_x = 99999.0;
        min_y = 99999.0;
        pi = 0;
        while pi < n_count {
            if not isGhostNode[pi] {
                if xs[pi] < min_x { min_x = xs[pi]; }
                if ys[pi] < min_y { min_y = ys[pi]; }
            }
            pi = pi + 1;
        }

        positions: dict = {};
        pi = 0;
        while pi < n_count {
            if not isGhostNode[pi] {
                positions[ids[pi]] = {
                    "x": xs[pi] - min_x + 200,
                    "y": ys[pi] - min_y + 100
                };
            }
            pi = pi + 1;
        }

        # Counterargument-style nodes and suggested ghost nodes render in a side lane
        # instead of influencing the main structural layout.
        contra_groups: dict = {};
        ei = 0;
        while ei < len(edges) {
            edge_type = edgeRole(edges[ei]);
            if edge_type == "OPPOSES" {
                src = edges[ei]["source"];
                tgt = edges[ei]["target"];
                if tgt in positions {
                    contra_bucket: list = list(contra_groups[tgt]) if tgt in contra_groups else [];
                    contra_bucket.append(src);
                    contra_groups[tgt] = contra_bucket;
                }
            }
            ei = ei + 1;
        }

        ti = 0;
        while ti < len(nodes) {
            tgt_id = nodes[ti]["id"];
            if tgt_id in contra_groups and tgt_id in positions {
                contra_ids = contra_groups[tgt_id];
                cj = 0;
                while cj < len(contra_ids) {
                    src_id = contra_ids[cj];
                    src_box = getNodeBox(src_id);
                    tgt_box = getNodeBox(tgt_id);
                    vertical_gap = max(88.0, (src_box["h"] + tgt_box["h"]) / 2.0 + 14.0);
                    target_pos = positions[tgt_id];
                    is_ghost_src = False;
                    src_locked = False;
                    si = 0;
                    while si < len(nodes) {
                        if nodes[si]["id"] == src_id {
                            is_ghost_src = nodes[si]["isGhost"] if "isGhost" in nodes[si] else False;
                            src_locked = nodes[si]["layoutLocked"] if "layoutLocked" in nodes[si] else False;
                            break;
                        }
                        si = si + 1;
                    }
                    extra_x = 120.0 if is_ghost_src else 0.0;
                    if src_locked and src_id in savedNodePositions {
                        positions[src_id] = savedNodePositions[src_id];
                    } else {
                        positions[src_id] = {
                            "x": target_pos["x"] + 252.0 + extra_x,
                            "y": target_pos["y"] + (cj - (len(contra_ids) - 1) / 2.0) * vertical_gap
                        };
                    }
                    cj = cj + 1;
                }
            }
            ti = ti + 1;
        }

        positions = spreadDenseLayerNeighbors(positions, ids, depths);
        positions = applyFocusedBranchClearance(positions);
        positions = resolveOverlapPositions(positions);
        positions = applyFocusedBranchClearance(positions);
        positions = resolveOverlapPositions(positions);

        nodePositions = positions;
        if onLayoutResolved and positionsChanged(positions, savedNodePositions) {
            onLayoutResolved(positions);
        }
    }

    def getPos(nid: str) -> dict {
        if nid in nodePositions { return nodePositions[nid]; }
        # Fallback to node's original position
        fi = 0;
        while fi < len(nodes) {
            if nodes[fi]["id"] == nid {
                return nodes[fi]["position"] if "position" in nodes[fi] else {"x": 0, "y": 0};
            }
            fi = fi + 1;
        }
        return {"x": 0, "y": 0};
    }

    # Compute branch set for dimming
    branchIds = computeBranchIds(focusBranch) if focusBranch else [];

    def isInBranch(nid: str) -> bool {
        return isBranchNodeId(nid);
    }

    def edgeColor(t: str) -> str {
        norm = "OPPOSES" if t == "CONTRADICTS" else ("RESOLVES" if t == "ADDRESSES" else t);
        return EDGE_COLORS[norm] if norm in EDGE_COLORS else "#6b7280";
    }

    def edgeDash(t: str) -> str {
        norm = "OPPOSES" if t == "CONTRADICTS" else t;
        return "6,4" if norm == "OPPOSES" or norm == "BLOCKS" else "none";
    }

    # ── Zoom / Pan / Drag ──
    def handleWheel(e: any) -> None {
        e.preventDefault();
        new_scale = max(0.15, min(4.0, scale - e.deltaY * 0.001));
        scale = new_scale;
    }

    def zoomIn()     -> None { scale = min(4.0, scale + 0.15); }
    def zoomOut()    -> None { scale = max(0.15, scale - 0.15); }
    def resetView()  -> None { scale = 1.0; viewX = 40.0; viewY = 40.0; }

    def handleCanvasMouseDown(e: any) -> None {
        if draggingNodeId { return; }
        isPanning = True;
        panStartX = e.clientX - viewX;
        panStartY = e.clientY - viewY;
    }

    def handleNodeMouseDown(e: any, nodeId: str) -> None {
        e.preventDefault();
        e.stopPropagation();
        canvas = e.currentTarget.closest("[data-graph-canvas]");
        rect   = canvas.getBoundingClientRect();
        pos    = getPos(nodeId);
        nodeDragOffsetX = (e.clientX - rect.left - viewX) / scale - pos["x"];
        nodeDragOffsetY = (e.clientY - rect.top  - viewY) / scale - pos["y"];
        draggingNodeId    = nodeId;
        dragDidMove       = False;
        dragStartClientX  = e.clientX;
        dragStartClientY  = e.clientY;
    }

    def handleMouseMove(e: any) -> None {
        if draggingNodeId {
            # Only count as drag if mouse moved more than 4px (prevents click jitter)
            dx = e.clientX - dragStartClientX;
            dy = e.clientY - dragStartClientY;
            if not dragDidMove and (dx * dx + dy * dy) < 16 {
                return;
            }
            rect  = e.currentTarget.getBoundingClientRect();
            new_x = (e.clientX - rect.left - viewX) / scale - nodeDragOffsetX;
            new_y = (e.clientY - rect.top  - viewY) / scale - nodeDragOffsetY;
            updated: dict = {};
            ki = 0;
            while ki < len(nodes) {
                k = nodes[ki]["id"];
                if k in nodePositions {
                    updated[k] = {"x": nodePositions[k]["x"], "y": nodePositions[k]["y"]};
                }
                ki = ki + 1;
            }
            updated[draggingNodeId] = {"x": new_x, "y": new_y};
            nodePositions = updated;
            dragDidMove   = True;
            return;
        }
        if isPanning {
            viewX = e.clientX - panStartX;
            viewY = e.clientY - panStartY;
        }
    }

    def handleMouseUp(e: any) -> None {
        if dragDidMove and onNodePositionsChange {
            onNodePositionsChange(nodePositions);
        }
        draggingNodeId = None;
        isPanning      = False;
        dragDidMove    = False;
    }

    def handleNodeClickInternal(nodeItem: dict) -> None {
        if not dragDidMove {
            is_ghost = nodeItem["isGhost"] if "isGhost" in nodeItem else False;
            if is_ghost and onGhostAccept {
                # Ghost nodes trigger accept flow instead of selection
                ghost_target = nodeItem["ghostTarget"] if "ghostTarget" in nodeItem else "";
                ghost_text = nodeItem["content"] if "content" in nodeItem else "";
                onGhostAccept({"text": ghost_text, "target_node": ghost_target});
            } elif onNodeClick {
                onNodeClick(nodeItem);
            }
        }
    }

    # ── Build edge SVG elements ──
    edge_elements: list = [];
    ei = 0;
    while ei < len(edges) {
        cur_e = edges[ei];
        s_pos = getPos(cur_e["source"]);
        t_pos = getPos(cur_e["target"]);
        s_box = getNodeBox(cur_e["source"]);
        t_box = getNodeBox(cur_e["target"]);
        sx = s_pos["x"]; sy = s_pos["y"];
        tx = t_pos["x"]; ty = t_pos["y"];
        s_half_h = s_box["h"] / 2.0;
        t_half_h = t_box["h"] / 2.0;
        mid_y = (sy + s_half_h + ty - t_half_h) / 2.0;
        mx = (sx + tx) / 2.0;
        edge_role = edgeRole(cur_e);
        color  = edgeColor(edge_role);
        dash   = edgeDash(edge_role);

        path_d = f"M {sx},{sy + s_half_h} C {sx},{mid_y} {tx},{mid_y} {tx},{ty - t_half_h}";

        e_type = edge_role;
        mkr_id = "mk-sup";
        if e_type == "OPPOSES" { mkr_id = "mk-con"; }
        elif e_type == "RESOLVES" or e_type == "IMPLEMENTS" or e_type == "HAS_OPTION" or e_type == "BLOCKS" or e_type == "DEPENDS_ON" { mkr_id = "mk-adr"; }

        is_ghost_edge = cur_e["isGhost"] if "isGhost" in cur_e else False;
        both_in = isInBranch(cur_e["source"]) and isInBranch(cur_e["target"]);
        e_opacity = "0.25" if is_ghost_edge else ("0.7" if both_in else "0.1");
        e_width = "1.5" if is_ghost_edge else ("2" if both_in else "1");
        if is_ghost_edge { dash = "4,3"; }

        # Show weight percentage on edge if available (never for ghost edges)
        show_edge_label = False;
        edge_label_text = "";
        if not is_ghost_edge and "weight" in cur_e {
            e_weight = cur_e["weight"];
            try {
                w_float = float(str(e_weight));
                # Guard against NaN: NaN != NaN
                if w_float == w_float and w_float >= 0.0 and w_float <= 1.0 {
                    w_val = int(w_float * 100);
                    edge_label_text = f"{w_val}%";
                    show_edge_label = True;
                }
            } except Exception {
                show_edge_label = False;
            }
        }

        lbl_half_w = 20 if show_edge_label else 0;

        if show_edge_label {
            edge_elements.append(
                <g key={cur_e["id"]} opacity={e_opacity}>
                    <path d={path_d} stroke={color} strokeWidth={e_width}
                          strokeDasharray={dash} fill="none"
                          markerEnd={f"url(#{mkr_id})"} />
                    <rect x={str(mx - lbl_half_w)} y={str(mid_y - 10)} width={str(lbl_half_w * 2)} height="20" rx="10"
                          style={{"fill": "var(--color-edge-label-bg)", "stroke": "var(--color-edge-label-border)"}}
                          strokeWidth="1" />
                    <text x={str(mx)} y={str(mid_y + 4)} textAnchor="middle" fontSize="8.5"
                          fill={color} fontWeight="600" fontFamily="DM Sans, sans-serif">
                        {edge_label_text}
                    </text>
                </g>
            );
        } else {
            edge_elements.append(
                <g key={cur_e["id"]} opacity={e_opacity}>
                    <path d={path_d} stroke={color} strokeWidth={e_width}
                          strokeDasharray={dash} fill="none"
                          markerEnd={f"url(#{mkr_id})"} />
                </g>
            );
        }
        ei = ei + 1;
    }

    # ── Helper functions for proper closure binding in while loops ──
    def makeNodeClickHandler(item: dict) -> any {
        return lambda -> None { handleNodeClickInternal(item); };
    }
    def makeNodeMouseDownHandler(nodeId: str) -> any {
        return lambda e -> None { handleNodeMouseDown(e, nodeId); };
    }

    # ── Build node SVG elements ──
    node_elements: list = [];
    ni = 0;
    while ni < len(nodes) {
        node_item = nodes[ni];
        pos = getPos(node_item["id"]);
        is_dragging = draggingNodeId == node_item["id"];
        is_sel = selectedNodeId == node_item["id"];
        is_dim = not isInBranch(node_item["id"]);
        node_cursor = "grabbing" if is_dragging else "grab";
        nid = node_item["id"];

        is_ghost_node = node_item["isGhost"] if "isGhost" in node_item else False;
        node_click_fn = makeNodeClickHandler(node_item);
        node_md_fn = makeNodeMouseDownHandler(nid);
        node_elements.append(
            <g key={nid}
                transform={f"translate({pos['x']}, {pos['y']})"}
                style={{"cursor": node_cursor, "transition": "transform 0.05s ease-out" if not is_dragging else "none"}}
                onMouseDown={node_md_fn}
                onClick={node_click_fn}
            >
                <ArgumentNodeComponent
                    node={node_item}
                    isSelected={is_sel}
                    isDimmed={is_dim}
                    isGhost={is_ghost_node}
                />
            </g>
        );
        ni = ni + 1;
    }

    return (
        <div
            className="graph-canvas"
            data-graph-canvas="true"
            onMouseDown={handleCanvasMouseDown}
            onMouseMove={handleMouseMove}
            onMouseUp={handleMouseUp}
            onMouseLeave={handleMouseUp}
            onWheel={handleWheel}
        >
            <svg
                xmlns="http://www.w3.org/2000/svg"
                className="graph-svg-layer"
            >
                <defs>
                    <marker id="mk-sup" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
                        <polygon points="0 0,8 3,0 6" fill="#10b981" />
                    </marker>
                    <marker id="mk-con" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
                        <polygon points="0 0,8 3,0 6" fill="#ef4444" />
                    </marker>
                    <marker id="mk-adr" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
                        <polygon points="0 0,8 3,0 6" fill="#0057B7" /> # UMich royal blue (was #8b5cf6)
                    </marker>
                    <filter id="drop-shadow" x="-20%" y="-20%" width="140%" height="140%">
                        <feDropShadow dx="0" dy="2" stdDeviation="4" floodOpacity="0.1" />
                    </filter>
                    <filter id="glow-selected" x="-30%" y="-30%" width="160%" height="160%">
                        <feGaussianBlur stdDeviation="6" result="blur" />
                        <feMerge>
                            <feMergeNode in="blur" />
                            <feMergeNode in="SourceGraphic" />
                        </feMerge>
                    </filter>
                </defs>
                <g transform={f"translate({viewX}, {viewY}) scale({scale})"}>
                    {edge_elements}
                    {node_elements}
                </g>
            </svg>

            <div className="graph-zoom-controls">
                <button
                    className="graph-zoom-btn"
                    onClick={zoomIn}
                    title="Zoom in"
                >+</button>
                <button
                    className="graph-zoom-btn"
                    onClick={zoomOut}
                    title="Zoom out"
                >−</button>
                <button
                    className="graph-zoom-btn graph-zoom-btn-sm"
                    onClick={resetView}
                    title="Reset view"
                >⊙</button>
            </div>

            {(
                <div className="graph-hint">
                    Click a node for details · Drag to rearrange · Scroll to zoom
                </div>
            )}
        </div>
    );
}
