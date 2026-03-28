"""MaizeMind - Interactive Argument Graph Viewer Component.
Renders nodes/edges as an interactive zoomable graph.
Handles branch selection, zoom-to-node, and per-branch LLM context.

Place this file at: components/GraphViewer.jac
"""


# ============================================================
# 1. BRANCH CONTEXT SYSTEM
#    Stores LLM working history per-branch so switching
#    branches doesn't lose context.
# ============================================================

"Stores one revision event for a node"
obj RevisionEntry {
    has timestamp: str,
        action: str,          # what the user did
        before_text: str,
        after_text: str,
        llm_reasoning: str;   # why the LLM suggested this
}

"Per-node context that travels with the node"
obj NodeContext {
    has node_id: str,
        revision_history: list[RevisionEntry] = [],
        branch_summary: str = "",    # LLM summary of this subtree's state
        working_notes: str = "";     # LLM's in-progress reasoning for this branch
}

"Manages all branch contexts for the session"
obj BranchContextStore {
    has contexts: dict[str, NodeContext] = {};

    """Get or create context for a node"""
    def get_context(node_id: str) -> NodeContext {
        if node_id not in self.contexts {
            self.contexts[node_id] = NodeContext(node_id=node_id);
        }
        return self.contexts[node_id];
    }

    """Gather full branch context: walk from node up to root,
    then collect all context in that subtree. Returns a string
    the LLM can use to understand the branch state."""
    def gather_branch_context(
        node_id: str,
        nodes: list,
        edges: list
    ) -> str {
        # Build parent map
        parent_map: dict[str, str] = {};
        children_map: dict[str, list[str]] = {};
        for e in edges {
            if e["type"] in ["supports", "depends_on"] {
                parent_map[e["from_id"]] = e["to_id"];
                if e["to_id"] not in children_map {
                    children_map[e["to_id"]] = [];
                }
                children_map[e["to_id"]].append(e["from_id"]);
            }
        }

        # Walk up to find branch root
        branch_root = node_id;
        visited: list[str] = [];
        current = node_id;
        while current in parent_map and current not in visited {
            visited.append(current);
            current = parent_map[current];
            branch_root = current;
        }

        # Collect all nodes in this subtree
        subtree_ids: list[str] = [];
        queue: list[str] = [branch_root];
        while queue {
            nid = queue.pop(0);
            subtree_ids.append(nid);
            if nid in children_map {
                for child in children_map[nid] {
                    queue.append(child);
                }
            }
        }

        # Build context string from all nodes in branch
        node_map: dict[str, str] = {};
        for n in nodes {
            node_map[n["id"]] = f"[{n['type']}] {n['text']}";
        }

        context_parts: list[str] = ["=== Branch Context ==="];
        context_parts.append(f"Branch root: {branch_root}");
        context_parts.append(f"Selected node: {node_id}");
        context_parts.append(f"Nodes in branch: {len(subtree_ids)}");
        context_parts.append("");

        for sid in subtree_ids {
            label = node_map.get(sid, sid);
            context_parts.append(f"  {sid}: {label}");
            ctx = self.get_context(sid);
            if ctx.working_notes {
                context_parts.append(f"    [LLM notes]: {ctx.working_notes}");
            }
            if ctx.revision_history {
                last_rev = ctx.revision_history[-1];
                context_parts.append(f"    [Last revision]: {last_rev.action}");
            }
        }

        return "\n".join(context_parts);
    }

    """Save LLM working notes for a branch after interaction"""
    def save_working_notes(node_id: str, notes: str) -> None {
        ctx = self.get_context(node_id);
        ctx.working_notes = notes;
    }

    """Record a revision to a node"""
    def record_revision(
        node_id: str,
        action: str,
        before_text: str,
        after_text: str,
        llm_reasoning: str
    ) -> None {
        ctx = self.get_context(node_id);
        import from datetime { datetime }
        ctx.revision_history.append(
            RevisionEntry(
                timestamp=datetime.now().isoformat(),
                action=action,
                before_text=before_text,
                after_text=after_text,
                llm_reasoning=llm_reasoning
            )
        );
    }
}


# ============================================================
# 2. GRAPH LAYOUT ENGINE
#    Assigns x,y positions using tree layout (BFS from root)
# ============================================================

"Position info for a node"
obj NodePosition {
    has node_id: str,
        x: float,
        y: float,
        level: int = 0;
}

"""Calculate tree layout positions for all nodes.
Returns list of NodePosition objects."""
def calculate_layout(
    nodes: list[dict[str, str]],
    edges: list[dict[str, str]],
    canvas_width: float = 1200.0,
    level_height: float = 150.0
) -> list[NodePosition] {

    if not nodes {
        return [];
    }

    # Build adjacency: find children (nodes that this node supports/depends)
    children_map: dict[str, list[str]] = {};
    has_parent: list[str] = [];

    for e in edges {
        parent_id = e.get("to_id", "");
        child_id = e.get("from_id", "");
        if e.get("type", "") in ["supports", "depends_on"] {
            if parent_id not in children_map {
                children_map[parent_id] = [];
            }
            children_map[parent_id].append(child_id);
            has_parent.append(child_id);
        }
    }

    # Find root nodes (no parent)
    all_ids = [n.get("id", "") for n in nodes];
    roots = [nid for nid in all_ids if nid not in has_parent];

    # If no clear root, use the first thesis or first node
    if not roots {
        thesis = [n.get("id", "") for n in nodes if n.get("type", "") == "thesis"];
        roots = thesis if thesis else [all_ids[0]];
    }

    # BFS to assign levels
    level_map: dict[str, int] = {};
    queue: list[str] = [];
    for r in roots {
        queue.append(r);
        level_map[r] = 0;
    }

    while queue {
        current = queue.pop(0);
        current_level = level_map.get(current, 0);
        children = children_map.get(current, []);
        for child in children {
            if child not in level_map {
                level_map[child] = current_level + 1;
                queue.append(child);
            }
        }
    }

    # Assign any orphans
    for nid in all_ids {
        if nid not in level_map {
            level_map[nid] = 0;
        }
    }

    # Group by level
    levels: dict[int, list[str]] = {};
    for nid in all_ids {
        lvl = level_map[nid];
        if lvl not in levels {
            levels[lvl] = [];
        }
        levels[lvl].append(nid);
    }

    # Calculate positions
    positions: list[NodePosition] = [];
    for lvl in levels {
        nodes_at_level = levels[lvl];
        count = len(nodes_at_level);
        spacing = canvas_width / (count + 1);

        for (i, nid) in enumerate(nodes_at_level) {
            positions.append(NodePosition(
                node_id=nid,
                x=spacing * (i + 1),
                y=80.0 + lvl * level_height,
                level=lvl
            ));
        }
    }

    return positions;
}


# ============================================================
# 3. GRAPH VIEWER - Client-side React component
#    Renders the interactive graph with zoom/pan/click
# ============================================================

cl {

"""Interactive argument graph with zoom, pan, and node selection.
Props:
  - graph_nodes: list of node dicts from the pipeline
  - graph_edges: list of edge dicts from the pipeline
  - on_node_select: callback when a node is clicked
  - on_branch_focus: callback when zooming into a branch"""
def:pub GraphViewer(
    graph_nodes: list = [],
    graph_edges: list = [],
    on_node_select: any = None,
    on_branch_focus: any = None
) -> JsxElement {

    # --- State ---
    has selected_node_id: str = "",
        zoom_level: float = 1.0,
        pan_x: float = 0.0,
        pan_y: float = 0.0,
        is_panning: bool = False,
        pan_start_x: float = 0.0,
        pan_start_y: float = 0.0,
        hovered_node_id: str = "",
        focused_branch_root: str = "";

    # --- Node colors by type ---
    def get_node_color(node_type: str) -> str {
        if node_type == "thesis" { return "#8b5cf6"; }     # purple
        if node_type == "claim" { return "#3b82f6"; }      # blue
        if node_type == "evidence" { return "#10b981"; }    # green
        if node_type == "assumption" { return "#f59e0b"; }  # yellow
        if node_type == "counterarg" { return "#ef4444"; }  # red
        return "#6b7280";  # gray fallback
    }

    # --- Status border color ---
    def get_status_color(status: str) -> str {
        if status == "ok" { return "#10b981"; }         # green
        if status == "needs_work" { return "#f59e0b"; } # yellow
        if status == "missing" { return "#ef4444"; }    # red
        return "#d1d5db";  # gray
    }

    # --- Edge colors by type ---
    def get_edge_color(edge_type: str) -> str {
        if edge_type == "supports" { return "#10b981"; }    # green
        if edge_type == "contradicts" { return "#ef4444"; }  # red
        if edge_type == "depends_on" { return "#f59e0b"; }   # yellow
        if edge_type == "addresses" { return "#8b5cf6"; }    # purple
        return "#9ca3af";
    }

    # --- Edge dash pattern ---
    def get_edge_dash(edge_type: str) -> str {
        if edge_type == "contradicts" { return "8,4"; }
        if edge_type == "depends_on" { return "6,3"; }
        return "none";
    }

    # --- Calculate layout positions ---
    def get_positions() -> dict[str, dict[str, float]] {
        # Simple dict-based layout for client side
        pos_map: dict[str, dict[str, float]] = {};
        if not graph_nodes { return pos_map; }

        # Build children map
        children_map: dict[str, list[str]] = {};
        has_parent: list[str] = [];
        for e in graph_edges {
            p_id = e.get("to_id", "");
            c_id = e.get("from_id", "");
            if e.get("type", "") in ["supports", "depends_on"] {
                if p_id not in children_map {
                    children_map[p_id] = [];
                }
                children_map[p_id].append(c_id);
                has_parent.append(c_id);
            }
        }

        all_ids = [n.get("id", "") for n in graph_nodes];
        roots = [nid for nid in all_ids if nid not in has_parent];
        if not roots {
            roots = [all_ids[0]];
        }

        # BFS levels
        level_map: dict[str, int] = {};
        queue: list[str] = [];
        for r in roots {
            queue.append(r);
            level_map[r] = 0;
        }
        while queue {
            cur = queue.pop(0);
            for child in children_map.get(cur, []) {
                if child not in level_map {
                    level_map[child] = level_map[cur] + 1;
                    queue.append(child);
                }
            }
        }
        for nid in all_ids {
            if nid not in level_map {
                level_map[nid] = 0;
            }
        }

        # Group by level
        levels: dict[int, list[str]] = {};
        for nid in all_ids {
            lvl = level_map[nid];
            if lvl not in levels {
                levels[lvl] = [];
            }
            levels[lvl].append(nid);
        }

        # Position
        w = 1000.0;
        lh = 160.0;
        for lvl in levels {
            ns = levels[lvl];
            cnt = len(ns);
            sp = w / (cnt + 1);
            for (i, nid) in enumerate(ns) {
                pos_map[nid] = {
                    "x": sp * (i + 1),
                    "y": 60.0 + lvl * lh
                };
            }
        }

        return pos_map;
    }

    # --- Event handlers ---
    def handle_node_click(node_id: str) -> None {
        selected_node_id = node_id;
        if on_node_select { on_node_select(node_id); }
    }

    def handle_zoom_to_node(node_id: str) -> None {
        positions = get_positions();
        if node_id in positions {
            p = positions[node_id];
            # Center on node and zoom in
            zoom_level = 2.0;
            pan_x = -(p["x"] * 2.0 - 500.0);
            pan_y = -(p["y"] * 2.0 - 300.0);
        }
        selected_node_id = node_id;
        focused_branch_root = node_id;
        if on_branch_focus { on_branch_focus(node_id); }
    }

    def handle_zoom_out() -> None {
        zoom_level = 1.0;
        pan_x = 0.0;
        pan_y = 0.0;
        focused_branch_root = "";
    }

    def handle_wheel(e: any) -> None {
        e.preventDefault();
        delta = -e.deltaY * 0.001;
        new_zoom = zoom_level + delta;
        if new_zoom < 0.3 { new_zoom = 0.3; }
        if new_zoom > 4.0 { new_zoom = 4.0; }
        zoom_level = new_zoom;
    }

    def handle_mouse_down(e: any) -> None {
        if e.button == 0 {
            is_panning = True;
            pan_start_x = e.clientX - pan_x;
            pan_start_y = e.clientY - pan_y;
        }
    }

    def handle_mouse_move(e: any) -> None {
        if is_panning {
            pan_x = e.clientX - pan_start_x;
            pan_y = e.clientY - pan_start_y;
        }
    }

    def handle_mouse_up(e: any) -> None {
        is_panning = False;
    }

    # --- Render ---
    positions = get_positions();

    # SVG dimensions
    svg_w = 1000;
    svg_h = max(600, len(graph_nodes) * 80);

    return
        <div className="gv-container">

            <div className="gv-zoom-controls">
                <button
                    className="gv-zoom-btn"
                    onClick={lambda e: any -> None { zoom_level = min(4.0, zoom_level + 0.3); }}>
                    +
                </button>
                <button
                    className="gv-zoom-btn"
                    onClick={lambda e: any -> None { zoom_level = max(0.3, zoom_level - 0.3); }}>
                    -
                </button>
                <button
                    className="gv-zoom-btn gv-zoom-btn-fit"
                    onClick={lambda e: any -> None { handle_zoom_out(); }}>
                    Fit
                </button>
            </div>

            { focused_branch_root and
                <div
                    className="gv-branch-back-btn"
                    onClick={lambda e: any -> None { handle_zoom_out(); }}>
                    ← Back to full map
                </div>
            }

            <svg
                width="100%"
                height="100%"
                viewBox={f"0 0 {svg_w} {svg_h}"}
                onWheel={handle_wheel}
                onMouseDown={handle_mouse_down}
                onMouseMove={handle_mouse_move}
                onMouseUp={handle_mouse_up}
                onMouseLeave={handle_mouse_up}
                style={{"cursor": "grab" if not is_panning else "grabbing"}}>

                <g transform={f"translate({pan_x},{pan_y}) scale({zoom_level})"}>

                    { [
                        <g key={f"edge-{i}"}>
                            { (lambda e: any, ps: any -> JsxElement {
                                from_p = ps.get(e.get("from_id", ""), {});
                                to_p = ps.get(e.get("to_id", ""), {});
                                if not from_p or not to_p {
                                    return <g></g>;
                                }
                                fx = from_p.get("x", 0);
                                fy = from_p.get("y", 0);
                                tx = to_p.get("x", 0);
                                ty = to_p.get("y", 0);
                                # Bezier control points for smooth curves
                                mid_y = (fy + ty) / 2;
                                ec = get_edge_color(e.get("type", ""));
                                ed = get_edge_dash(e.get("type", ""));
                                w = max(1.5, e.get("weight", 0.5) * 4);
                                return <g>
                                    <path
                                        d={f"M {fx} {fy} C {fx} {mid_y}, {tx} {mid_y}, {tx} {ty}"}
                                        stroke={ec}
                                        strokeWidth={w}
                                        fill="none"
                                        strokeDasharray={ed if ed != "none" else ""}
                                        opacity="0.6"
                                        markerEnd="url(#arrowhead)" />
                                    <text
                                        x={(fx + tx) / 2 + 8}
                                        y={mid_y - 4}
                                        fontSize="10"
                                        fill={ec}
                                        opacity="0.8">
                                        {e.get("type", "")}
                                    </text>
                                </g>;
                            })(edge, positions) }
                        </g>
                        for (i, edge) in enumerate(graph_edges)
                    ] }

                    { [
                        <g key={f"node-{i}"}
                           onClick={lambda e: any -> None {
                               handle_node_click(node.get("id", ""));
                           }}
                           onDoubleClick={lambda e: any -> None {
                               handle_zoom_to_node(node.get("id", ""));
                           }}
                           onMouseEnter={lambda e: any -> None {
                               hovered_node_id = node.get("id", "");
                           }}
                           onMouseLeave={lambda e: any -> None {
                               hovered_node_id = "";
                           }}
                           className="gv-node"
                           transform={
                               f"translate({positions.get(node.get('id', ''), {}).get('x', 0) - 90},"
                               f"{positions.get(node.get('id', ''), {}).get('y', 0) - 30})"
                           }>
                            <rect
                                className="gv-node-rect"
                                width="180" height="60"
                                rx="12" ry="12"
                                fill="white"
                                stroke={
                                    "#6366f1" if node.get("id") == selected_node_id
                                    else get_status_color(node.get("status", ""))
                                }
                                strokeWidth={
                                    "3" if node.get("id") == selected_node_id else "2"
                                }
                                style={{
                                    "filter": "drop-shadow(0 2px 4px rgba(0,0,0,0.08))"
                                             if node.get("id") != hovered_node_id
                                             else "drop-shadow(0 4px 8px rgba(0,0,0,0.15))"
                                }} />

                            <rect
                                width="180" height="20"
                                rx="12" ry="12"
                                fill={get_node_color(node.get("type", ""))} />
                            <rect
                                y="10" width="180" height="10"
                                fill={get_node_color(node.get("type", ""))} />

                            <text x="10" y="14" fontSize="10" fill="white"
                                  fontWeight="600" fontFamily="system-ui">
                                {node.get("type", "").upper()}
                            </text>

                            <text x="155" y="14" fontSize="9" fill="white"
                                  fontWeight="500" textAnchor="end" fontFamily="system-ui">
                                {f"{int(node.get('nodeScore', 50))}"}
                            </text>
                            <text x="10" y="38" fontSize="11" fill="#1e293b"
                                  fontFamily="system-ui">
                                { node.get("text", "")[:28] }
                            </text>
                            <text x="10" y="52" fontSize="11" fill="#1e293b"
                                  fontFamily="system-ui">
                                { node.get("text", "")[28:56] + ("..." if len(node.get("text", "")) > 56 else "") }
                            </text>

                            { node.get("issues", []) and
                                <g>
                                    <circle cx="170" cy="50" r="8" fill="#ef4444" />
                                    <text x="170" y="54" fontSize="10" fill="white"
                                          textAnchor="middle" fontWeight="700">
                                        !
                                    </text>
                                </g>
                            }
                        </g>
                        for (i, node) in enumerate(graph_nodes)
                    ] }

                    <defs>
                        <marker id="arrowhead" markerWidth="8" markerHeight="6"
                                refX="8" refY="3" orient="auto">
                            <path d="M 0 0 L 8 3 L 0 6 Z" fill="#9ca3af" />
                        </marker>
                    </defs>

                </g>
            </svg>

            <div className="gv-legend">
                <span><span className="gv-legend-dot-thesis">●</span> Thesis</span>
                <span><span className="gv-legend-dot-claim">●</span> Claim</span>
                <span><span className="gv-legend-dot-evidence">●</span> Evidence</span>
                <span><span className="gv-legend-dot-assumption">●</span> Assumption</span>
                <span><span className="gv-legend-dot-counter">●</span> Counter</span>
            </div>

            <div className="gv-hint">
                Click: select · Double-click: zoom to branch · Scroll: zoom · Drag: pan
            </div>
        </div>;
}

}