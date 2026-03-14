"""Argument node — SVG-native with colored header, strength badge, and status indicators."""

def:pub ArgumentNodeComponent(props: any) -> JsxElement {
    node_data = props.node if props.node else {};
    isSelected = props.isSelected if props.isSelected else False;
    isDimmed = props.isDimmed if props.isDimmed else False;
    isDark = props.isDark if props.isDark else False;

    nodeTypeConfig = {
        "THESIS":           {"fill": "#ede9fe", "stroke": "#7c3aed", "header": "#7c3aed", "text": "#5b21b6", "ht": "#fff", "label": "THESIS",
                             "dfill": "#1e1636", "dstroke": "#a78bfa", "dheader": "#7c3aed", "dtext": "#c4b5fd"},
        "CLAIM":            {"fill": "#e8e0fc", "stroke": "#9f7aea", "header": "#9f7aea", "text": "#6d28d9", "ht": "#fff", "label": "CLAIM",
                             "dfill": "#1c1430", "dstroke": "#b794f4", "dheader": "#9f7aea", "dtext": "#d6bcfa"},
        "EVIDENCE":         {"fill": "#d1fae5", "stroke": "#10b981", "header": "#10b981", "text": "#065f46", "ht": "#fff", "label": "EVIDENCE",
                             "dfill": "#0d2818", "dstroke": "#6ee7b7", "dheader": "#10b981", "dtext": "#a7f3d0"},
        "ASSUMPTION":       {"fill": "#fef3c7", "stroke": "#f59e0b", "header": "#f59e0b", "text": "#92400e", "ht": "#fff", "label": "ASSUMPTION",
                             "dfill": "#2a2008", "dstroke": "#fcd34d", "dheader": "#f59e0b", "dtext": "#fde68a"},
        "COUNTERARGUMENT":  {"fill": "#fee2e2", "stroke": "#ef4444", "header": "#ef4444", "text": "#991b1b", "ht": "#fff", "label": "COUNTER",
                             "dfill": "#2a1215", "dstroke": "#f87171", "dheader": "#ef4444", "dtext": "#fca5a5"}
    };

    node_type = node_data["type"] if "type" in node_data else "CLAIM";
    node_content = node_data["content"] if "content" in node_data else "";
    node_issues = node_data["issues"] if "issues" in node_data else [];
    is_weak = node_data["isWeak"] if "isWeak" in node_data else False;
    has_issues = is_weak or len(node_issues) > 0;
    confidence = node_data["confidence"] if "confidence" in node_data else 0.5;

    config = nodeTypeConfig[node_type] if node_type in nodeTypeConfig else nodeTypeConfig["CLAIM"];

    # Colors based on theme
    fill_color = config["dfill"] if isDark else config["fill"];
    stroke_color = config["dstroke"] if isDark else config["stroke"];
    header_color = config["dheader"] if isDark else config["header"];
    text_color = config["dtext"] if isDark else config["text"];
    ht_color = config["ht"];

    # Strength color
    conf_val = confidence if confidence else 0.5;
    str_color = "#16a34a" if conf_val >= 0.7 else ("#ca8a04" if conf_val >= 0.5 else "#dc2626");

    # Wrap text into lines
    max_chars = 26;
    lines: list = [];
    if len(node_content) <= max_chars {
        lines = [node_content];
    } else {
        words = node_content.split(" ");
        cur = "";
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
        lines = lines[:3];
    }

    w = 200;
    h = max(70, 32 + len(lines) * 17 + 12);
    opacity_val = "0.15" if isDimmed else "1";

    sel_stroke = stroke_color;
    sel_width = "3" if isSelected else "1.5";

    # Build text line elements in a loop (avoids two-param lambda)
    line_elements = [];
    line_idx = 0;
    for line_text in lines {
        y_pos = -h/2 + 34 + line_idx * 17 + 12;
        line_elements.append(
            <text key={str(line_idx)} x="0" y={str(y_pos)}
                fontSize="11.5" fontWeight="500" textAnchor="middle"
                fill={text_color} fontFamily="DM Sans, sans-serif">
                {line_text}
            </text>
        );
        line_idx = line_idx + 1;
    }

    return (
        <g opacity={opacity_val}>
            {(
                <rect x={str(-w/2 - 4)} y={str(-h/2 - 4)} width={str(w + 8)} height={str(h + 8)}
                    rx="18" fill="none" stroke={stroke_color} strokeWidth="2" opacity="0.4" />
            ) if isSelected else None}

            <rect x={str(-w/2)} y={str(-h/2)} width={str(w)} height={str(h)}
                rx="14" fill={fill_color} stroke={sel_stroke} strokeWidth={sel_width} />

            <rect x={str(-w/2)} y={str(-h/2)} width={str(w)} height="26"
                rx="14" fill={header_color} />
            <rect x={str(-w/2)} y={str(-h/2 + 16)} width={str(w)} height="10"
                fill={header_color} />

            <text x={str(-w/2 + 12)} y={str(-h/2 + 17)} fontSize="9.5" fontWeight="600"
                letterSpacing="0.8" fill={ht_color} fontFamily="DM Sans, sans-serif">
                {config["label"]}
            </text>

            <rect x={str(w/2 - 38)} y={str(-h/2 + 4)} width="32" height="18"
                rx="9" fill={str_color} />
            <text x={str(w/2 - 22)} y={str(-h/2 + 16)} fontSize="9.5" fontWeight="600"
                textAnchor="middle" fill="#fff" fontFamily="DM Sans, sans-serif">
                {str(int(conf_val * 100))}
            </text>

            {line_elements}

            {(
                <g>
                    <circle cx={str(w/2 - 14)} cy={str(h/2 - 14)} r="7" fill="#ef4444" />
                    <text x={str(w/2 - 14)} y={str(h/2 - 10)} fontSize="9" fill="#fff"
                        textAnchor="middle" fontWeight="700">!</text>
                </g>
            ) if has_issues else None}
        </g>
    );
}
