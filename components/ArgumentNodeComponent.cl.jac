"""Argument node component — mockup-style with colored header band and status indicators."""

def:pub ArgumentNodeComponent(props: any) -> JsxElement {
    node_data = props.node if props.node else {};

    nodeTypeConfig = {
        "THESIS":           {"color": "#8b5cf6", "bg": "rgba(139,92,246,0.12)", "label": "THESIS"},
        "CLAIM":            {"color": "#3b82f6", "bg": "rgba(59,130,246,0.12)", "label": "CLAIM"},
        "EVIDENCE":         {"color": "#10b981", "bg": "rgba(16,185,129,0.12)", "label": "EVIDENCE"},
        "ASSUMPTION":       {"color": "#f59e0b", "bg": "rgba(245,158,11,0.12)", "label": "ASSUMPTION"},
        "COUNTERARGUMENT":  {"color": "#ef4444", "bg": "rgba(239,68,68,0.12)", "label": "COUNTER"}
    };

    node_type = node_data["type"] if "type" in node_data else "CLAIM";
    node_content = node_data["content"] if "content" in node_data else "";
    node_issues = node_data["issues"] if "issues" in node_data else [];
    is_weak = node_data["isWeak"] if "isWeak" in node_data else False;
    has_issues = is_weak or len(node_issues) > 0;
    status_ok = not has_issues;

    config = nodeTypeConfig[node_type] if node_type in nodeTypeConfig else {"color": "#3b82f6", "bg": "rgba(59,130,246,0.12)", "label": "CLAIM"};

    border_color = "#ef4444" if has_issues else ("#10b981" if status_ok else "#e5e7eb");

    return (
        <div style={{
            "width": "220px",
            "background": "#fff",
            "borderRadius": "12px",
            "border": f"1.5px solid {border_color}",
            "boxShadow": "0 2px 8px rgba(0,0,0,0.08)",
            "overflow": "hidden",
            "fontFamily": "'DM Sans', system-ui, sans-serif",
            "position": "relative"
        }}>
            <div style={{
                "background": config["bg"],
                "padding": "8px 14px",
                "display": "flex",
                "alignItems": "center",
                "justifyContent": "space-between"
            }}>
                <span style={{
                    "fontSize": "10px",
                    "fontWeight": "700",
                    "letterSpacing": "1px",
                    "textTransform": "uppercase",
                    "color": config["color"]
                }}>{config["label"]}</span>

                {(
                    <span style={{
                        "width": "16px",
                        "height": "16px",
                        "borderRadius": "50%",
                        "background": "#ef4444",
                        "color": "#fff",
                        "fontSize": "10px",
                        "fontWeight": "700",
                        "display": "flex",
                        "alignItems": "center",
                        "justifyContent": "center"
                    }}>!</span>
                ) if has_issues else None}
            </div>

            <div style={{"padding": "10px 14px 12px"}}>
                <p style={{
                    "margin": "0",
                    "fontSize": "12px",
                    "fontWeight": "500",
                    "color": "#1f2937",
                    "lineHeight": "1.5",
                    "display": "-webkit-box",
                    "WebkitLineClamp": "3",
                    "WebkitBoxOrient": "vertical",
                    "overflow": "hidden"
                }}>{node_content}</p>
            </div>

            {(
                <div style={{
                    "position": "absolute",
                    "bottom": "8px",
                    "right": "10px",
                    "width": "18px",
                    "height": "18px",
                    "borderRadius": "50%",
                    "background": "#10b981",
                    "color": "#fff",
                    "fontSize": "12px",
                    "display": "flex",
                    "alignItems": "center",
                    "justifyContent": "center"
                }}>&#10003;</div>
            ) if status_ok else None}
        </div>
    );
}
