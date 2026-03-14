"""Juncture - Review Screen with mockup-style graph, side panel, legend, source bar."""

sv import from ...main { GetContext, GetGraphWithScoring }

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
        focusBranch: str = None;

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

    can with entry {
        currentGraph = screen_data["graphData"] if "graphData" in screen_data else None;
        currentScore = screen_data["scoreData"] if "scoreData" in screen_data else None;
        currentIssues = screen_data["issuesData"] if "issuesData" in screen_data else [];
        if not currentGraph { loadContext(); }
    }

    def handleNodeClick(node_data: any) -> None {
        selectedNode = node_data;
        focusBranch = None;
    }

    def closePanel() -> None {
        selectedNode = None;
        focusBranch = None;
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

    def handleReviseNode() -> None {
        if selectedNode {
            navigate("revise", {
                "graphData": currentGraph,
                "scoreData": currentScore,
                "issuesData": currentIssues,
                "nodeId": selectedNode["id"]
            });
        }
    }

    def goToRevise() -> None {
        if selectedNode {
            navigate("revise", {
                "graphData": currentGraph,
                "scoreData": currentScore,
                "issuesData": currentIssues,
                "nodeId": selectedNode["id"] if selectedNode else ""
            });
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
                    break;
                }
            }
        }
    }

    if not currentGraph or not currentScore {
        return <div style={{
            "minHeight": "100vh", "display": "flex", "alignItems": "center",
            "justifyContent": "center", "fontFamily": "'DM Sans', system-ui, sans-serif",
            "color": "#64748b"
        }}><p>Loading argument map...</p></div>;
    }

    # Score color
    overall = currentScore["overall"] if "overall" in currentScore else 0;
    scoreColor = "#16a34a" if overall >= 70 else ("#ca8a04" if overall >= 50 else "#dc2626");

    # Theme colors - precomputed
    bgColor = "#0f0f17" if isDark else "#f4f1ee";
    panelBg = "#13131f" if isDark else "#ffffff";
    borderColor = "rgba(255,255,255,0.07)" if isDark else "rgba(0,0,0,0.08)";
    textColor = "#f1f5f9" if isDark else "#1e293b";
    mutedColor = "#94a3b8" if isDark else "#475569";
    faintColor = "#64748b" if isDark else "#94a3b8";
    cardBg = "rgba(255,255,255,0.04)" if isDark else "rgba(0,0,0,0.03)";
    themeToggleText = "Light" if isDark else "Dark";
    exportBtnBg = "rgba(139,92,246,0.15)" if isDark else "rgba(139,92,246,0.1)";

    # Precomputed conditional styles for issue cards
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

    # Score bar colors
    support_val = currentScore["support"] if "support" in currentScore else 0;
    premise_val = currentScore["premise"] if "premise" in currentScore else 0;
    consistency_val = currentScore["consistency"] if "consistency" in currentScore else 0;
    support_bar_color = "#10b981" if support_val >= 70 else ("#f59e0b" if support_val >= 50 else "#ef4444");
    premise_bar_color = "#10b981" if premise_val >= 70 else ("#f59e0b" if premise_val >= 50 else "#ef4444");
    consistency_bar_color = "#10b981" if consistency_val >= 70 else ("#f59e0b" if consistency_val >= 50 else "#ef4444");

    # Node type colors for legend
    typeLegend = [
        {"key": "THESIS", "color": "#7c3aed", "bg": "#ede9fe", "label": "Thesis"},
        {"key": "CLAIM", "color": "#9f7aea", "bg": "#e8e0fc", "label": "Claim"},
        {"key": "EVIDENCE", "color": "#10b981", "bg": "#d1fae5", "label": "Evidence"},
        {"key": "ASSUMPTION", "color": "#f59e0b", "bg": "#fef3c7", "label": "Assumption"},
        {"key": "COUNTERARGUMENT", "color": "#ef4444", "bg": "#fee2e2", "label": "Counter"}
    ];

    # Get issues for selected node (avoid list comprehension for safety)
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

    # Selected node info
    sel_type = selectedNode["type"] if selectedNode and "type" in selectedNode else "CLAIM";
    sel_content = selectedNode["content"] if selectedNode and "content" in selectedNode else "";
    sel_confidence = selectedNode["confidence"] if selectedNode and "confidence" in selectedNode else 0.5;
    sel_conf_val = sel_confidence if sel_confidence else 0.5;
    sel_str_color = "#16a34a" if sel_conf_val >= 0.7 else ("#ca8a04" if sel_conf_val >= 0.5 else "#dc2626");
    sel_str_bg = "rgba(34,197,94,0.1)" if sel_conf_val >= 0.7 else ("rgba(250,204,21,0.15)" if sel_conf_val >= 0.5 else "rgba(239,68,68,0.1)");

    typeColorMap = {
        "THESIS": "#7c3aed", "CLAIM": "#9f7aea", "EVIDENCE": "#10b981",
        "ASSUMPTION": "#f59e0b", "COUNTERARGUMENT": "#ef4444"
    };
    sel_type_color = typeColorMap[sel_type] if sel_type in typeColorMap else "#9f7aea";

    # Edit branch button state
    is_editing_selected = False;
    if focusBranch and selectedNode {
        is_editing_selected = focusBranch == selectedNode["id"];
    }
    edit_btn_bg = "#6366f1" if is_editing_selected else "rgba(99,102,241,0.08)";
    edit_btn_color = "#fff" if is_editing_selected else "#6366f1";
    edit_btn_text = "Exit branch editing" if is_editing_selected else "Edit this branch";

    # Build node issue elements for selected node panel (while loops for safety)
    nodeIssueElements: list = [];
    _ni = 0;
    while _ni < len(nodeIssues) {
        iss = nodeIssues[_ni];
        nodeIssueElements.append(
            <div key={iss["id"]} style={{
                "padding": "12px",
                "background": error_bg,
                "border": error_border,
                "borderRadius": "10px", "marginBottom": "6px"
            }}>
                <div style={{"fontSize": "13px", "fontWeight": "500",
                              "marginBottom": "3px",
                              "color": error_text_color}}>
                    {iss["description"]}
                </div>
                <div style={{"fontSize": "12px", "color": mutedColor,
                              "lineHeight": "1.5"}}>
                    {iss["suggestedAction"]}
                </div>
            </div>
        );
        _ni = _ni + 1;
    }

    # Build top issues elements for default panel (while loops for safety)
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
        topIssueElements.append(
            <div key={iss["id"]} style={{
                "padding": "12px",
                "background": error_bg,
                "border": error_border,
                "borderRadius": "10px", "marginBottom": "8px", "cursor": "pointer"
            }} onClick={lambda -> None { handleIssueClick(iss_node_id); }}>
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

    graph_nodes = currentGraph["nodes"] if "nodes" in currentGraph else [];
    graph_edges = currentGraph["edges"] if "edges" in currentGraph else [];
    node_count_str = str(len(graph_nodes)) if graph_nodes else "0";
    edge_count_str = str(len(graph_edges)) if graph_edges else "0";

    return (
        <div style={{"minHeight": "100vh", "fontFamily": "'DM Sans', system-ui, sans-serif",
                      "color": textColor, "display": "flex", "flexDirection": "column",
                      "background": bgColor}}>

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
                            nodes={currentGraph["nodes"]}
                            edges={currentGraph["edges"]}
                            onNodeClick={handleNodeClick}
                            selectedNodeId={selectedNode["id"] if selectedNode else None}
                            isDark={isDark}
                            focusBranch={focusBranch}
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
                                  "display": "flex", "flexDirection": "column", "overflow": "hidden"}}>
                        <div style={{"padding": "20px", "borderBottom": f"1px solid {borderColor}"}}>
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
                            <h3 style={{"fontSize": "17px", "fontWeight": "600", "marginTop": "12px",
                                         "lineHeight": "1.5", "color": textColor}}>{sel_content}</h3>
                        </div>

                        <div style={{"flex": "1", "overflowY": "auto", "padding": "20px"}}>

                            <button onClick={toggleBranch} style={{
                                "width": "100%", "padding": "10px 14px", "marginBottom": "14px",
                                "background": edit_btn_bg,
                                "border": "1px solid rgba(99,102,241,0.2)", "borderRadius": "10px",
                                "fontSize": "12px", "fontWeight": "600", "cursor": "pointer",
                                "color": edit_btn_color,
                                "textAlign": "center"
                            }}>{edit_btn_text}</button>

                            <div style={{"marginBottom": "18px"}}>
                                <div style={{"color": "#dc2626", "fontSize": "11px", "fontWeight": "700",
                                              "textTransform": "uppercase", "letterSpacing": "1.5px",
                                              "marginBottom": "10px", "display": "flex",
                                              "alignItems": "center", "gap": "8px"}}>
                                    <span style={{"width": "6px", "height": "6px",
                                                   "background": "#dc2626", "borderRadius": "3px"}}></span>
                                    What's Wrong
                                </div>
                                {(
                                    <div>{nodeIssueElements}</div>
                                ) if len(nodeIssues) > 0 else (
                                    <div style={{
                                        "padding": "12px", "borderRadius": "10px", "fontSize": "13px",
                                        "background": success_bg,
                                        "border": success_border,
                                        "color": success_text_color
                                    }}>Well-supported ✓</div>
                                )}
                            </div>

                            <div style={{"marginBottom": "18px"}}>
                                <div style={{"color": "#8b5cf6", "fontSize": "11px", "fontWeight": "700",
                                              "textTransform": "uppercase", "letterSpacing": "1.5px",
                                              "marginBottom": "10px", "display": "flex",
                                              "alignItems": "center", "gap": "8px"}}>
                                    <span style={{"width": "6px", "height": "6px",
                                                   "background": "#8b5cf6", "borderRadius": "3px"}}></span>
                                    Suggested Actions
                                </div>
                                <button onClick={goToRevise}
                                    style={{
                                        "display": "block", "width": "100%", "padding": "10px 14px",
                                        "marginBottom": "6px",
                                        "background": action_bg,
                                        "border": action_border,
                                        "borderRadius": "10px", "fontSize": "13px",
                                        "color": action_text_color,
                                        "textAlign": "left", "cursor": "pointer"
                                    }}>Add Evidence</button>
                                <button onClick={goToRevise}
                                    style={{
                                        "display": "block", "width": "100%", "padding": "10px 14px",
                                        "marginBottom": "6px",
                                        "background": action_bg,
                                        "border": action_border,
                                        "borderRadius": "10px", "fontSize": "13px",
                                        "color": action_text_color,
                                        "textAlign": "left", "cursor": "pointer"
                                    }}>Add Assumption</button>
                                <button onClick={goToRevise}
                                    style={{
                                        "display": "block", "width": "100%", "padding": "10px 14px",
                                        "marginBottom": "6px",
                                        "background": action_bg,
                                        "border": action_border,
                                        "borderRadius": "10px", "fontSize": "13px",
                                        "color": action_text_color,
                                        "textAlign": "left", "cursor": "pointer"
                                    }}>Clarify Wording</button>
                            </div>

                            <div style={{"marginBottom": "18px"}}>
                                <div style={{"color": "#3b82f6", "fontSize": "11px", "fontWeight": "700",
                                              "textTransform": "uppercase", "letterSpacing": "1.5px",
                                              "marginBottom": "10px", "display": "flex",
                                              "alignItems": "center", "gap": "8px"}}>
                                    <span style={{"width": "6px", "height": "6px",
                                                   "background": "#3b82f6", "borderRadius": "3px"}}></span>
                                    Score Breakdown
                                </div>
                                <div style={{"marginBottom": "8px"}}>
                                    <div style={{"display": "flex", "justifyContent": "space-between",
                                                  "fontSize": "12px", "marginBottom": "4px"}}>
                                        <span style={{"color": mutedColor}}>Support (40%)</span>
                                        <span style={{"fontWeight": "600", "color": textColor}}>{support_val}%</span>
                                    </div>
                                    <div style={{"height": "4px", "background": bar_track_bg, "borderRadius": "2px"}}>
                                        <div style={{"height": "100%", "borderRadius": "2px", "transition": "width 0.5s",
                                                      "width": f"{support_val}%",
                                                      "background": support_bar_color}}></div>
                                    </div>
                                </div>
                                <div style={{"marginBottom": "8px"}}>
                                    <div style={{"display": "flex", "justifyContent": "space-between",
                                                  "fontSize": "12px", "marginBottom": "4px"}}>
                                        <span style={{"color": mutedColor}}>Premise (40%)</span>
                                        <span style={{"fontWeight": "600", "color": textColor}}>{premise_val}%</span>
                                    </div>
                                    <div style={{"height": "4px", "background": bar_track_bg, "borderRadius": "2px"}}>
                                        <div style={{"height": "100%", "borderRadius": "2px", "transition": "width 0.5s",
                                                      "width": f"{premise_val}%",
                                                      "background": premise_bar_color}}></div>
                                    </div>
                                </div>
                                <div style={{"marginBottom": "8px"}}>
                                    <div style={{"display": "flex", "justifyContent": "space-between",
                                                  "fontSize": "12px", "marginBottom": "4px"}}>
                                        <span style={{"color": mutedColor}}>Consistency (20%)</span>
                                        <span style={{"fontWeight": "600", "color": textColor}}>{consistency_val}%</span>
                                    </div>
                                    <div style={{"height": "4px", "background": bar_track_bg, "borderRadius": "2px"}}>
                                        <div style={{"height": "100%", "borderRadius": "2px", "transition": "width 0.5s",
                                                      "width": f"{consistency_val}%",
                                                      "background": consistency_bar_color}}></div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div style={{"padding": "16px 20px", "borderTop": f"1px solid {borderColor}"}}>
                            <button onClick={handleReviseNode} style={{
                                "width": "100%", "padding": "13px 18px",
                                "background": "linear-gradient(135deg, #8b5cf6, #7c3aed)",
                                "border": "none", "borderRadius": "10px",
                                "fontSize": "14px", "fontWeight": "600", "color": "#fff",
                                "cursor": "pointer", "boxShadow": "0 4px 12px rgba(124,58,237,0.25)"
                            }}>Revise This Node →</button>
                        </div>
                    </div>
                ) if selectedNode else (
                    <div style={{"width": "380px", "background": panelBg,
                                  "borderLeft": f"1px solid {borderColor}",
                                  "display": "flex", "flexDirection": "column", "overflow": "hidden"}}>
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
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}
