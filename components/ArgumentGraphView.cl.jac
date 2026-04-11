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
    selectedNodeId = props.selectedNodeId if props.selectedNodeId else None;
    focusBranch = props.focusBranch if props.focusBranch else None;

    NODE_W   = 200;
    NODE_H   = 80;

    EDGE_COLORS = {
        "SUPPORTS": "#10b981", "CONTRADICTS": "#ef4444",
        "ADDRESSES": "#0057B7"   # UMich royal blue (was purple #8b5cf6)
    };
    EDGE_LABELS = {
        "SUPPORTS": "SUP", "CONTRADICTS": "CON",
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

    can with entry {
        n_count = len(nodes);
        if n_count == 0 { return; }

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

        ni = 0;
        while ni < n_count {
            node_item = nodes[ni];
            node_box = estimateNodeBox(node_item);
            ghost_flag = node_item["isGhost"] if "isGhost" in node_item else False;
            ids.append(node_item["id"]);
            xs.append(node_item["position"]["x"] if "position" in node_item else 0.0);
            ys.append(node_item["position"]["y"] if "position" in node_item else 0.0);
            vxs.append(0.0);
            vys.append(0.0);
            txs.append(0.0);
            tys.append(0.0);
            depths.append(-1);
            isGhostNode.append(ghost_flag);
            halfWs.append(node_box["w"] / 2.0);
            halfHs.append(node_box["h"] / 2.0);
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
                edge_type = edges[ei]["type"] if "type" in edges[ei] else "";
                is_ghost_edge = edges[ei]["isGhost"] if "isGhost" in edges[ei] else False;
                if not is_ghost_edge and (edge_type == "SUPPORTS" or edge_type == "ADDRESSES") {
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
                    txs[ci] = (idx - (count - 1) / 2.0) * 280.0;
                    tys[ci] = current_y;
                    xs[ci] = txs[ci];
                    ys[ci] = tys[ci];
                    idx = idx + 1;
                }
                ci = ci + 1;
            }
            current_y = current_y + layer_max_h + 96.0;
            layer = layer + 1;
        }

        force_si: list = [];
        force_ti: list = [];
        ei = 0;
        while ei < len(edges) {
            src = edges[ei]["source"];
            tgt = edges[ei]["target"];
            edge_type = edges[ei]["type"] if "type" in edges[ei] else "";
            is_ghost_edge = edges[ei]["isGhost"] if "isGhost" in edges[ei] else False;
            if not is_ghost_edge and (edge_type == "SUPPORTS" or edge_type == "ADDRESSES") {
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
                total_deg = degs[si] + degs[ti];
                bias = degs[ti] / total_deg if total_deg > 0 else 0.5;
                vxs[ti] = vxs[ti] - fx * bias;
                vys[ti] = vys[ti] - fy * bias;
                vxs[si] = vxs[si] + fx * (1.0 - bias);
                vys[si] = vys[si] + fy * (1.0 - bias);
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
                        vxs[ia] = vxs[ia] + ux * w;
                        vys[ia] = vys[ia] + uy * w;
                        vxs[ib] = vxs[ib] - ux * w;
                        vys[ib] = vys[ib] - uy * w;
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
                    overlap_x = (halfWs[ia] + halfWs[ib] + 28.0) - abs(dx);
                    overlap_y = (halfHs[ia] + halfHs[ib] + 28.0) - abs(dy);
                    if overlap_x > 0.0 and overlap_y > 0.0 {
                        if overlap_x < overlap_y {
                            push_x = overlap_x * 0.5;
                            if dx >= 0.0 {
                                vxs[ib] = vxs[ib] + push_x;
                                vxs[ia] = vxs[ia] - push_x;
                            } else {
                                vxs[ib] = vxs[ib] - push_x;
                                vxs[ia] = vxs[ia] + push_x;
                            }
                        } else {
                            push_y = overlap_y * 0.5;
                            if dy >= 0.0 {
                                vys[ib] = vys[ib] + push_y;
                                vys[ia] = vys[ia] - push_y;
                            } else {
                                vys[ib] = vys[ib] - push_y;
                                vys[ia] = vys[ia] + push_y;
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
                    vxs[pi] = vxs[pi] + (txs[pi] - xs[pi]) * 0.08 * alpha;
                    vys[pi] = vys[pi] + (tys[pi] - ys[pi]) * 0.3 * alpha;
                }
                pi = pi + 1;
            }

            pi = 0;
            while pi < n_count {
                if not isGhostNode[pi] {
                    vxs[pi] = vxs[pi] * 0.25;
                    vys[pi] = vys[pi] * 0.25;
                    xs[pi] = xs[pi] + vxs[pi];
                    ys[pi] = ys[pi] + vys[pi];
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
            edge_type = edges[ei]["type"] if "type" in edges[ei] else "";
            if edge_type == "CONTRADICTS" {
                src = edges[ei]["source"];
                tgt = edges[ei]["target"];
                if tgt in positions {
                    if tgt not in contra_groups {
                        contra_groups[tgt] = [];
                    }
                    contra_groups[tgt].append(src);
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
                    vertical_gap = max(110.0, (src_box["h"] + tgt_box["h"]) / 2.0 + 24.0);
                    target_pos = positions[tgt_id];
                    is_ghost_src = False;
                    si = 0;
                    while si < len(nodes) {
                        if nodes[si]["id"] == src_id {
                            is_ghost_src = nodes[si]["isGhost"] if "isGhost" in nodes[si] else False;
                            break;
                        }
                        si = si + 1;
                    }
                    extra_x = 120.0 if is_ghost_src else 0.0;
                    positions[src_id] = {
                        "x": target_pos["x"] + 280.0 + extra_x,
                        "y": target_pos["y"] + (cj - (len(contra_ids) - 1) / 2.0) * vertical_gap
                    };
                    cj = cj + 1;
                }
            }
            ti = ti + 1;
        }

        nodePositions = positions;
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
    def getBranchIds(rootId: str) -> list {
        result: list = [rootId];
        ei = 0;
        while ei < len(edges) {
            if edges[ei]["target"] == rootId and (edges[ei]["type"] == "SUPPORTS" or edges[ei]["type"] == "ADDRESSES") {
                src = edges[ei]["source"];
                if src not in result {
                    result.append(src);
                    ei2 = 0;
                    while ei2 < len(edges) {
                        if edges[ei2]["target"] == src and (edges[ei2]["type"] == "SUPPORTS" or edges[ei2]["type"] == "ADDRESSES") {
                            if edges[ei2]["source"] not in result { result.append(edges[ei2]["source"]); }
                        }
                        ei2 = ei2 + 1;
                    }
                }
            }
            ei = ei + 1;
        }
        return result;
    }

    branchIds = getBranchIds(focusBranch) if focusBranch else [];

    def isInBranch(nid: str) -> bool {
        if not focusBranch { return True; }
        return nid in branchIds;
    }

    def edgeColor(t: str) -> str {
        return EDGE_COLORS[t] if t in EDGE_COLORS else "#6b7280";
    }

    def edgeDash(t: str) -> str {
        return "6,4" if t == "CONTRADICTS" else "none";
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
        draggingNodeId  = nodeId;
        dragDidMove     = False;
    }

    def handleMouseMove(e: any) -> None {
        if draggingNodeId {
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
        draggingNodeId = None;
        isPanning      = False;
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
        color  = edgeColor(cur_e["type"]);
        dash   = edgeDash(cur_e["type"]);

        path_d = f"M {sx},{sy + s_half_h} C {sx},{mid_y} {tx},{mid_y} {tx},{ty - t_half_h}";

        e_type = cur_e["type"];
        mkr_id = "mk-sup";
        if e_type == "CONTRADICTS" { mkr_id = "mk-con"; }
        elif e_type == "ADDRESSES" { mkr_id = "mk-adr"; }

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
