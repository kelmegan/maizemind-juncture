"""Argument node — SVG-native with colored header, strength badge, and status indicators."""

def:pub ArgumentNodeComponent(props: any) -> JsxElement {
    node_data = props.node if props.node else {};
    isSelected = props.isSelected if props.isSelected else False;
    isDimmed = props.isDimmed if props.isDimmed else False;
    isGhost = props.isGhost if props.isGhost else False;

    nodeTypeConfig = {
        "THESIS":           {"fill": "#ede9fe", "stroke": "#7c3aed", "header": "#7c3aed", "text": "#5b21b6", "ht": "#fff", "label": "THESIS"},
        "CLAIM":            {"fill": "#e8e0fc", "stroke": "#9f7aea", "header": "#9f7aea", "text": "#6d28d9", "ht": "#fff", "label": "CLAIM"},
        "EVIDENCE":         {"fill": "#d1fae5", "stroke": "#10b981", "header": "#10b981", "text": "#065f46", "ht": "#fff", "label": "EVIDENCE"},
        "ASSUMPTION":       {"fill": "#fef3c7", "stroke": "#f59e0b", "header": "#f59e0b", "text": "#92400e", "ht": "#fff", "label": "ASSUMPTION"},
        "COUNTERARGUMENT":  {"fill": "#fee2e2", "stroke": "#ef4444", "header": "#ef4444", "text": "#991b1b", "ht": "#fff", "label": "COUNTER"}
    };

    # Evidence category short labels
    categoryLabels = {
        "empirical_data": "EMPIRICAL",
        "expert_testimony": "EXPERT",
        "anecdotal": "ANECDOTAL",
        "logical_reasoning": "LOGICAL",
        "analogy": "ANALOGY"
    };

    node_type = node_data["type"] if "type" in node_data else "CLAIM";
    node_content = node_data["content"] if "content" in node_data else "";
    node_issues = node_data["issues"] if "issues" in node_data else [];
    is_weak = node_data["isWeak"] if "isWeak" in node_data else False;
    has_issues = is_weak or len(node_issues) > 0;
    confidence = node_data["confidence"] if "confidence" in node_data else 0.5;

    config = nodeTypeConfig[node_type] if node_type in nodeTypeConfig else nodeTypeConfig["CLAIM"];

    # Evidence category info
    ev_category = node_data["evidence_category"] if "evidence_category" in node_data else "";
    ev_cat_label = categoryLabels[ev_category] if ev_category in categoryLabels else "";
    node_assumptions = node_data["assumptions"] if "assumptions" in node_data else [];
    has_assumptions = len(node_assumptions) > 0;

    # Pre-compute header label
    base_label = ev_cat_label if ev_cat_label else config["label"];
    header_label = "SUGGESTED" if isGhost else base_label;

    # Colors from config
    fill_color = config["fill"];
    stroke_color = config["stroke"];
    header_color = config["header"];
    text_color = config["text"];
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
    base_opacity = "0.5" if isGhost else "1";
    opacity_val = "0.15" if isDimmed else base_opacity;

    sel_stroke = stroke_color;
    sel_width = "3" if isSelected else "1.5";
    stroke_dash = "6,3" if isGhost else "none";

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
                rx="14" fill={fill_color} stroke={sel_stroke} strokeWidth={sel_width}
                strokeDasharray={stroke_dash} />

            <rect x={str(-w/2)} y={str(-h/2)} width={str(w)} height="26"
                rx="14" fill={header_color} />
            <rect x={str(-w/2)} y={str(-h/2 + 16)} width={str(w)} height="10"
                fill={header_color} />

            <text x={str(-w/2 + 12)} y={str(-h/2 + 17)} fontSize="9.5" fontWeight="600"
                letterSpacing="0.8" fill={ht_color} fontFamily="DM Sans, sans-serif">
                {header_label}
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

            {(
                <circle cx={str(w/2 - 30)} cy={str(h/2 - 14)} r="5" fill="#f59e0b" opacity="0.8" />
            ) if has_assumptions else None}

            {(
                <g>
                    <circle cx="0" cy={str(h/2 + 10)} r="10" fill="#ef4444" opacity="0.8" />
                    <text x="0" y={str(h/2 + 14)} fontSize="13" fill="#fff"
                        textAnchor="middle" fontWeight="700">+</text>
                </g>
            ) if isGhost else None}
        </g>
    );
}
