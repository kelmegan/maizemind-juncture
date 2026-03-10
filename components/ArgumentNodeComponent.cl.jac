"""Argument node component for graph visualization."""

import from "lucide-react" { AlertCircle, CheckCircle2 }


def:pub ArgumentNodeComponent(props: any) -> JsxElement {
    node_data = props.node if props.node else {};
    className = props.className if props.className else "";

    nodeColors = {
        "THESIS": "bg-purple-100 border-purple-400",
        "CLAIM": "bg-blue-100 border-blue-400",
        "EVIDENCE": "bg-green-100 border-green-400",
        "ASSUMPTION": "bg-yellow-100 border-yellow-400",
        "COUNTERARGUMENT": "bg-red-100 border-red-400"
    };

    nodeIcons = {
        "THESIS": "🎯",
        "CLAIM": "💭",
        "EVIDENCE": "📊",
        "ASSUMPTION": "🔗",
        "COUNTERARGUMENT": "⚠️"
    };

    node_type = node_data["type"] if "type" in node_data else "CLAIM";
    node_content = node_data["content"] if "content" in node_data else "";
    node_issues = node_data["issues"] if "issues" in node_data else [];
    is_weak = node_data["isWeak"] if "isWeak" in node_data else False;
    has_issues = is_weak or len(node_issues) > 0;

    color_class = nodeColors[node_type] if node_type in nodeColors else "bg-gray-100 border-gray-400";
    icon = nodeIcons[node_type] if node_type in nodeIcons else "💭";
    issue_class = "ring-2 ring-red-400 animate-pulse " if has_issues else "";
    base_class = "border-2 rounded-lg p-3 cursor-pointer hover:shadow-lg transition-all min-w-[200px] max-w-[300px] ";

    return (
        <div className={base_class + color_class + " " + issue_class + className}>
            <div className="space-y-2">
                <div className="flex items-center justify-between gap-2">
                    <span className="text-xs font-semibold uppercase text-gray-600">
                        {icon} {node_type}
                    </span>
                    {(
                        <AlertCircle className="h-4 w-4 text-red-500" />
                    ) if has_issues else (
                        <CheckCircle2 className="h-4 w-4 text-green-500" />
                    )}
                </div>

                <p className="text-sm leading-tight text-gray-800">{node_content}</p>

                {(
                    <div className="text-xs text-red-600 font-medium">
                        {len(node_issues)} issue{"s" if len(node_issues) > 1 else ""} found
                    </div>
                ) if len(node_issues) > 0 else None}
            </div>
        </div>
    );
}