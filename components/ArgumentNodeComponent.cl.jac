"""Argument node component for graph visualization."""

def:pub ArgumentNodeComponent(props: any) -> JsxElement {
    node_data = props.node if props.node else {};
    className = props.className if props.className else "";

    nodeColorClasses = {
        "THESIS":           "node-card-thesis",
        "CLAIM":            "node-card-claim",
        "EVIDENCE":         "node-card-evidence",
        "ASSUMPTION":       "node-card-assumption",
        "COUNTERARGUMENT":  "node-card-counterargument"
    };

    nodeIcons = {
        "THESIS":           "🎯",
        "CLAIM":            "💭",
        "EVIDENCE":         "📊",
        "ASSUMPTION":       "🔗",
        "COUNTERARGUMENT":  "⚠️"
    };

    node_type = node_data["type"] if "type" in node_data else "CLAIM";
    node_content = node_data["content"] if "content" in node_data else "";
    node_issues = node_data["issues"] if "issues" in node_data else [];
    is_weak = node_data["isWeak"] if "isWeak" in node_data else False;
    has_issues = is_weak or len(node_issues) > 0;

    type_class = nodeColorClasses[node_type] if node_type in nodeColorClasses else "node-card-default";
    icon = nodeIcons[node_type] if node_type in nodeIcons else "💭";
    issue_class = "node-card-has-issues " if has_issues else "";

    return (
        <div className={"node-card " + type_class + " " + issue_class + className}>
            <div className="node-card-body">
                <div className="node-card-header">
                    <span className="node-card-type-label">
                        {icon} {node_type}
                    </span>
                </div>

                <p className="node-card-content">{node_content}</p>

                {(
                    <div className="node-card-issues-count">
                        {len(node_issues)} issue{"s" if len(node_issues) > 1 else ""} found
                    </div>
                ) if len(node_issues) > 0 else None}
            </div>
        </div>
    );
}
