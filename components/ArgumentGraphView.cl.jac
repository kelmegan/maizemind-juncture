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

    can with entry {
        n_count = len(nodes);
        n_edges = len(edges);
        if n_count == 0 { return; }

        # ── Build parallel arrays: ids[], xs[], ys[], vxs[], vys[] ──
        # Using ONLY index-based while loops (no for-in on dicts)

        ids: list = [];
        xs: list = [];
        ys: list = [];
        vxs: list = [];
        vys: list = [];
        txs: list = [];
        tys: list = [];
        depths: list = [];

        # Initialize from node positions
        ni = 0;
        while ni < n_count {
            ids.append(nodes[ni]["id"]);
            xs.append(nodes[ni]["position"]["x"] if "position" in nodes[ni] else 0.0);
            ys.append(nodes[ni]["position"]["y"] if "position" in nodes[ni] else 0.0);
            vxs.append(0.0);
            vys.append(0.0);
            txs.append(0.0);
            tys.append(0.0);
            depths.append(-1);
            ni = ni + 1;
        }

        # Find index of root (THESIS or first)
        root_idx = 0;
        ri = 0;
        while ri < n_count {
            if nodes[ri]["type"] == "THESIS" { root_idx = ri; break; }
            ri = ri + 1;
        }

        # BFS to compute depths using index arrays
        depths[root_idx] = 0;
        bfs_queue: list = [root_idx];
        bqi = 0;
        while bqi < len(bfs_queue) {
            ci = bfs_queue[bqi];
            cur_id = ids[ci];
            cur_d = depths[ci];
            # Scan edges for neighbors
            ei = 0;
            while ei < n_edges {
                nb_id = "";
                if edges[ei]["source"] == cur_id { nb_id = edges[ei]["target"]; }
                elif edges[ei]["target"] == cur_id { nb_id = edges[ei]["source"]; }
                if nb_id {
                    # Find index of neighbor
                    nbi = 0;
                    while nbi < n_count {
                        if ids[nbi] == nb_id and depths[nbi] == -1 {
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

        # Fix disconnected nodes (depth still -1)
        max_d = 0;
        mi = 0;
        while mi < n_count {
            if depths[mi] > max_d { max_d = depths[mi]; }
            mi = mi + 1;
        }
        mi = 0;
        while mi < n_count {
            if depths[mi] == -1 { depths[mi] = max_d + 1; }
            mi = mi + 1;
        }

        # Count nodes per depth layer and compute BFS target positions
        # First pass: count per layer
        max_layer = 0;
        mi = 0;
        while mi < n_count {
            if depths[mi] > max_layer { max_layer = depths[mi]; }
            mi = mi + 1;
        }

        # For each layer, count nodes and assign x positions
        layer = 0;
        while layer <= max_layer {
            # Count nodes in this layer
            count = 0;
            ci = 0;
            while ci < n_count {
                if depths[ci] == layer { count = count + 1; }
                ci = ci + 1;
            }
            # Assign positions to nodes in this layer
            idx = 0;
            ci = 0;
            while ci < n_count {
                if depths[ci] == layer {
                    txs[ci] = (idx - (count - 1) / 2.0) * 250;
                    tys[ci] = layer * 130.0;
                    # Start nodes at their target positions
                    xs[ci] = txs[ci];
                    ys[ci] = tys[ci];
                    idx = idx + 1;
                }
                ci = ci + 1;
            }
            layer = layer + 1;
        }

        # Precompute edge source/target indices
        edge_si: list = [];
        edge_ti: list = [];
        ei = 0;
        while ei < n_edges {
            src = edges[ei]["source"];
            tgt = edges[ei]["target"];
            si = -1;
            ti = -1;
            fi = 0;
            while fi < n_count {
                if ids[fi] == src { si = fi; }
                if ids[fi] == tgt { ti = fi; }
                fi = fi + 1;
            }
            edge_si.append(si);
            edge_ti.append(ti);
            ei = ei + 1;
        }

        # Compute degrees for link bias
        degs: list = [];
        di = 0;
        while di < n_count { degs.append(0); di = di + 1; }
        ei = 0;
        while ei < n_edges {
            if edge_si[ei] >= 0 { degs[edge_si[ei]] = degs[edge_si[ei]] + 1; }
            if edge_ti[ei] >= 0 { degs[edge_ti[ei]] = degs[edge_ti[ei]] + 1; }
            ei = ei + 1;
        }

        # ── Force simulation: exact d3-force parameters from mockup ──
        # forceLink:     distance=140, strength=0.05
        # forceManyBody: strength=-80, distanceMax=300
        # forceCollide:  radius=112
        # forceX:        strength=0.08
        # forceY:        strength=0.3
        # alphaDecay=0.12, velocityDecay=0.75 (internal=0.25), alpha=0.3, 150 ticks

        alpha = 0.3;
        tick = 0;
        while tick < 150 {
            # Alpha decay
            alpha = alpha * 0.88;

            # Link force
            ei = 0;
            while ei < n_edges {
                si = edge_si[ei];
                ti = edge_ti[ei];
                if si >= 0 and ti >= 0 {
                    dx = xs[ti] + vxs[ti] - xs[si] - vxs[si];
                    dy = ys[ti] + vys[ti] - ys[si] - vys[si];
                    dist = (dx * dx + dy * dy) ** 0.5;
                    if dist < 0.001 { dist = 0.001; }
                    strength = (dist - 140.0) / dist * alpha * 0.05;
                    fx = dx * strength;
                    fy = dy * strength;
                    total_deg = degs[si] + degs[ti];
                    bias = degs[ti] / total_deg if total_deg > 0 else 0.5;
                    vxs[ti] = vxs[ti] - fx * bias;
                    vys[ti] = vys[ti] - fy * bias;
                    vxs[si] = vxs[si] + fx * (1.0 - bias);
                    vys[si] = vys[si] + fy * (1.0 - bias);
                }
                ei = ei + 1;
            }

            # Many-body (charge) force
            ia = 0;
            while ia < n_count {
                ib = ia + 1;
                while ib < n_count {
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

            # Collision force (radius=112, pair min distance=224)
            ia = 0;
            while ia < n_count {
                ib = ia + 1;
                while ib < n_count {
                    dx = xs[ib] - xs[ia];
                    dy = ys[ib] - ys[ia];
                    dist = (dx * dx + dy * dy) ** 0.5;
                    if dist < 224.0 and dist > 0.01 {
                        overlap = (224.0 - dist) / dist * 0.5;
                        vxs[ib] = vxs[ib] + dx * overlap;
                        vys[ib] = vys[ib] + dy * overlap;
                        vxs[ia] = vxs[ia] - dx * overlap;
                        vys[ia] = vys[ia] - dy * overlap;
                    }
                    ib = ib + 1;
                }
                ia = ia + 1;
            }

            # X/Y positioning forces
            pi = 0;
            while pi < n_count {
                vxs[pi] = vxs[pi] + (txs[pi] - xs[pi]) * 0.08 * alpha;
                vys[pi] = vys[pi] + (tys[pi] - ys[pi]) * 0.3 * alpha;
                pi = pi + 1;
            }

            # Apply velocity with decay (d3: vx *= 1-velocityDecay, then x += vx)
            pi = 0;
            while pi < n_count {
                vxs[pi] = vxs[pi] * 0.25;
                vys[pi] = vys[pi] * 0.25;
                xs[pi] = xs[pi] + vxs[pi];
                ys[pi] = ys[pi] + vys[pi];
                pi = pi + 1;
            }

            tick = tick + 1;
        }

        # Normalize positions
        min_x = 99999.0;
        min_y = 99999.0;
        pi = 0;
        while pi < n_count {
            if xs[pi] < min_x { min_x = xs[pi]; }
            if ys[pi] < min_y { min_y = ys[pi]; }
            pi = pi + 1;
        }

        positions: dict = {};
        pi = 0;
        while pi < n_count {
            positions[ids[pi]] = {
                "x": xs[pi] - min_x + 200,
                "y": ys[pi] - min_y + 100
            };
            pi = pi + 1;
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
        sx = s_pos["x"]; sy = s_pos["y"];
        tx = t_pos["x"]; ty = t_pos["y"];
        mid_y = (sy + 40 + ty - 40) / 2.0;
        mx = (sx + tx) / 2.0;
        color  = edgeColor(cur_e["type"]);
        dash   = edgeDash(cur_e["type"]);

        path_d = f"M {sx},{sy + 40} C {sx},{mid_y} {tx},{mid_y} {tx},{ty - 40}";

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
