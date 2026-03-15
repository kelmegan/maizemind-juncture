"""Juncture - Review Screen with inline editing workshop, ghost nodes, and score delta."""

sv import from ...main { GetContext, GetGraphWithScoring, AddEvidenceToNode, AddAssumptionToEvidence, UpdateNodeContent, DeleteNode, AddCounterargumentNode, EvaluateNewNode }

import from ..components.ArgumentGraphView { ArgumentGraphView }
import from ..components.Button { Button }

def:pub ReviewScreen(props: any) -> JsxElement {
    navigate = props.navigate;
    screen_data = props.screenData if props.screenData else {};

    has currentGraph: dict = None,
        currentScore: dict = None,
        currentIssues: list = [],
        selectedNode: dict = None,
        isDark: bool = False,
        focusBranch: str = None,
        editMode: str = "",
        editInputValue: str = "",
        isSaving: bool = False,
        prevScore: int = 0,
        scoreDelta: int = 0,
        showScoreDelta: bool = False,
        showConfirmDelete: bool = False,
        suggestedCounterargs: list = [];

    async def loadContext() -> None {
        try {
            ctx = await root spawn GetContext();
            if ctx and ctx["currentGraph"] {
                graphObj = ctx["currentGraph"];
                graphId = graphObj["id"] if "id" in graphObj else "";
                if graphId {
                    result = await root spawn GetGraphWithScoring(graphId=graphId);
                    data = result.reports[0] if result.reports else {};
                    if "error" not in data {
                        currentGraph = data["graph"] if "graph" in data else None;
                        currentScore = data["score"] if "score" in data else None;
                        currentIssues = data["issues"] if "issues" in data else [];
                    }
                }
            }
        } except Exception {
            # Context not available
        }
    }

    has _didInit: bool = False;

    can with entry {
        if not _didInit {
            currentGraph = screen_data["graphData"] if "graphData" in screen_data else None;
            currentScore = screen_data["scoreData"] if "scoreData" in screen_data else None;
            currentIssues = screen_data["issuesData"] if "issuesData" in screen_data else [];
            suggestedCounterargs = screen_data["suggestedCounterarguments"] if "suggestedCounterarguments" in screen_data else [];
            _didInit = True;
            if not currentGraph { loadContext(); }
        }
    }

    def handleNodeClick(node_data: any) -> None {
        selectedNode = node_data;
        focusBranch = None;
        editMode = "";
        editInputValue = "";
        showConfirmDelete = False;
        showScoreDelta = False;
    }

    def closePanel() -> None {
        selectedNode = None;
        focusBranch = None;
        editMode = "";
        editInputValue = "";
        showConfirmDelete = False;
    }

    def toggleTheme() -> None {
        isDark = not isDark;
    }

    def toggleBranch() -> None {
        if selectedNode {
            if focusBranch == selectedNode["id"] {
                focusBranch = None;
            } else {
                focusBranch = selectedNode["id"];
            }
        }
    }

    def handleExport() -> None {
        navigate("export", {
            "graphData": currentGraph,
            "scoreData": currentScore,
            "issuesData": currentIssues
        });
    }

    def handleBack() -> None {
        navigate("generate");
    }

    def handleIssueClick(nodeId: str) -> None {
        if currentGraph {
            nodes_list = currentGraph["nodes"] if "nodes" in currentGraph else [];
            for n in nodes_list {
                if n["id"] == nodeId {
                    selectedNode = n;
                    editMode = "";
                    editInputValue = "";
                    showConfirmDelete = False;
                    break;
                }
            }
        }
    }

    # --- Inline edit handlers ---
    def startEdit(mode: str) -> None {
        showScoreDelta = False;
        showConfirmDelete = False;
        if mode == "delete" {
            editMode = "";
            showConfirmDelete = True;
            return;
        }
        editMode = mode;
        if mode == "clarify" {
            editInputValue = sel_content;
        } else {
            editInputValue = "";
        }
    }

    def cancelEdit() -> None {
        editMode = "";
        editInputValue = "";
        showConfirmDelete = False;
    }

    def handleEditInput(e: any) -> None {
        editInputValue = e.target.value;
    }

    async def saveEdit() -> None {
        if not editInputValue.trim() or not selectedNode or not currentGraph { return; }
        isSaving = True;
        prevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        graphId = currentGraph["id"] if "id" in currentGraph else "";
        nodeId = selectedNode["id"];
        saveSuccess = False;

        try {
            if editMode == "evidence" {
                await root spawn AddEvidenceToNode(
                    graphId=graphId, nodeId=nodeId, evidenceContent=editInputValue.trim()
                );
                saveSuccess = True;
            } elif editMode == "clarify" {
                await root spawn UpdateNodeContent(
                    graphId=graphId, nodeId=nodeId, newContent=editInputValue.trim()
                );
                saveSuccess = True;
            } elif editMode == "assumption" {
                await root spawn AddAssumptionToEvidence(
                    graphId=graphId, nodeId=nodeId, assumptionText=editInputValue.trim()
                );
                saveSuccess = True;
            } elif editMode == "counter" {
                await root spawn AddCounterargumentNode(
                    graphId=graphId, targetNodeId=nodeId, counterargContent=editInputValue.trim()
                );
                saveSuccess = True;
            }
        } except Exception {
            saveSuccess = False;
        }

        if saveSuccess {
            try {
                # Refresh graph data with updated scores
                result = await root spawn GetGraphWithScoring(graphId=graphId);
                data = result.reports[0] if result.reports else {};
                if "error" not in data {
                    currentGraph = data["graph"] if "graph" in data else currentGraph;
                    currentScore = data["score"] if "score" in data else currentScore;
                    currentIssues = data["issues"] if "issues" in data else currentIssues;

                    newOverall = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
                    scoreDelta = newOverall - prevScore;
                    showScoreDelta = True;

                    # Re-select same node from updated graph
                    updatedNodes = currentGraph["nodes"] if "nodes" in currentGraph else [];
                    foundNode = None;
                    for n in updatedNodes {
                        if n["id"] == nodeId {
                            foundNode = n;
                            break;
                        }
                    }
                    selectedNode = foundNode;
                }
            } except Exception {
                # refresh failed
            }
        }

        editMode = "";
        editInputValue = "";
        isSaving = False;
    }

    async def handleDelete() -> None {
        if not selectedNode or not currentGraph { return; }
        isSaving = True;
        prevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        graphId = currentGraph["id"] if "id" in currentGraph else "";

        try {
            await root spawn DeleteNode(graphId=graphId, nodeId=selectedNode["id"]);

            result = await root spawn GetGraphWithScoring(graphId=graphId);
            data = result.reports[0] if result.reports else {};
            if "error" not in data {
                currentGraph = data["graph"] if "graph" in data else currentGraph;
                currentScore = data["score"] if "score" in data else currentScore;
                currentIssues = data["issues"] if "issues" in data else currentIssues;

                newOverall = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
                scoreDelta = newOverall - prevScore;
                showScoreDelta = True;
            }
        } except Exception {
            # delete failed
        }

        selectedNode = None;
        showConfirmDelete = False;
        editMode = "";
        isSaving = False;
    }

    async def handleAcceptCounterarg(ca: dict) -> None {
        if not currentGraph { return; }
        ca_text = ca["text"] if "text" in ca else "";
        ca_target = ca["target_node"] if "target_node" in ca else "";
        if not ca_text or not ca_target { return; }

        # Optimistic: remove from suggestions BEFORE async calls
        # so the UI updates immediately and survives re-renders
        newSuggestions: list = [];
        _ci = 0;
        while _ci < len(suggestedCounterargs) {
            sc = suggestedCounterargs[_ci];
            sc_text = sc["text"] if "text" in sc else "";
            if sc_text != ca_text {
                newSuggestions.append(sc);
            }
            _ci = _ci + 1;
        }
        suggestedCounterargs = newSuggestions;

        isSaving = True;
        prevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        graphId = currentGraph["id"] if "id" in currentGraph else "";

        try {
            await root spawn AddCounterargumentNode(
                graphId=graphId, targetNodeId=ca_target, counterargContent=ca_text
            );

            result = await root spawn GetGraphWithScoring(graphId=graphId);
            data = result.reports[0] if result.reports else {};
            if "error" not in data {
                currentGraph = data["graph"] if "graph" in data else currentGraph;
                currentScore = data["score"] if "score" in data else currentScore;
                currentIssues = data["issues"] if "issues" in data else currentIssues;

                newOverall = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
                scoreDelta = newOverall - prevScore;
                showScoreDelta = True;
            }
        } except Exception {
            # accept failed
        }
        isSaving = False;
    }

    # --- Loading state ---
    if not currentGraph or not currentScore {
        return <div style={{
            "minHeight": "100vh", "display": "flex", "alignItems": "center",
            "justifyContent": "center", "fontFamily": "'DM Sans', system-ui, sans-serif",
            "color": "#64748b"
        }}><p>Loading argument map...</p></div>;
    }

    # --- Pre-compute all values before JSX ---

    overall = currentScore["overall"] if "overall" in currentScore else 0;
    scoreColor = "#16a34a" if overall >= 70 else ("#ca8a04" if overall >= 50 else "#dc2626");

    # Score delta display
    delta_text = "";
    delta_color = "#16a34a";
    if showScoreDelta and scoreDelta != 0 {
        delta_sign = "+" if scoreDelta > 0 else "";
        delta_text = f"({delta_sign}{scoreDelta})";
        delta_color = "#16a34a" if scoreDelta > 0 else "#dc2626";
    }

    # Theme colors
    bgColor = "#0f0f17" if isDark else "#f4f1ee";
    panelBg = "#13131f" if isDark else "#ffffff";
    borderColor = "rgba(255,255,255,0.07)" if isDark else "rgba(0,0,0,0.08)";
    textColor = "#f1f5f9" if isDark else "#1e293b";
    mutedColor = "#94a3b8" if isDark else "#475569";
    faintColor = "#64748b" if isDark else "#94a3b8";
    cardBg = "rgba(255,255,255,0.04)" if isDark else "rgba(0,0,0,0.03)";
    themeToggleText = "Light" if isDark else "Dark";
    exportBtnBg = "rgba(139,92,246,0.15)" if isDark else "rgba(139,92,246,0.1)";

    error_bg = "rgba(239,68,68,0.08)" if isDark else "rgba(239,68,68,0.06)";
    error_border = "1px solid rgba(239,68,68,0.15)" if isDark else "1px solid rgba(239,68,68,0.12)";
    error_text_color = "#fca5a5" if isDark else "#dc2626";
    success_bg = "rgba(34,197,94,0.08)" if isDark else "rgba(34,197,94,0.06)";
    success_border = "1px solid rgba(34,197,94,0.15)" if isDark else "1px solid rgba(34,197,94,0.12)";
    success_text_color = "#86efac" if isDark else "#16a34a";
    action_bg = "rgba(139,92,246,0.08)" if isDark else "rgba(139,92,246,0.06)";
    action_border = "1px solid rgba(139,92,246,0.2)" if isDark else "1px solid rgba(139,92,246,0.15)";
    action_text_color = "#c4b5fd" if isDark else "#7c3aed";
    bar_track_bg = "rgba(255,255,255,0.1)" if isDark else "#e5e7eb";

    support_val = currentScore["support"] if "support" in currentScore else 0;
    premise_val = currentScore["premise"] if "premise" in currentScore else 0;
    consistency_val = currentScore["consistency"] if "consistency" in currentScore else 0;
    support_bar_color = "#10b981" if support_val >= 70 else ("#f59e0b" if support_val >= 50 else "#ef4444");
    premise_bar_color = "#10b981" if premise_val >= 70 else ("#f59e0b" if premise_val >= 50 else "#ef4444");
    consistency_bar_color = "#10b981" if consistency_val >= 70 else ("#f59e0b" if consistency_val >= 50 else "#ef4444");

    typeLegend = [
        {"key": "THESIS", "color": "#7c3aed", "bg": "#ede9fe", "label": "Thesis"},
        {"key": "CLAIM", "color": "#9f7aea", "bg": "#e8e0fc", "label": "Claim"},
        {"key": "EVIDENCE", "color": "#10b981", "bg": "#d1fae5", "label": "Evidence"},
        {"key": "COUNTERARGUMENT", "color": "#ef4444", "bg": "#fee2e2", "label": "Counter"}
    ];

    # Selected node info
    sel_type = selectedNode["type"] if selectedNode and "type" in selectedNode else "CLAIM";
    sel_content = selectedNode["content"] if selectedNode and "content" in selectedNode else "";
    sel_confidence = selectedNode["confidence"] if selectedNode and "confidence" in selectedNode else 0.5;
    sel_conf_val = sel_confidence if sel_confidence else 0.5;
    sel_str_color = "#16a34a" if sel_conf_val >= 0.7 else ("#ca8a04" if sel_conf_val >= 0.5 else "#dc2626");
    sel_str_bg = "rgba(34,197,94,0.1)" if sel_conf_val >= 0.7 else ("rgba(250,204,21,0.15)" if sel_conf_val >= 0.5 else "rgba(239,68,68,0.1)");

    typeColorMap = {
        "THESIS": "#7c3aed", "CLAIM": "#9f7aea", "EVIDENCE": "#10b981",
        "COUNTERARGUMENT": "#ef4444"
    };
    sel_type_color = typeColorMap[sel_type] if sel_type in typeColorMap else "#9f7aea";

    sel_node_score = selectedNode["nodeScore"] if selectedNode and "nodeScore" in selectedNode else -1;
    sel_has_node_score = sel_node_score >= 0;

    # Evidence-specific data
    sel_is_evidence = sel_type == "EVIDENCE";
    sel_ev_category = "";
    sel_assumptions: list = [];
    sel_has_assumptions = False;
    if selectedNode {
        sel_ev_category = selectedNode["evidence_category"] if "evidence_category" in selectedNode else "";
        sel_assumptions = selectedNode["assumptions"] if "assumptions" in selectedNode else [];
        sel_has_assumptions = len(sel_assumptions) > 0;
    }
    sel_ev_cat_display = sel_ev_category.replace("_", " ") if sel_ev_category else "logical reasoning";

    # Edit mode labels and placeholders
    edit_label = "Add Evidence";
    edit_placeholder = "Add a fact, statistic, study, or expert quote...";
    if editMode == "clarify" {
        edit_label = "Clarify Wording";
        edit_placeholder = "Rewrite this node more clearly...";
    } elif editMode == "assumption" {
        edit_label = "Acknowledge Assumption";
        edit_placeholder = "What implicit assumption does this evidence rely on?";
    } elif editMode == "counter" {
        edit_label = "Add Counterargument";
        edit_placeholder = "What's a strong argument against this point?";
    }

    # Node issues
    nodeIssues: list = [];
    if selectedNode and currentIssues {
        sel_id = selectedNode["id"];
        _ii = 0;
        while _ii < len(currentIssues) {
            _iss = currentIssues[_ii];
            _nid = _iss["nodeId"] if "nodeId" in _iss else "";
            if _nid == sel_id { nodeIssues.append(_iss); }
            _ii = _ii + 1;
        }
    }
    has_node_issues = len(nodeIssues) > 0;

    # Helper to create proper closure for fix button edit modes
    def makeFixHandler(mode: str) -> any {
        return lambda -> None { startEdit(mode); };
    }

    # Build issue elements with inline Fix buttons
    nodeIssueElements: list = [];
    _ni = 0;
    while _ni < len(nodeIssues) {
        iss = nodeIssues[_ni];
        iss_type = iss["type"] if "type" in iss else "";
        # Map issue type to edit mode
        fix_mode = "evidence";
        if iss_type == "assumption_heavy" {
            fix_mode = "assumption";
        } elif iss_type == "counterargument_suggestion" {
            fix_mode = "counter";
        }
        fix_click_fn = makeFixHandler(fix_mode);
        nodeIssueElements.append(
            <div key={iss["id"]} style={{
                "padding": "10px 12px",
                "background": error_bg,
                "border": error_border,
                "borderRadius": "10px", "marginBottom": "6px"
            }}>
                <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "start", "gap": "8px"}}>
                    <div style={{"flex": "1"}}>
                        <div style={{"fontSize": "12px", "fontWeight": "500",
                                      "marginBottom": "3px",
                                      "color": error_text_color}}>
                            {iss["description"]}
                        </div>
                        <div style={{"fontSize": "11px", "color": mutedColor,
                                      "lineHeight": "1.4"}}>
                            {iss["suggestedAction"]}
                        </div>
                    </div>
                    <button onClick={fix_click_fn} style={{
                        "padding": "4px 10px", "background": action_bg,
                        "border": action_border, "borderRadius": "6px",
                        "fontSize": "10px", "fontWeight": "600",
                        "color": action_text_color, "cursor": "pointer",
                        "whiteSpace": "nowrap", "flexShrink": "0"
                    }}>Fix →</button>
                </div>
            </div>
        );
        _ni = _ni + 1;
    }

    # Build assumption elements
    assumptionElements: list = [];
    _ai = 0;
    while _ai < len(sel_assumptions) {
        assumption = sel_assumptions[_ai];
        assumptionElements.append(
            <div key={str(_ai)} style={{
                "padding": "8px 12px",
                "background": "rgba(245,158,11,0.08)",
                "border": "1px solid rgba(245,158,11,0.15)",
                "borderRadius": "8px", "marginBottom": "4px",
                "fontSize": "12px", "color": mutedColor
            }}>⚠️ {assumption}</div>
        );
        _ai = _ai + 1;
    }

    # Helper to create proper closure for issue click handlers
    def makeIssueClickHandler(nodeId: str) -> any {
        return lambda -> None { handleIssueClick(nodeId); };
    }

    # Build top issues for default panel
    topIssueElements: list = [];
    issues_safe: list = list(currentIssues) if currentIssues else [];
    top_count = len(issues_safe);
    if top_count > 3 { top_count = 3; }
    _ti = 0;
    while _ti < top_count {
        iss = issues_safe[_ti];
        sev_bg = "#fef2f2" if iss["severity"] == "high" else "#fffbeb";
        sev_color = "#ef4444" if iss["severity"] == "high" else "#f59e0b";
        iss_node_id = iss["nodeId"] if "nodeId" in iss else "";
        iss_click_fn = makeIssueClickHandler(iss_node_id);
        topIssueElements.append(
            <div key={iss["id"]} style={{
                "padding": "12px",
                "background": error_bg,
                "border": error_border,
                "borderRadius": "10px", "marginBottom": "8px", "cursor": "pointer"
            }} onClick={iss_click_fn}>
                <div style={{"display": "flex", "alignItems": "center", "gap": "8px", "marginBottom": "4px"}}>
                    <span style={{"padding": "2px 8px",
                                   "background": sev_bg,
                                   "color": sev_color,
                                   "fontSize": "10px", "fontWeight": "600",
                                   "borderRadius": "4px", "textTransform": "uppercase"}}>
                        {iss["severity"]}
                    </span>
                </div>
                <div style={{"fontSize": "13px", "color": textColor, "fontWeight": "500"}}>
                    {iss["description"]}
                </div>
            </div>
        );
        _ti = _ti + 1;
    }

    # Helper to create proper closure for counterarg accept buttons
    def makeAcceptHandler(caItem: dict) -> any {
        return lambda -> None { handleAcceptCounterarg(caItem); };
    }

    # Build suggested counterargument cards for default panel
    counterargElements: list = [];
    _cai = 0;
    while _cai < len(suggestedCounterargs) {
        ca = suggestedCounterargs[_cai];
        ca_text = ca["text"] if "text" in ca else "";
        ca_target = ca["target_node"] if "target_node" in ca else "";
        ca_severity = ca["severity"] if "severity" in ca else "medium";
        ca_sev_color = "#ef4444" if ca_severity == "high" else "#f59e0b";
        # Find target node content for display
        ca_target_content = "";
        _tni = 0;
        ca_nodes = currentGraph["nodes"] if "nodes" in currentGraph else [];
        while _tni < len(ca_nodes) {
            if ca_nodes[_tni]["id"] == ca_target {
                ca_target_content = ca_nodes[_tni]["content"];
                break;
            }
            _tni = _tni + 1;
        }
        ca_target_short = ca_target_content[:30] if len(ca_target_content) > 30 else ca_target_content;
        ca_accept_fn = makeAcceptHandler(ca);
        counterargElements.append(
            <div key={str(_cai)} style={{
                "padding": "12px",
                "background": "rgba(239,68,68,0.05)",
                "border": "1px solid rgba(239,68,68,0.12)",
                "borderRadius": "10px", "marginBottom": "8px"
            }}>
                <div style={{"display": "flex", "alignItems": "center", "gap": "6px", "marginBottom": "6px"}}>
                    <span style={{"padding": "2px 6px", "background": "rgba(239,68,68,0.1)",
                                   "color": ca_sev_color, "fontSize": "9px", "fontWeight": "600",
                                   "borderRadius": "4px", "textTransform": "uppercase"}}>{ca_severity}</span>
                    <span style={{"fontSize": "10px", "color": faintColor}}>targets: {ca_target_short}</span>
                </div>
                <div style={{"fontSize": "12px", "color": textColor, "marginBottom": "8px", "lineHeight": "1.4"}}>
                    {ca_text}
                </div>
                <button onClick={ca_accept_fn}
                    style={{
                        "padding": "6px 12px", "background": "rgba(239,68,68,0.1)",
                        "border": "1px solid rgba(239,68,68,0.2)", "borderRadius": "6px",
                        "fontSize": "11px", "fontWeight": "600", "color": "#ef4444",
                        "cursor": "pointer", "width": "100%"
                    }}>Add to Graph</button>
            </div>
        );
        _cai = _cai + 1;
    }
    has_counterarg_suggestions = len(counterargElements) > 0;

    # Build ghost nodes and edges from suggested counterargs
    ghostNodes: list = [];
    ghostEdges: list = [];
    _gi = 0;
    while _gi < len(suggestedCounterargs) {
        gca = suggestedCounterargs[_gi];
        gca_text = gca["text"] if "text" in gca else "";
        gca_target = gca["target_node"] if "target_node" in gca else "";
        if gca_text and gca_target {
            ghost_id = f"ghost_{_gi}";
            ghostNodes.append({
                "id": ghost_id,
                "type": "COUNTERARGUMENT",
                "content": gca_text,
                "confidence": 0.0,
                "isWeak": False,
                "issues": [],
                "position": {"x": 0, "y": 0},
                "isGhost": True,
                "ghostTarget": gca_target
            });
            ghostEdges.append({
                "id": f"ghost_edge_{_gi}",
                "source": ghost_id,
                "target": gca_target,
                "type": "CONTRADICTS",
                "isGhost": True
            });
        }
        _gi = _gi + 1;
    }

    graph_nodes = currentGraph["nodes"] if "nodes" in currentGraph else [];
    graph_edges = currentGraph["edges"] if "edges" in currentGraph else [];
    allNodes = list(graph_nodes) + ghostNodes;
    allEdges = list(graph_edges) + ghostEdges;
    node_count_str = str(len(graph_nodes)) if graph_nodes else "0";
    edge_count_str = str(len(graph_edges)) if graph_edges else "0";

    # Saving overlay opacity
    saving_overlay_display = "flex" if isSaving else "none";

    # Show actions based on node type
    show_add_evidence = sel_type == "CLAIM" or sel_type == "THESIS";
    show_acknowledge_assumption = sel_is_evidence;
    show_add_counter = sel_type == "CLAIM" or sel_type == "THESIS";

    return (
        <div style={{"height": "100vh", "fontFamily": "'DM Sans', system-ui, sans-serif",
                      "color": textColor, "display": "flex", "flexDirection": "column",
                      "overflow": "hidden", "background": bgColor}}>

            <div style={{"padding": "10px 20px", "borderBottom": f"1px solid {borderColor}",
                          "display": "flex", "alignItems": "center", "justifyContent": "space-between",
                          "background": panelBg}}>
                <div style={{"display": "flex", "alignItems": "center", "gap": "10px"}}>
                    <button onClick={handleBack} style={{
                        "background": "none", "border": "none", "cursor": "pointer",
                        "color": mutedColor, "fontSize": "14px", "padding": "4px 8px"
                    }}>← Back</button>
                    <span style={{"fontSize": "18px", "color": "#8b5cf6"}}>△</span>
                    <span style={{"fontWeight": "600", "fontSize": "15px", "color": textColor}}>Juncture</span>
                    <span style={{"color": faintColor}}>/</span>
                    <span style={{"color": mutedColor, "fontSize": "13px"}}>Review</span>
                </div>
                <div style={{"display": "flex", "alignItems": "center", "gap": "10px"}}>
                    <button onClick={toggleTheme} style={{
                        "padding": "5px 10px", "background": cardBg,
                        "border": f"1px solid {borderColor}", "borderRadius": "6px",
                        "color": mutedColor, "fontSize": "11px", "cursor": "pointer"
                    }}>{themeToggleText}</button>
                    <div style={{"display": "flex", "alignItems": "center", "gap": "6px",
                                  "padding": "5px 12px", "background": cardBg,
                                  "borderRadius": "8px", "border": f"1px solid {borderColor}"}}>
                        <span style={{"color": faintColor, "fontSize": "11px"}}>Score</span>
                        <span style={{"fontSize": "16px", "fontWeight": "700", "color": scoreColor}}>{overall}</span>
                        {(
                            <span style={{"fontSize": "12px", "fontWeight": "600", "color": delta_color,
                                           "marginLeft": "2px"}}>{delta_text}</span>
                        ) if delta_text else None}
                    </div>
                    <button onClick={handleExport} style={{
                        "padding": "6px 12px",
                        "background": exportBtnBg,
                        "border": "1px solid rgba(139,92,246,0.25)",
                        "borderRadius": "6px", "color": "#8b5cf6",
                        "fontWeight": "500", "fontSize": "12px", "cursor": "pointer"
                    }}>Export</button>
                </div>
            </div>

            <div style={{"padding": "7px 20px", "display": "flex", "alignItems": "center",
                          "gap": "20px", "borderBottom": f"1px solid {borderColor}",
                          "background": cardBg, "fontSize": "11px"}}>
                <div style={{"display": "flex", "alignItems": "center", "gap": "8px"}}>
                    <span style={{"color": faintColor, "fontSize": "10px", "textTransform": "uppercase",
                                   "letterSpacing": "1px"}}>Type</span>
                    {typeLegend.map(lambda item -> any {
                        return <div key={item["key"]} style={{"display": "flex", "alignItems": "center", "gap": "4px"}}>
                            <div style={{"width": "14px", "height": "14px", "borderRadius": "7px",
                                          "background": item["bg"], "border": f"2px solid {item['color']}"}}></div>
                            <span style={{"color": item["color"], "fontWeight": "500"}}>{item["label"]}</span>
                        </div>;
                    })}
                </div>
                <div style={{"display": "flex", "alignItems": "center", "gap": "8px"}}>
                    <span style={{"color": faintColor, "fontSize": "10px", "textTransform": "uppercase",
                                   "letterSpacing": "1px"}}>Strength</span>
                    <div style={{"display": "flex", "alignItems": "center", "gap": "4px"}}>
                        <div style={{"width": "10px", "height": "10px", "borderRadius": "3px", "background": "#16a34a"}}></div>
                        <span style={{"color": mutedColor}}>70+</span>
                    </div>
                    <div style={{"display": "flex", "alignItems": "center", "gap": "4px"}}>
                        <div style={{"width": "10px", "height": "10px", "borderRadius": "3px", "background": "#ca8a04"}}></div>
                        <span style={{"color": mutedColor}}>50-69</span>
                    </div>
                    <div style={{"display": "flex", "alignItems": "center", "gap": "4px"}}>
                        <div style={{"width": "10px", "height": "10px", "borderRadius": "3px", "background": "#dc2626"}}></div>
                        <span style={{"color": mutedColor}}>{"<50"}</span>
                    </div>
                </div>
                <div style={{"display": "flex", "alignItems": "center", "gap": "8px"}}>
                    <span style={{"color": faintColor, "fontSize": "10px", "textTransform": "uppercase",
                                   "letterSpacing": "1px"}}>Links</span>
                    <div style={{"display": "flex", "alignItems": "center", "gap": "3px"}}>
                        <div style={{"width": "16px", "height": "2px", "background": "#10b981"}}></div>
                        <span style={{"color": "#10b981", "fontSize": "10px"}}>supports</span>
                    </div>
                    <div style={{"display": "flex", "alignItems": "center", "gap": "3px"}}>
                        <div style={{"width": "16px", "height": "2px", "background": "#ef4444",
                                      "borderTop": "1px dashed #ef4444"}}></div>
                        <span style={{"color": "#ef4444", "fontSize": "10px"}}>contradicts</span>
                    </div>
                    <div style={{"display": "flex", "alignItems": "center", "gap": "3px"}}>
                        <div style={{"width": "16px", "height": "2px", "background": "#8b5cf6"}}></div>
                        <span style={{"color": "#8b5cf6", "fontSize": "10px"}}>addresses</span>
                    </div>
                </div>
            </div>

            <div style={{"display": "flex", "flex": "1", "overflow": "hidden"}}>

                <div style={{"flex": "1", "position": "relative", "display": "flex", "flexDirection": "column"}}>
                    {(
                        <button onClick={toggleBranch} style={{
                            "position": "absolute", "top": "12px", "left": "12px", "zIndex": "10",
                            "padding": "8px 16px", "borderRadius": "10px",
                            "background": "#6366f1", "color": "#fff", "fontSize": "13px",
                            "cursor": "pointer", "border": "none",
                            "boxShadow": "0 2px 8px rgba(99,102,241,0.3)",
                            "display": "flex", "alignItems": "center", "gap": "8px"
                        }}>Editing branch - Click to exit</button>
                    ) if focusBranch else None}

                    <div style={{"flex": "1"}}>
                        <ArgumentGraphView
                            nodes={allNodes}
                            edges={allEdges}
                            onNodeClick={handleNodeClick}
                            selectedNodeId={selectedNode["id"] if selectedNode else None}
                            isDark={isDark}
                            focusBranch={focusBranch}
                            onGhostAccept={handleAcceptCounterarg}
                        />
                    </div>

                    <div style={{"padding": "8px 20px", "borderTop": f"1px solid {borderColor}",
                                  "background": panelBg, "display": "flex",
                                  "alignItems": "center", "gap": "12px", "overflowX": "auto"}}>
                        <span style={{"color": faintColor, "fontSize": "10px",
                                       "textTransform": "uppercase", "letterSpacing": "1px",
                                       "flexShrink": "0"}}>Sources</span>
                        <span style={{"color": mutedColor, "fontSize": "11px"}}>
                            {node_count_str} nodes - {edge_count_str} edges
                        </span>
                    </div>
                </div>

                {(
                    <div style={{"width": "400px", "background": panelBg,
                                  "borderLeft": f"1px solid {borderColor}",
                                  "display": "flex", "flexDirection": "column", "overflow": "hidden",
                                  "position": "relative"}}>

                        <div style={{"display": saving_overlay_display, "position": "absolute",
                                      "top": "0", "left": "0", "right": "0", "bottom": "0",
                                      "background": "rgba(0,0,0,0.3)", "zIndex": "20",
                                      "alignItems": "center", "justifyContent": "center"}}>
                            <div style={{"padding": "12px 20px", "background": panelBg,
                                          "borderRadius": "10px", "fontSize": "13px",
                                          "color": textColor, "fontWeight": "500"}}>Saving...</div>
                        </div>

                        <div style={{"padding": "16px 20px", "borderBottom": f"1px solid {borderColor}"}}>
                            <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "start"}}>
                                <div style={{"display": "flex", "alignItems": "center", "gap": "10px"}}>
                                    <span style={{"color": sel_type_color, "fontSize": "11px",
                                                   "fontWeight": "700", "textTransform": "uppercase",
                                                   "letterSpacing": "1px"}}>{sel_type}</span>
                                    <span style={{"padding": "3px 10px", "background": sel_str_bg,
                                                   "color": sel_str_color, "borderRadius": "8px",
                                                   "fontSize": "11px", "fontWeight": "600",
                                                   "border": f"1px solid {sel_str_color}"}}>
                                        {str(int(sel_conf_val * 100))}%
                                    </span>
                                </div>
                                <button onClick={closePanel} style={{
                                    "background": cardBg, "border": f"1px solid {borderColor}",
                                    "color": mutedColor, "fontSize": "14px", "cursor": "pointer",
                                    "padding": "4px 10px", "borderRadius": "6px"
                                }}>✕</button>
                            </div>
                            <h3 style={{"fontSize": "16px", "fontWeight": "600", "marginTop": "10px",
                                         "lineHeight": "1.5", "color": textColor}}>{sel_content}</h3>
                        </div>

                        <div style={{"flex": "1", "overflowY": "auto", "padding": "16px 20px"}}>

                            <div style={{"marginBottom": "16px"}}>
                                <div style={{"color": "#dc2626", "fontSize": "10px", "fontWeight": "700",
                                              "textTransform": "uppercase", "letterSpacing": "1.5px",
                                              "marginBottom": "8px", "display": "flex",
                                              "alignItems": "center", "gap": "6px"}}>
                                    <span style={{"width": "5px", "height": "5px",
                                                   "background": "#dc2626", "borderRadius": "3px"}}></span>
                                    Issues
                                </div>
                                {(
                                    <div>{nodeIssueElements}</div>
                                ) if has_node_issues else (
                                    <div style={{
                                        "padding": "10px 12px", "borderRadius": "8px", "fontSize": "12px",
                                        "background": success_bg,
                                        "border": success_border,
                                        "color": success_text_color
                                    }}>Well-supported ✓</div>
                                )}
                            </div>

                            <div style={{"marginBottom": "16px"}}>
                                <div style={{"color": "#8b5cf6", "fontSize": "10px", "fontWeight": "700",
                                              "textTransform": "uppercase", "letterSpacing": "1.5px",
                                              "marginBottom": "8px", "display": "flex",
                                              "alignItems": "center", "gap": "6px"}}>
                                    <span style={{"width": "5px", "height": "5px",
                                                   "background": "#8b5cf6", "borderRadius": "3px"}}></span>
                                    Quick Actions
                                </div>
                                <div style={{"display": "flex", "flexWrap": "wrap", "gap": "6px"}}>
                                    {(
                                        <button onClick={lambda -> None { startEdit("evidence"); }} style={{
                                            "padding": "7px 12px", "background": action_bg,
                                            "border": action_border, "borderRadius": "8px",
                                            "fontSize": "11px", "fontWeight": "600",
                                            "color": action_text_color, "cursor": "pointer"
                                        }}>📊 Add Evidence</button>
                                    ) if show_add_evidence else None}
                                    {(
                                        <button onClick={lambda -> None { startEdit("assumption"); }} style={{
                                            "padding": "7px 12px", "background": action_bg,
                                            "border": action_border, "borderRadius": "8px",
                                            "fontSize": "11px", "fontWeight": "600",
                                            "color": action_text_color, "cursor": "pointer"
                                        }}>🔗 Assumption</button>
                                    ) if show_acknowledge_assumption else None}
                                    {(
                                        <button onClick={lambda -> None { startEdit("counter"); }} style={{
                                            "padding": "7px 12px", "background": action_bg,
                                            "border": action_border, "borderRadius": "8px",
                                            "fontSize": "11px", "fontWeight": "600",
                                            "color": action_text_color, "cursor": "pointer"
                                        }}>⚔️ Counter</button>
                                    ) if show_add_counter else None}
                                    <button onClick={lambda -> None { startEdit("clarify"); }} style={{
                                        "padding": "7px 12px", "background": action_bg,
                                        "border": action_border, "borderRadius": "8px",
                                        "fontSize": "11px", "fontWeight": "600",
                                        "color": action_text_color, "cursor": "pointer"
                                    }}>✏️ Clarify</button>
                                    <button onClick={lambda -> None { startEdit("delete"); }} style={{
                                        "padding": "7px 12px", "background": "rgba(239,68,68,0.06)",
                                        "border": "1px solid rgba(239,68,68,0.15)", "borderRadius": "8px",
                                        "fontSize": "11px", "fontWeight": "600",
                                        "color": "#ef4444", "cursor": "pointer"
                                    }}>🗑️ Delete</button>
                                </div>
                            </div>

                            {(
                                <div style={{"marginBottom": "16px", "padding": "14px",
                                              "background": "rgba(139,92,246,0.06)",
                                              "border": "1px solid rgba(139,92,246,0.15)",
                                              "borderRadius": "10px"}}>
                                    <div style={{"fontSize": "12px", "fontWeight": "600",
                                                  "color": action_text_color, "marginBottom": "8px"}}>{edit_label}</div>
                                    <textarea
                                        value={editInputValue}
                                        onChange={handleEditInput}
                                        placeholder={edit_placeholder}
                                        style={{
                                            "width": "100%", "minHeight": "80px", "padding": "10px",
                                            "background": cardBg, "border": f"1px solid {borderColor}",
                                            "borderRadius": "8px", "fontSize": "12px", "color": textColor,
                                            "resize": "vertical", "fontFamily": "'DM Sans', system-ui, sans-serif",
                                            "boxSizing": "border-box"
                                        }}
                                    />
                                    <div style={{"display": "flex", "gap": "8px", "marginTop": "8px"}}>
                                        <button onClick={saveEdit} style={{
                                            "flex": "1", "padding": "8px 14px",
                                            "background": "linear-gradient(135deg, #8b5cf6, #7c3aed)",
                                            "border": "none", "borderRadius": "8px",
                                            "fontSize": "12px", "fontWeight": "600", "color": "#fff",
                                            "cursor": "pointer"
                                        }}>Save</button>
                                        <button onClick={cancelEdit} style={{
                                            "padding": "8px 14px", "background": cardBg,
                                            "border": f"1px solid {borderColor}", "borderRadius": "8px",
                                            "fontSize": "12px", "color": mutedColor, "cursor": "pointer"
                                        }}>Cancel</button>
                                    </div>
                                </div>
                            ) if editMode else None}

                            {(
                                <div style={{"marginBottom": "16px", "padding": "14px",
                                              "background": "rgba(239,68,68,0.06)",
                                              "border": "1px solid rgba(239,68,68,0.15)",
                                              "borderRadius": "10px"}}>
                                    <div style={{"fontSize": "12px", "fontWeight": "600",
                                                  "color": "#ef4444", "marginBottom": "8px"}}>Delete this node?</div>
                                    <div style={{"fontSize": "11px", "color": mutedColor, "marginBottom": "10px"}}>
                                        This will remove the node and all its connections. This cannot be undone.
                                    </div>
                                    <div style={{"display": "flex", "gap": "8px"}}>
                                        <button onClick={handleDelete} style={{
                                            "flex": "1", "padding": "8px 14px",
                                            "background": "#ef4444",
                                            "border": "none", "borderRadius": "8px",
                                            "fontSize": "12px", "fontWeight": "600", "color": "#fff",
                                            "cursor": "pointer"
                                        }}>Delete</button>
                                        <button onClick={cancelEdit} style={{
                                            "padding": "8px 14px", "background": cardBg,
                                            "border": f"1px solid {borderColor}", "borderRadius": "8px",
                                            "fontSize": "12px", "color": mutedColor, "cursor": "pointer"
                                        }}>Cancel</button>
                                    </div>
                                </div>
                            ) if showConfirmDelete else None}

                            {(
                                <div style={{"marginBottom": "16px"}}>
                                    <div style={{"color": "#f59e0b", "fontSize": "10px", "fontWeight": "700",
                                                  "textTransform": "uppercase", "letterSpacing": "1.5px",
                                                  "marginBottom": "8px", "display": "flex",
                                                  "alignItems": "center", "gap": "6px"}}>
                                        <span style={{"width": "5px", "height": "5px",
                                                       "background": "#f59e0b", "borderRadius": "3px"}}></span>
                                        Assumptions
                                    </div>
                                    {assumptionElements}
                                </div>
                            ) if sel_has_assumptions else None}

                            {(
                                <div style={{"marginBottom": "16px"}}>
                                    <div style={{"color": "#06b6d4", "fontSize": "10px", "fontWeight": "700",
                                                  "textTransform": "uppercase", "letterSpacing": "1.5px",
                                                  "marginBottom": "8px", "display": "flex",
                                                  "alignItems": "center", "gap": "6px"}}>
                                        <span style={{"width": "5px", "height": "5px",
                                                       "background": "#06b6d4", "borderRadius": "3px"}}></span>
                                        Evidence Details
                                    </div>
                                    <div style={{
                                        "padding": "8px 12px",
                                        "background": "rgba(6,182,212,0.06)",
                                        "border": "1px solid rgba(6,182,212,0.12)",
                                        "borderRadius": "8px", "fontSize": "12px"
                                    }}>
                                        <div style={{"display": "flex", "justifyContent": "space-between", "marginBottom": "4px"}}>
                                            <span style={{"color": mutedColor}}>Category</span>
                                            <span style={{"fontWeight": "600", "color": textColor, "textTransform": "capitalize"}}>
                                                {sel_ev_cat_display}
                                            </span>
                                        </div>
                                        <div style={{"display": "flex", "justifyContent": "space-between"}}>
                                            <span style={{"color": mutedColor}}>Quality Score</span>
                                            <span style={{"fontWeight": "600", "color": sel_str_color}}>
                                                {str(sel_node_score)}%
                                            </span>
                                        </div>
                                    </div>
                                </div>
                            ) if sel_is_evidence else None}

                            {(
                                <div style={{"marginBottom": "16px"}}>
                                    <div style={{"color": "#3b82f6", "fontSize": "10px", "fontWeight": "700",
                                                  "textTransform": "uppercase", "letterSpacing": "1.5px",
                                                  "marginBottom": "8px", "display": "flex",
                                                  "alignItems": "center", "gap": "6px"}}>
                                        <span style={{"width": "5px", "height": "5px",
                                                       "background": "#3b82f6", "borderRadius": "3px"}}></span>
                                        Node Score
                                    </div>
                                    <div style={{"textAlign": "center", "padding": "12px",
                                                  "background": cardBg, "borderRadius": "10px"}}>
                                        <div style={{"fontSize": "28px", "fontWeight": "700", "color": sel_str_color}}>
                                            {str(sel_node_score)}
                                        </div>
                                        <div style={{"color": mutedColor, "fontSize": "11px"}}>Node Quality</div>
                                    </div>
                                </div>
                            ) if sel_has_node_score else None}
                        </div>
                    </div>
                ) if selectedNode else (
                    <div style={{"width": "380px", "background": panelBg,
                                  "borderLeft": f"1px solid {borderColor}",
                                  "display": "flex", "flexDirection": "column", "overflow": "hidden",
                                  "position": "relative"}}>

                        <div style={{"display": saving_overlay_display, "position": "absolute",
                                      "top": "0", "left": "0", "right": "0", "bottom": "0",
                                      "background": "rgba(0,0,0,0.3)", "zIndex": "20",
                                      "alignItems": "center", "justifyContent": "center"}}>
                            <div style={{"padding": "12px 20px", "background": panelBg,
                                          "borderRadius": "10px", "fontSize": "13px",
                                          "color": textColor, "fontWeight": "500"}}>Saving...</div>
                        </div>

                        <div style={{"flex": "1", "overflowY": "auto", "padding": "20px"}}>
                            <div style={{"display": "flex", "alignItems": "center", "gap": "8px", "marginBottom": "16px"}}>
                                <span style={{"fontSize": "20px"}}>📈</span>
                                <span style={{"fontWeight": "600", "fontSize": "16px", "color": textColor}}>Reasoning Score</span>
                            </div>
                            <div style={{"textAlign": "center", "padding": "20px",
                                          "background": cardBg, "borderRadius": "12px", "marginBottom": "20px"}}>
                                <div style={{"fontSize": "48px", "fontWeight": "700", "color": scoreColor}}>{overall}</div>
                                <div style={{"color": mutedColor, "fontSize": "14px"}}>out of 100</div>
                                <div style={{"height": "8px", "background": bar_track_bg,
                                              "borderRadius": "4px", "marginTop": "12px"}}>
                                    <div style={{"height": "100%", "borderRadius": "4px", "transition": "width 0.5s",
                                                  "width": f"{overall}%", "background": scoreColor}}></div>
                                </div>
                                {(
                                    <div style={{"marginTop": "8px", "fontSize": "14px", "fontWeight": "600",
                                                  "color": delta_color}}>{delta_text}</div>
                                ) if delta_text else None}
                            </div>

                            <div style={{"marginBottom": "6px"}}>
                                <div style={{"display": "flex", "justifyContent": "space-between",
                                              "fontSize": "12px", "marginBottom": "4px"}}>
                                    <span style={{"color": mutedColor}}>Support (40%)</span>
                                    <span style={{"fontWeight": "600", "color": textColor}}>{support_val}%</span>
                                </div>
                                <div style={{"height": "4px", "background": bar_track_bg, "borderRadius": "2px"}}>
                                    <div style={{"height": "100%", "borderRadius": "2px", "transition": "width 0.5s",
                                                  "width": f"{support_val}%", "background": support_bar_color}}></div>
                                </div>
                            </div>
                            <div style={{"marginBottom": "6px"}}>
                                <div style={{"display": "flex", "justifyContent": "space-between",
                                              "fontSize": "12px", "marginBottom": "4px"}}>
                                    <span style={{"color": mutedColor}}>Premise (40%)</span>
                                    <span style={{"fontWeight": "600", "color": textColor}}>{premise_val}%</span>
                                </div>
                                <div style={{"height": "4px", "background": bar_track_bg, "borderRadius": "2px"}}>
                                    <div style={{"height": "100%", "borderRadius": "2px", "transition": "width 0.5s",
                                                  "width": f"{premise_val}%", "background": premise_bar_color}}></div>
                                </div>
                            </div>
                            <div style={{"marginBottom": "20px"}}>
                                <div style={{"display": "flex", "justifyContent": "space-between",
                                              "fontSize": "12px", "marginBottom": "4px"}}>
                                    <span style={{"color": mutedColor}}>Consistency (20%)</span>
                                    <span style={{"fontWeight": "600", "color": textColor}}>{consistency_val}%</span>
                                </div>
                                <div style={{"height": "4px", "background": bar_track_bg, "borderRadius": "2px"}}>
                                    <div style={{"height": "100%", "borderRadius": "2px", "transition": "width 0.5s",
                                                  "width": f"{consistency_val}%", "background": consistency_bar_color}}></div>
                                </div>
                            </div>

                            <div style={{"display": "flex", "alignItems": "center", "gap": "8px", "marginBottom": "12px"}}>
                                <span style={{"fontSize": "16px"}}>⚠️</span>
                                <span style={{"fontWeight": "600", "fontSize": "14px", "color": textColor}}>Top Issues</span>
                            </div>
                            <p style={{"fontSize": "12px", "color": mutedColor, "marginBottom": "12px"}}>Click on a node to fix it</p>
                            {(
                                <div>{topIssueElements}</div>
                            ) if len(currentIssues) > 0 else (
                                <div style={{"padding": "14px", "background": "rgba(34,197,94,0.06)",
                                              "border": "1px solid rgba(34,197,94,0.12)",
                                              "borderRadius": "10px", "fontSize": "13px",
                                              "color": "#16a34a"}}>
                                    No major issues found! Great work.
                                </div>
                            )}

                            {(
                                <div style={{"marginTop": "20px"}}>
                                    <div style={{"display": "flex", "alignItems": "center", "gap": "8px", "marginBottom": "12px"}}>
                                        <span style={{"fontSize": "16px"}}>⚔️</span>
                                        <span style={{"fontWeight": "600", "fontSize": "14px", "color": textColor}}>Consider These Counterarguments</span>
                                    </div>
                                    <p style={{"fontSize": "12px", "color": mutedColor, "marginBottom": "12px"}}>
                                        Strengthen your argument by addressing opposing views
                                    </p>
                                    {counterargElements}
                                </div>
                            ) if has_counterarg_suggestions else None}
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}
