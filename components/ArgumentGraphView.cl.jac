"""SVG-based argument graph visualization component."""

import from .ArgumentNodeComponent { ArgumentNodeComponent }


def:pub ArgumentGraphView(props: any) -> JsxElement {
    nodes = list(props.nodes) if props.nodes else [];
    edges = list(props.edges) if props.edges else [];
    onNodeClick = props.onNodeClick if props.onNodeClick else None;

    def getEdgeColor(edgeType: str) -> str {
        if edgeType == "SUPPORTS" { return "#10b981"; }
        elif edgeType == "CONTRADICTS" { return "#ef4444"; }
        elif edgeType == "DEPENDS_ON" { return "#f59e0b"; }
        elif edgeType == "ADDRESSES" { return "#8b5cf6"; }
        else { return "#6b7280"; }
    }

    def getEdgeDash(edgeType: str) -> str {
        if edgeType == "CONTRADICTS" { return "8,4"; }
        elif edgeType == "DEPENDS_ON" { return "4,4"; }
        else { return "none"; }
    }

    node_width = 220;
    node_height = 110;

    node_map = {};
    for node_item in nodes {
        node_map[node_item["id"]] = node_item;
    }

    def getMidX(nodeId: str) -> int {
        n = node_map[nodeId] if nodeId in node_map else None;
        if not n { return 0; }
        return n["position"]["x"] + node_width / 2;
    }

    def getMidY(nodeId: str) -> int {
        n = node_map[nodeId] if nodeId in node_map else None;
        if not n { return 0; }
        return n["position"]["y"] + node_height / 2;
    }

    max_x = 600;
    max_y = 400;
    for node_item in nodes {
        nx = node_item["position"]["x"] + node_width + 40;
        ny = node_item["position"]["y"] + node_height + 40;
        if nx > max_x { max_x = nx; }
        if ny > max_y { max_y = ny; }
    }

    edge_elements = [];
    for edge in edges {
        sx = getMidX(edge["source"]);
        sy = getMidY(edge["source"]);
        tx = getMidX(edge["target"]);
        ty = getMidY(edge["target"]);
        mx = (sx + tx) / 2;
        my = (sy + ty) / 2;
        color = getEdgeColor(edge["type"]);
        dash = getEdgeDash(edge["type"]);
        marker = "url(#arrowhead-supports)" if edge["type"] == "SUPPORTS" else "url(#arrowhead-contradicts)" if edge["type"] == "CONTRADICTS" else "url(#arrowhead-default)";
        edge_elements.append(
            <g key={edge["id"]}>
                <line x1={sx} y1={sy} x2={tx} y2={ty} stroke={color} strokeWidth="2" strokeDasharray={dash} markerEnd={marker} />
                <rect x={mx - 28} y={my - 10} width="56" height="18" rx="4" fill="white" fillOpacity="0.9" />
                <text x={mx} y={my + 4} textAnchor="middle" fontSize="9" fontWeight="600" fill={color}>{edge["type"]}</text>
            </g>
        );
    }

    node_elements = [];
    for node_item in nodes {
        nx = node_item["position"]["x"];
        ny = node_item["position"]["y"];
        node_elements.append(
            <foreignObject key={node_item["id"]} x={nx} y={ny} width={node_width} height={node_height}>
                <div xmlns="http://www.w3.org/1999/xhtml">
                    <ArgumentNodeComponent
                        node={node_item}
                        onClick={lambda -> None { onNodeClick(node_item) if onNodeClick else None; }}
                    />
                </div>
            </foreignObject>
        );
    }

    return (
        <div className="w-full h-full overflow-auto bg-gray-50 rounded-lg border">
            <svg width={max_x} height={max_y} xmlns="http://www.w3.org/2000/svg">
                <defs>
                    <marker id="arrowhead-supports" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto">
                        <polygon points="0 0, 10 3.5, 0 7" fill="#10b981" />
                    </marker>
                    <marker id="arrowhead-contradicts" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto">
                        <polygon points="0 0, 10 3.5, 0 7" fill="#ef4444" />
                    </marker>
                    <marker id="arrowhead-default" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto">
                        <polygon points="0 0, 10 3.5, 0 7" fill="#6b7280" />
                    </marker>
                </defs>
                {edge_elements}
                {node_elements}
            </svg>
        </div>
    );
}