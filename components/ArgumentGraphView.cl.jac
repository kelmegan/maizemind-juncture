"""SVG argument graph: draggable nodes, pan, zoom, lock, collision nudging."""

import from .ArgumentNodeComponent { ArgumentNodeComponent }


def:pub ArgumentGraphView(props: any) -> JsxElement {
    nodes       = list(props.nodes) if props.nodes else [];
    edges       = list(props.edges) if props.edges else [];
    onNodeClick = props.onNodeClick if props.onNodeClick else None;

    NODE_W   = 220;
    NODE_H   = 130;
    NODE_PAD = 18;

    has nodePositions: dict    = {},
        draggingNodeId: str    = None,
        dragDidMove: bool      = False,
        nodeDragOffsetX: float = 0.0,
        nodeDragOffsetY: float = 0.0,
        isPanning: bool        = False,
        panStartX: float       = 0.0,
        panStartY: float       = 0.0,
        viewX: float           = 0.0,
        viewY: float           = 0.0,
        scale: float           = 1.0,
        isLocked: bool         = False,
        viewportW: float       = 0.0,
        viewportH: float       = 0.0;

    can with entry {
        init = {};
        for n in nodes {
            init[n["id"]] = {
                "x": n["position"]["x"],
                "y": n["position"]["y"]
            };
        }
        nodePositions = init;

        # center the camera
        canvas = document.querySelector("[data-graph-canvas]");
        if canvas {
            rect = canvas.getBoundingClientRect();
            viewportW = rect.width;
            viewportH = rect.height;

            viewX = viewportW / 2.0;
            viewY = viewportH / 2.0;
        }
    }

    def getPos(nid: str) -> dict {
        if nid in nodePositions { return nodePositions[nid]; }
        for n in nodes { if n["id"] == nid { return n["position"]; } }
        return {"x": 0, "y": 0};
    }

    def midX(nid: str) -> float { return getPos(nid)["x"] + NODE_W / 2.0; }
    def midY(nid: str) -> float { return getPos(nid)["y"] + NODE_H / 2.0; }

    def edgeColor(t: str) -> str {
        colors = {"SUPPORTS": "#10b981", "CONTRADICTS": "#ef4444", "DEPENDS_ON": "#f59e0b", "ADDRESSES": "#8b5cf6"};
        return colors[t] if t in colors else "#6b7280";
    }

    def edgeDash(t: str) -> str {
        return "8,4" if t == "CONTRADICTS" else ("4,4" if t == "DEPENDS_ON" else "none");
    }

    def makePath(sx: float, sy: float, tx: float, ty: float) -> str {
        dy = ty - sy;
        return f"M {sx} {sy} C {sx} {sy + dy*0.5}, {tx} {ty - dy*0.5}, {tx} {ty}";
    }

    def resolveCollisions(positions: dict, draggedId: str) -> dict {
        # Deep-copy so we don't mutate the input
        result = {};
        for n in nodes {
            nid = n["id"];
            pos = positions[nid];
            result[nid] = {"x": pos["x"], "y": pos["y"]};
        }

        all_ids = list(result);

        # Multiple passes let chain reactions propagate (A bumps B, B bumps C)
        passes = 4;
        for _ in range(passes) {
            for aid in all_ids {
                for bid in all_ids {
                    if aid == bid { continue; }

                    # The dragged card is immovable — only nudge stationary cards
                    if aid == draggedId or bid == draggedId {
                        # Exactly one of the pair is the dragged card; let the
                        # OTHER one be the one that gets pushed.
                        mover   = bid if aid == draggedId else aid;
                        anchor  = draggedId;
                        a_pos   = result[anchor];
                        m_pos   = result[mover];

                        dx = m_pos["x"] - a_pos["x"];
                        dy = m_pos["y"] - a_pos["y"];
                        overlap_x = (NODE_W + NODE_PAD) - abs(dx);
                        overlap_y = (NODE_H + NODE_PAD) - abs(dy);

                        if overlap_x > 0 and overlap_y > 0 {
                            if overlap_x <= overlap_y {
                                push = overlap_x if dx >= 0 else -overlap_x;
                                result[mover] = {"x": m_pos["x"] + push, "y": m_pos["y"]};
                            } else {
                                push = overlap_y if dy >= 0 else -overlap_y;
                                result[mover] = {"x": m_pos["x"], "y": m_pos["y"] + push};
                            }
                        }
                    } else {
                        # Two non-dragged cards: let them push each other symmetrically
                        a_pos = result[aid];
                        b_pos = result[bid];

                        dx = b_pos["x"] - a_pos["x"];
                        dy = b_pos["y"] - a_pos["y"];
                        overlap_x = (NODE_W + NODE_PAD) - abs(dx);
                        overlap_y = (NODE_H + NODE_PAD) - abs(dy);

                        if overlap_x > 0 and overlap_y > 0 {
                            if overlap_x <= overlap_y {
                                half = overlap_x / 2.0;
                                push = half if dx >= 0 else -half;
                                result[aid] = {"x": a_pos["x"] - push, "y": a_pos["y"]};
                                result[bid] = {"x": b_pos["x"] + push, "y": b_pos["y"]};
                            } else {
                                half = overlap_y / 2.0;
                                push = half if dy >= 0 else -half;
                                result[aid] = {"x": a_pos["x"], "y": a_pos["y"] - push};
                                result[bid] = {"x": b_pos["x"], "y": b_pos["y"] + push};
                            }
                        }
                    }
                }
            }
        }

        # Clamp all cards to the positive canvas region
        for k in all_ids {
            result[k] = {
                "x": max(0.0, result[k]["x"]),
                "y": max(0.0, result[k]["y"])
            };
        }

        return result;
    }

    def handleWheel(e: any) -> None {
        if isLocked { return; }
        e.preventDefault();
        new_scale = max(0.25, min(3.0, scale - e.deltaY * 0.001));
        scale = new_scale;
    }

    def zoomIn()     -> None { scale = min(3.0, scale + 0.15); }
    def zoomOut()    -> None { scale = max(0.25, scale - 0.15); }
    def resetView()  -> None { scale = 1.0; viewX = viewportW / 2.0; viewY = viewportH / 2.0; }
    def toggleLock() -> None { isLocked = not isLocked; }

    def handleCanvasMouseDown(e: any) -> None {
    if isLocked { return; }
    if draggingNodeId { return; }
    isPanning = True;
    panStartX = e.clientX - viewX;
    panStartY = e.clientY - viewY;
}

    def handleNodeMouseDown(e: any, nodeId: str) -> None {
        if isLocked { return; }
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
        if isLocked { return; }

        if draggingNodeId {
            rect  = e.currentTarget.getBoundingClientRect();

            new_x = max(0.0, (e.clientX - rect.left - viewX) / scale - nodeDragOffsetX);
            new_y = max(0.0, (e.clientY - rect.top  - viewY) / scale - nodeDragOffsetY);

            # Ensure node exists in position table
            if draggingNodeId not in nodePositions {
                nodePositions[draggingNodeId] = {"x": new_x, "y": new_y};
            }

            # Update dragged node directly
            nodePositions[draggingNodeId] = {
                "x": new_x,
                "y": new_y
            };

            # Resolve collisions against current state
            nodePositions = resolveCollisions(nodePositions, draggingNodeId);

            dragDidMove = True;
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

    # ── edges ──────────────────────────────────────────────────────────────
    edge_elements = [];
    for edge in edges {
        sx = midX(edge["source"]); sy = midY(edge["source"]);
        tx = midX(edge["target"]); ty = midY(edge["target"]);
        mx = (sx + tx) / 2.0;     my = (sy + ty) / 2.0;
        color  = edgeColor(edge["type"]);
        dash   = edgeDash(edge["type"]);
        path_d = makePath(sx, sy, tx, ty);
        mkr_id = "mk-" + edge["type"].toLowerCase();
        edge_elements.append(
            <g key={edge["id"]}>
                <path d={path_d} stroke={color} strokeWidth="2"
                      strokeDasharray={dash} fill="none"
                      markerEnd={f"url(#{mkr_id})"} />
                <rect x={mx-32} y={my-10} width="64" height="18" rx="4"
                      fill="white" fillOpacity="0.92" />
                <text x={mx} y={my+4} textAnchor="middle" fontSize="9"
                      fontWeight="600" fill={color}
                      fontFamily="DM Sans, sans-serif">{edge["type"]}</text>
            </g>
        );
    }

    # ── nodes ──────────────────────────────────────────────────────────────
    node_elements = [];
    for node_item in nodes {
        pos         = getPos(node_item["id"]);
        is_dragging = draggingNodeId == node_item["id"];
        drop_shadow = "drop-shadow(0 8px 20px rgba(0,0,0,0.22))" if is_dragging else "drop-shadow(0 2px 6px rgba(0,0,0,0.08))";
        node_cursor = "grabbing" if is_dragging else ("default" if isLocked else "grab");
        node_elements.append(
            <foreignObject
                key={node_item["id"]}
                x={pos["x"]} y={pos["y"]}
                width={NODE_W} height={NODE_H}
                style={{"cursor": node_cursor, "filter": drop_shadow, "overflow": "visible"}}
                onMouseDown={lambda e -> None { handleNodeMouseDown(e, node_item["id"]); }}
                onClick={lambda -> None {
                    if onNodeClick and not dragDidMove { onNodeClick(node_item); }
                }}
            >
                <div xmlns="http://www.w3.org/1999/xhtml">
                    <ArgumentNodeComponent node={node_item} />
                </div>
            </foreignObject>
        );
    }

    lock_class = "graph-control-btn graph-control-btn-active" if isLocked else "graph-control-btn";

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
                style={{
                    "position":        "absolute",
                    "top":             "0",
                    "left":            "0",
                    "width":           "100%",
                    "height":          "100%",
                    "overflow":        "visible"
                }}
            >
                <defs>
                    <marker id="mk-supports"    markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#10b981" /></marker>
                    <marker id="mk-contradicts" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#ef4444" /></marker>
                    <marker id="mk-depends_on"  markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#f59e0b" /></marker>
                    <marker id="mk-addresses"   markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#8b5cf6" /></marker>
                    <marker id="mk-default"     markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#6b7280" /></marker>
                </defs>
                <g transform={f"translate({viewX}, {viewY}) scale({scale})"}>
                    {edge_elements}
                    {node_elements}
                </g>
            </svg>

            <div className="graph-controls">
                <button className="graph-control-btn" onClick={zoomIn}    title="Zoom in">+</button>
                <button className="graph-control-btn" onClick={zoomOut}   title="Zoom out">−</button>
                <button className="graph-control-btn" onClick={resetView} title="Reset view">⊙</button>
                <button className={lock_class}         onClick={toggleLock}
                        title={"Unlock view" if isLocked else "Lock view"}>
                    {"🔒" if isLocked else "🔓"}
                </button>
            </div>
        </div>
    );
}