"""Juncture - Review Screen with inline editing workshop, ghost nodes, and score delta."""

import from ..components.ArgumentGraphView { ArgumentGraphView }
import from ..components.Button { Button }
import from ..components.Header { Header }

def:pub ReviewScreen(props: any) -> JsxElement {
    navigate = props.navigate;
    screen_data = props.screenData if props.screenData else {};

    has currentGraph: dict = None,
        currentScore: dict = None,
        currentIssues: list = [],
        currentNextActions: list = [],
        selectedNode: dict = None,
        focusBranch: str = None,
        editMode: str = "",
        editInputValue: str = "",
        sourceUrlValue: str = "",
        isSaving: bool = False,
        prevScore: int = 0,
        scoreDelta: int = 0,
        showScoreDelta: bool = False,
        showConfirmDelete: bool = False,
        suggestedCounterargs: list = [],
        _acceptedTexts: list = [];

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
                        currentNextActions = data["nextActions"] if "nextActions" in data else [];
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
            currentNextActions = screen_data["nextActionsData"] if "nextActionsData" in screen_data else [];
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

    def toggleBranch() -> None {
        if selectedNode {
            if focusBranch == selectedNode["id"] {
                focusBranch = "";
            } else {
                focusBranch = selectedNode["id"];
            }
        }
    }

    def handleExport() -> None {
        navigate("export", {
            "graphData": currentGraph,
            "scoreData": currentScore,
            "issuesData": currentIssues,
            "nextActionsData": currentNextActions
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

    def startEdit(mode: str) -> None {
        showScoreDelta = False;
        showConfirmDelete = False;
        if mode == "delete" {
            editMode = "";
            showConfirmDelete = True;
            return;
        }
        if mode == "counter" {
            handleGenerateCounter();
            return;
        }
        if mode == "clarify" {
            handleClarifyNode();
            return;
        }
        editMode = mode;
        editInputValue = "";
    }

    async def handleGenerateCounter() -> None {
        if not selectedNode or not currentGraph { return; }
        isSaving = True;
        _gcGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _gcNodeId = selectedNode["id"];
        _gcPrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        try {
            mutResult = await root spawn GenerateCounter(graphId=_gcGraphId, targetNodeId=_gcNodeId);
            mutData = mutResult.reports[0] if mutResult.reports else {};
            if "graph" in mutData { currentGraph = mutData["graph"]; }
            if "score" in mutData {
                currentScore = mutData["score"];
                _gcNewScore = currentScore["overall"] if "overall" in currentScore else _gcPrevScore;
                applyScoreDelta(_gcPrevScore, _gcNewScore);
            }
            if "issues" in mutData { currentIssues = mutData["issues"]; }
            if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
            _gcNodes = currentGraph["nodes"] if currentGraph and "nodes" in currentGraph else [];
            _gcFound = None;
            _gci = 0;
            while _gci < len(_gcNodes) {
                if _gcNodes[_gci]["id"] == _gcNodeId { _gcFound = _gcNodes[_gci]; break; }
                _gci = _gci + 1;
            }
            selectedNode = {_gcFound};
        } except Exception { }
        isSaving = False;
    }

    async def handleClarifyNode() -> None {
        if not selectedNode or not currentGraph { return; }
        isSaving = True;
        _clGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _clNodeId = selectedNode["id"];
        _clPrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        try {
            mutResult = await root spawn ClarifyNode(graphId=_clGraphId, nodeId=_clNodeId);
            mutData = mutResult.reports[0] if mutResult.reports else {};
            if "graph" in mutData { currentGraph = mutData["graph"]; }
            if "score" in mutData {
                currentScore = mutData["score"];
                _clNewScore = currentScore["overall"] if "overall" in currentScore else _clPrevScore;
                applyScoreDelta(_clPrevScore, _clNewScore);
            }
            if "issues" in mutData { currentIssues = mutData["issues"]; }
            if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
            _clNodes = currentGraph["nodes"] if currentGraph and "nodes" in currentGraph else [];
            _clFound = None;
            _cli = 0;
            while _cli < len(_clNodes) {
                if _clNodes[_cli]["id"] == _clNodeId { _clFound = _clNodes[_cli]; break; }
                _cli = _cli + 1;
            }
            selectedNode = {_clFound};
        } except Exception { }
        isSaving = False;
    }

    def cancelEdit() -> None {
        editMode = "";
        editInputValue = "";
        sourceUrlValue = "";
        showConfirmDelete = False;
    }

    def handleEditInput(e: any) -> None {
        editInputValue = e.target.value;
    }

    def handleSourceUrlInput(e: any) -> None {
        sourceUrlValue = e.target.value;
    }

    def applyScoreDelta(prev_value: int, new_value: int) -> None {
        scoreDelta = new_value - prev_value;
        showScoreDelta = scoreDelta != 0;
        if showScoreDelta {
            setTimeout(lambda -> None {
                showScoreDelta = False;
                scoreDelta = 0;
            }, 2200);
        }
    }

    async def saveEdit() -> None {
        if not editInputValue.strip() or not selectedNode or not currentGraph { return; }
        isSaving = True;
        _seGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _seNodeId = selectedNode["id"];
        _seMode = editMode;
        _seContent = editInputValue.strip();
        _sePrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;

        _seDefendId = "";
        if _seMode == "address" {
            _seEdges = currentGraph["edges"] if "edges" in currentGraph else [];
            _sei = 0;
            while _sei < len(_seEdges) {
                _see = _seEdges[_sei];
                _seSrc = _see["source"] if "source" in _see else "";
                _seTyp = _see["type"] if "type" in _see else "";
                if _seSrc == _seNodeId and _seTyp == "CONTRADICTS" {
                    _seDefendId = _see["target"] if "target" in _see else "";
                    break;
                }
                _sei = _sei + 1;
            }
            if not _seDefendId { _seDefendId = _seNodeId; }
        }

        try {
            mutResult = None;
            if _seMode == "evidence" {
                _seSourceUrl = sourceUrlValue.strip() if sourceUrlValue else "";
                mutResult = await root spawn AddEvidenceToNode(
                    graphId=_seGraphId, nodeId=_seNodeId, evidenceContent=_seContent, sourceUrl=_seSourceUrl
                );
            } elif _seMode == "assumption" {
                mutResult = await root spawn AddAssumptionToNode(
                    graphId=_seGraphId, nodeId=_seNodeId, assumptionText=_seContent
                );
            } elif _seMode == "address" {
                mutResult = await root spawn AddAddressEdge(
                    graphId=_seGraphId,
                    defendNodeId=_seDefendId,
                    counterargNodeId=_seNodeId,
                    addressContent=_seContent
                );
            }
            if mutResult {
                mutData = mutResult.reports[0] if mutResult.reports else {};
                if "graph" in mutData { currentGraph = mutData["graph"]; }
                if "score" in mutData {
                    currentScore = mutData["score"];
                    _seNewScore = currentScore["overall"] if "overall" in currentScore else _sePrevScore;
                    applyScoreDelta(_sePrevScore, _seNewScore);
                }
                if "issues" in mutData { currentIssues = mutData["issues"]; }
                if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
                _seNodes = currentGraph["nodes"] if currentGraph and "nodes" in currentGraph else [];
                _seFound = None;
                _sefi = 0;
                while _sefi < len(_seNodes) {
                    if _seNodes[_sefi]["id"] == _seNodeId { _seFound = _seNodes[_sefi]; break; }
                    _sefi = _sefi + 1;
                }
                selectedNode = {_seFound};
            }
        } except Exception { }

        editMode = "";
        editInputValue = "";
        sourceUrlValue = "";
        isSaving = False;
    }

    async def handleDelete() -> None {
        if not currentGraph { return; }
        _delNodeId = selectedNode["id"] if selectedNode and "id" in selectedNode else "";
        if not _delNodeId { return; }
        isSaving = True;
        _delPrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        _delGraphId = currentGraph["id"] if "id" in currentGraph else "";

        try {
            mutResult = await root spawn DeleteNode(graphId=_delGraphId, nodeId=_delNodeId);
            mutData = mutResult.reports[0] if mutResult.reports else {};
            if "graph" in mutData { currentGraph = mutData["graph"]; }
            if "score" in mutData {
                currentScore = mutData["score"];
                _delNewScore = currentScore["overall"] if "overall" in currentScore else _delPrevScore;
                applyScoreDelta(_delPrevScore, _delNewScore);
            }
            if "issues" in mutData { currentIssues = mutData["issues"]; }
            if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
        } except Exception { }

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

        newAccepted: list = list(_acceptedTexts);
        newAccepted.append(ca_text);
        _acceptedTexts = newAccepted;

        isSaving = True;
        _acGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _acPrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;

        try {
            addResult = await root spawn AddCounterargumentNode(
                graphId=_acGraphId, targetNodeId=ca_target, counterargContent=ca_text
            );
            addData = addResult.reports[0] if addResult.reports else {};
            if "graph" in addData { currentGraph = addData["graph"]; }
            if "score" in addData {
                currentScore = addData["score"];
                _acNewScore = currentScore["overall"] if "overall" in currentScore else _acPrevScore;
                applyScoreDelta(_acPrevScore, _acNewScore);
            }
            if "issues" in addData { currentIssues = addData["issues"]; }
            if "nextActions" in addData { currentNextActions = addData["nextActions"]; }
        } except Exception { }

        isSaving = False;
    }

    async def handleExpandBranch() -> None {
        if not selectedNode or not currentGraph { return; }
        isSaving = True;
        _ebGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _ebNodeId = selectedNode["id"];
        _ebPrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        try {
            mutResult = await root spawn ExpandBranch(graphId=_ebGraphId, nodeId=_ebNodeId);
            mutData = mutResult.reports[0] if mutResult.reports else {};
            if "graph" in mutData { currentGraph = mutData["graph"]; }
            if "score" in mutData {
                currentScore = mutData["score"];
                _ebNewScore = currentScore["overall"] if "overall" in currentScore else _ebPrevScore;
                applyScoreDelta(_ebPrevScore, _ebNewScore);
            }
            if "issues" in mutData { currentIssues = mutData["issues"]; }
            if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
            # Re-select same node
            _ebNodes = currentGraph["nodes"] if currentGraph and "nodes" in currentGraph else [];
            _ebFound = None;
            _ebi = 0;
            while _ebi < len(_ebNodes) {
                if _ebNodes[_ebi]["id"] == _ebNodeId { _ebFound = _ebNodes[_ebi]; break; }
                _ebi = _ebi + 1;
            }
            selectedNode = {_ebFound};
        } except Exception { }
        isSaving = False;
    }

    if not currentGraph or not currentScore {
        return (
            <div className="rs-loading">
                <p>Loading argument map...</p>
            </div>
        );
    }

    # --- Pre-compute all values before JSX ---

    overall = currentScore["overall"] if "overall" in currentScore else 0;
    scoreColor = "#16a34a" if overall >= 70 else ("#ca8a04" if overall >= 50 else "#dc2626");

    delta_text = "";
    delta_color = "#16a34a";
    if showScoreDelta and scoreDelta != 0 {
        delta_sign = "+" if scoreDelta > 0 else "";
        delta_text = f"({delta_sign}{scoreDelta})";
        delta_color = "#16a34a" if scoreDelta > 0 else "#dc2626";
    }

    support_val = currentScore["support"] if "support" in currentScore else 0;
    premise_val = currentScore["premise"] if "premise" in currentScore else 0;
    coherence_val = currentScore["coherence"] if "coherence" in currentScore else 0;
    counter_val = currentScore["counterargument"] if "counterargument" in currentScore else (
        currentScore["consistency"] if "consistency" in currentScore else 0
    );
    support_bar_color = "#10b981" if support_val >= 70 else ("#f59e0b" if support_val >= 50 else "#ef4444");
    premise_bar_color = "#10b981" if premise_val >= 70 else ("#f59e0b" if premise_val >= 50 else "#ef4444");
    coherence_bar_color = "#10b981" if coherence_val >= 70 else ("#f59e0b" if coherence_val >= 50 else "#ef4444");
    counter_bar_color = "#10b981" if counter_val >= 70 else ("#f59e0b" if counter_val >= 50 else "#ef4444");

    typeLegend = [
        {"key": "THESIS", "color": "#7c3aed", "bg": "#ede9fe", "label": "Thesis"},
        {"key": "CLAIM", "color": "#9f7aea", "bg": "#e8e0fc", "label": "Claim"},
        {"key": "EVIDENCE", "color": "#10b981", "bg": "#d1fae5", "label": "Evidence"},
        {"key": "ASSUMPTION", "color": "#f59e0b", "bg": "#fef3c7", "label": "Assumption"},
        {"key": "COUNTERARGUMENT", "color": "#ef4444", "bg": "#fee2e2", "label": "Counter"}
    ];

    sel_type = selectedNode["type"] if selectedNode and "type" in selectedNode else "CLAIM";
    sel_content = selectedNode["content"] if selectedNode and "content" in selectedNode else "";
    sel_confidence = selectedNode["confidence"] if selectedNode and "confidence" in selectedNode else 0.5;
    sel_conf_val = sel_confidence if sel_confidence else 0.5;
    sel_str_color = "#16a34a" if sel_conf_val >= 0.7 else ("#ca8a04" if sel_conf_val >= 0.5 else "#dc2626");
    sel_str_bg = "rgba(34,197,94,0.1)" if sel_conf_val >= 0.7 else ("rgba(250,204,21,0.15)" if sel_conf_val >= 0.5 else "rgba(239,68,68,0.1)");

    typeColorMap = {
        "THESIS": "#7c3aed", "CLAIM": "#9f7aea", "EVIDENCE": "#10b981", "ASSUMPTION": "#f59e0b",
        "COUNTERARGUMENT": "#ef4444"
    };
    sel_type_color = typeColorMap[sel_type] if sel_type in typeColorMap else "#9f7aea";

    sel_node_score = selectedNode["nodeScore"] if selectedNode and "nodeScore" in selectedNode else -1;
    sel_has_node_score = sel_node_score >= 0;

    sel_is_evidence = sel_type == "EVIDENCE";
    sel_ev_category = "";
    sel_assumptions: list = [];
    sel_has_assumptions = False;
    sel_source_url = "";
    if selectedNode {
        sel_ev_category = selectedNode["evidence_category"] if "evidence_category" in selectedNode else "";
        sel_assumptions = selectedNode["assumptions"] if "assumptions" in selectedNode else [];
        sel_has_assumptions = len(sel_assumptions) > 0;
        sel_source_url = selectedNode["sourceUrl"] if "sourceUrl" in selectedNode else "";
    }
    sel_has_source = len(sel_source_url) > 0 if sel_source_url else False;
    sel_ev_cat_display = sel_ev_category.replace("_", " ") if sel_ev_category else "logical reasoning";

    sel_more_info = "";
    if selectedNode {
        sel_more_info = selectedNode["moreInfo"] if "moreInfo" in selectedNode else "";
    }
    sel_has_more_info = len(sel_more_info) > 0 if sel_more_info else False;

    edit_label = "Add Evidence";
    edit_placeholder = "Add a fact, statistic, study, or expert quote...";
    if editMode == "assumption" {
        edit_label = "Add Missing Assumption";
        edit_placeholder = "State the hidden assumption that makes this claim valid...";
    } elif editMode == "address" {
        edit_label = "Address This Counterargument";
        edit_placeholder = "How would you respond to this counterargument? Provide evidence or reasoning...";
    }

    _allNodeIssues: list = [];
    if selectedNode and currentIssues {
        sel_id = selectedNode["id"];
        _ii = 0;
        while _ii < len(currentIssues) {
            _iss = currentIssues[_ii];
            _nid = _iss["nodeId"] if "nodeId" in _iss else "";
            if _nid == sel_id { _allNodeIssues.append(_iss); }
            _ii = _ii + 1;
        }
    }
    nodeIssues: list = [];
    _maxIss = 3;
    if len(_allNodeIssues) < _maxIss { _maxIss = len(_allNodeIssues); }
    _li = 0;
    while _li < _maxIss {
        nodeIssues.append(_allNodeIssues[_li]);
        _li = _li + 1;
    }
    has_node_issues = len(nodeIssues) > 0;

    def makeFixHandler(mode: str) -> any {
        return lambda -> None { startEdit(mode); };
    }

    nodeIssueElements: list = [];
    _ni = 0;
    while _ni < len(nodeIssues) {
        iss = nodeIssues[_ni];
        iss_type = iss["type"] if "type" in iss else "";
        fix_mode = "evidence";
        if iss_type == "assumption_heavy" or iss_type == "missing_premise" {
            fix_mode = "assumption";
        } elif iss_type == "contradiction" or iss_type == "unresolved_contradiction" {
            fix_mode = "address";
        } elif iss_type == "vague_language" or iss_type == "weak_inference" {
            fix_mode = "clarify";
        } elif iss_type == "orphan_node" {
            fix_mode = "delete";
        }
        fix_click_fn = makeFixHandler(fix_mode);
        nodeIssueElements.append(
            <div key={iss["id"]} className="rs-issue-card">
                <div className="rs-issue-inner">
                    <div className="rs-issue-body">
                        <div className="rs-issue-description">{iss["description"]}</div>
                        <div className="rs-issue-suggestion">{iss["suggestedAction"]}</div>
                    </div>
                    <button onClick={fix_click_fn} className="rs-fix-btn">Fix →</button>
                </div>
            </div>
        );
        _ni = _ni + 1;
    }

    assumptionElements: list = [];
    _ai = 0;
    while _ai < len(sel_assumptions) {
        assumption = sel_assumptions[_ai];
        assumptionElements.append(
            <div key={str(_ai)} className="rs-assumption-item">⚠️ {assumption}</div>
        );
        _ai = _ai + 1;
    }

    def makeIssueClickHandler(nodeId: str) -> any {
        return lambda -> None { handleIssueClick(nodeId); };
    }

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
            <div key={iss["id"]} className="rs-issue-card-default" onClick={iss_click_fn}>
                <div className="rs-severity-row">
                    <span className="rs-severity-badge"
                        style={{"background": sev_bg, "color": sev_color}}>
                        {iss["severity"]}
                    </span>
                </div>
                <div className="rs-issue-title">{iss["description"]}</div>
            </div>
        );
        _ti = _ti + 1;
    }

    # Build next 3 actions in order (backend-ranked)
    nextActionElements: list = [];
    next_actions_safe: list = list(currentNextActions) if currentNextActions else [];
    if len(next_actions_safe) == 0 {
        _fallback_count = len(issues_safe);
        if _fallback_count > 3 { _fallback_count = 3; }
        _fai = 0;
        while _fai < _fallback_count {
            _fi = issues_safe[_fai];
            next_actions_safe.append({
                "nodeId": _fi["nodeId"] if "nodeId" in _fi else "",
                "action": _fi["suggestedAction"] if "suggestedAction" in _fi else "Fix this issue",
                "issueType": _fi["type"] if "type" in _fi else "",
                "rank": _fai + 1,
                "expectedLift": _fi["estimatedLift"] if "estimatedLift" in _fi else 0
            });
            _fai = _fai + 1;
        }
    }
    next_count = len(next_actions_safe);
    if next_count > 3 { next_count = 3; }
    _na = 0;
    while _na < next_count {
        next_issue = next_actions_safe[_na];
        next_node_id = next_issue["nodeId"] if "nodeId" in next_issue else "";
        next_lift = next_issue["expectedLift"] if "expectedLift" in next_issue else 0;
        next_click_fn = makeIssueClickHandler(next_node_id);
        nextActionElements.append(
            <div key={f"next_{str(_na)}"} className="rs-next-action-item">
                <div className="rs-next-action-rank">{str(_na + 1)}</div>
                <div className="rs-next-action-body">
                    <div className="rs-next-action-text">
                        {next_issue["action"] if "action" in next_issue else "Fix this issue"}
                        {(
                            <span className="rs-next-action-lift">{"+" + str(next_lift) + " est"}</span>
                        ) if next_lift > 0 else None}
                    </div>
                    <button onClick={next_click_fn} className="rs-next-action-btn">Go to node →</button>
                </div>
            </div>
        );
        _na = _na + 1;
    }

    # Filter out accepted counterargs to get visible suggestions
    visibleCounterargs: list = [];
    _vci = 0;
    while _vci < len(suggestedCounterargs) {
        _vc = suggestedCounterargs[_vci];
        _vc_text = _vc["text"] if "text" in _vc else "";
        _is_accepted = False;
        _aci = 0;
        while _aci < len(_acceptedTexts) {
            if _acceptedTexts[_aci] == _vc_text { _is_accepted = True; break; }
            _aci = _aci + 1;
        }
        if not _is_accepted { visibleCounterargs.append(_vc); }
        _vci = _vci + 1;
    }

    def makeAcceptHandler(caItem: dict) -> any {
        return lambda -> None { handleAcceptCounterarg(caItem); };
    }

    counterargElements: list = [];
    _cai = 0;
    while _cai < len(visibleCounterargs) {
        ca = visibleCounterargs[_cai];
        ca_text = ca["text"] if "text" in ca else "";
        ca_target = ca["target_node"] if "target_node" in ca else "";
        ca_severity = ca["severity"] if "severity" in ca else "medium";
        ca_sev_color = "#ef4444" if ca_severity == "high" else "#f59e0b";
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
            <div key={str(_cai)} className="rs-counter-card">
                <div className="rs-counter-header">
                    <span className="rs-counter-severity"
                        style={{"color": ca_sev_color}}>{ca_severity}</span>
                    <span className="rs-counter-target">targets: {ca_target_short}</span>
                </div>
                <div className="rs-counter-text">{ca_text}</div>
                <button onClick={ca_accept_fn} className="rs-accept-btn">Add to Graph</button>
            </div>
        );
        _cai = _cai + 1;
    }
    has_counterarg_suggestions = len(counterargElements) > 0;

    ghostNodes: list = [];
    ghostEdges: list = [];
    _gi = 0;
    while _gi < len(visibleCounterargs) {
        gca = visibleCounterargs[_gi];
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

    saving_overlay_display = "flex" if isSaving else "none";

    show_add_evidence = sel_type == "CLAIM" or sel_type == "THESIS";
    show_acknowledge_assumption = sel_type == "CLAIM" or sel_type == "THESIS";
    show_add_counter = sel_type == "CLAIM" or sel_type == "THESIS";
    show_address = sel_type == "COUNTERARGUMENT";
    show_expand = sel_type == "CLAIM" or sel_type == "THESIS";
    show_source_input = editMode == "evidence";

    return (
        <div className="rs-wrapper">

            <Header navigate={navigate} screen="review" title="Review Map" />

            <div className="rs-legend-bar">
                <div className="rs-legend-section">
                    <span className="rs-legend-label">Type</span>
                    {typeLegend.map(lambda item -> any {
                        return (
                            <div key={item["key"]} className="rs-legend-type-item">
                                <div className="rs-legend-type-dot"
                                    style={{"background": item["bg"], "border": f"2px solid {item['color']}"}}></div>
                                <span className="rs-legend-type-label"
                                    style={{"color": item["color"]}}>{item["label"]}</span>
                            </div>
                        );
                    })}
                </div>
                <div className="rs-legend-section">
                    <span className="rs-legend-label">Strength</span>
                    <div className="rs-legend-type-item">
                        <div className="rs-strength-dot rs-strength-dot-good"></div>
                        <span className="rs-legend-value">70+</span>
                    </div>
                    <div className="rs-legend-type-item">
                        <div className="rs-strength-dot rs-strength-dot-warning"></div>
                        <span className="rs-legend-value">50-69</span>
                    </div>
                    <div className="rs-legend-type-item">
                        <div className="rs-strength-dot rs-strength-dot-bad"></div>
                        <span className="rs-legend-value">{"<50"}</span>
                    </div>
                </div>
                <div className="rs-legend-section">
                    <span className="rs-legend-label">Links</span>
                    <div className="rs-legend-type-item">
                        <div className="rs-edge-line rs-edge-supports"></div>
                        <span className="rs-edge-label rs-edge-label-supports">supports</span>
                    </div>
                    <div className="rs-legend-type-item">
                        <div className="rs-edge-line rs-edge-contradicts"></div>
                        <span className="rs-edge-label rs-edge-label-contradicts">contradicts</span>
                    </div>
                    <div className="rs-legend-type-item">
                        <div className="rs-edge-line rs-edge-depends-on"></div>
                        <span className="rs-edge-label rs-edge-label-depends-on">depends_on</span>
                    </div>
                    <div className="rs-legend-type-item">
                        <div className="rs-edge-line rs-edge-addresses"></div>
                        <span className="rs-edge-label rs-edge-label-addresses">addresses</span>
                    </div>
                </div>
            </div>

            <div className="rs-body">

                <div className="rs-graph-area">
                    {(
                        <button className="rs-branch-exit-btn" onClick={toggleBranch}>
                            Editing branch - Click to exit
                        </button>
                    ) if focusBranch else None}

                    <div className="rs-graph-wrapper">
                        <ArgumentGraphView
                            nodes={allNodes}
                            edges={allEdges}
                            onNodeClick={handleNodeClick}
                            selectedNodeId={selectedNode["id"] if selectedNode else None}
                            focusBranch={focusBranch}
                            onGhostAccept={handleAcceptCounterarg}
                        />
                    </div>

                    <div className="rs-statusbar">
                        <span className="rs-statusbar-label">Sources</span>
                        <span className="rs-statusbar-text">
                            {node_count_str} nodes - {edge_count_str} edges
                        </span>
                    </div>
                </div>

                {(
                    <div className="rs-selected-panel">

                        <div className="rs-saving-overlay"
                            style={{"display": saving_overlay_display}}>
                            <div className="rs-saving-indicator">Saving...</div>
                        </div>

                        <div className="rs-panel-header">
                            <div className="rs-panel-header-row">
                                <div className="rs-panel-header-left">
                                    <span className="rs-panel-type-label"
                                        style={{"color": sel_type_color}}>{sel_type}</span>
                                    <span className="rs-strength-badge"
                                        style={{"background": sel_str_bg, "color": sel_str_color,
                                                "border": f"1px solid {sel_str_color}"}}>
                                        {str(int(sel_conf_val * 100))}%
                                    </span>
                                </div>
                                <button className="rs-panel-close-btn" onClick={closePanel}>✕</button>
                            </div>
                            <h3 className="rs-panel-node-title">{sel_content}</h3>
                        </div>

                        <div className="rs-panel-scroll">

                            <div className="rs-panel-section">
                                <div className="rs-section-heading rs-section-heading-issues">
                                    <span className="rs-section-dot rs-section-dot-issues"></span>
                                    Issues
                                </div>
                                {(
                                    <div>{nodeIssueElements}</div>
                                ) if has_node_issues else (
                                    <div className="rs-well-supported">Well-supported ✓</div>
                                )}
                            </div>

                            <div className="rs-panel-section">
                                <div className="rs-section-heading rs-section-heading-actions">
                                    <span className="rs-section-dot rs-section-dot-actions"></span>
                                    Quick Actions
                                </div>
                                <div className="rs-actions-row">
                                    {(
                                        <button className="rs-action-btn rs-action-btn-default"
                                            onClick={lambda -> None { startEdit("evidence"); }}>
                                            📊 Add Evidence
                                        </button>
                                    ) if show_add_evidence else None}
                                    {(
                                        <button className="rs-action-btn rs-action-btn-default"
                                            onClick={lambda -> None { startEdit("assumption"); }}>
                                            🔗 Add Assumption
                                        </button>
                                    ) if show_acknowledge_assumption else None}
                                    {(
                                        <button className="rs-action-btn rs-action-btn-default"
                                            onClick={lambda -> None { startEdit("counter"); }}>
                                            ⚔️ Counter
                                        </button>
                                    ) if show_add_counter else None}
                                    {(
                                        <button className="rs-action-btn rs-action-btn-respond"
                                            onClick={lambda -> None { startEdit("address"); }}>
                                            💬 Respond
                                        </button>
                                    ) if show_address else None}
                                    {(
                                        <button className="rs-action-btn rs-action-btn-expand"
                                            onClick={handleExpandBranch}>
                                            🌿 Expand
                                        </button>
                                    ) if show_expand else None}
                                    <button className="rs-action-btn rs-action-btn-default"
                                        onClick={lambda -> None { startEdit("clarify"); }}>
                                        ✏️ Clarify
                                    </button>
                                    <button className="rs-action-btn rs-action-btn-delete"
                                        onClick={lambda -> None { startEdit("delete"); }}>
                                        🗑️ Delete
                                    </button>
                                </div>
                            </div>

                            {(
                                <div className="rs-edit-box">
                                    <div className="rs-edit-label">{edit_label}</div>
                                    <textarea className="rs-edit-textarea"
                                        value={editInputValue}
                                        onChange={handleEditInput}
                                        placeholder={edit_placeholder} />
                                    {(
                                        <input type="text"
                                            className="rs-edit-source-input"
                                            value={sourceUrlValue}
                                            onChange={handleSourceUrlInput}
                                            placeholder="Source URL (optional) — e.g. https://example.com/study" />
                                    ) if show_source_input else None}
                                    <div className="rs-edit-buttons">
                                        <button className="rs-save-btn" onClick={saveEdit}>Save</button>
                                        <Button label="Cancel" onClick={cancelEdit} variant="secondary" />
                                    </div>
                                </div>
                            ) if editMode else None}

                            {(
                                <div className="rs-delete-box">
                                    <div className="rs-delete-title">Delete this node?</div>
                                    <div className="rs-delete-warning">
                                        This will remove the node and all its connections. This cannot be undone.
                                    </div>
                                    <div className="rs-edit-buttons">
                                        <button className="rs-confirm-delete-btn"
                                            onClick={handleDelete}>Delete</button>
                                        <Button label="Cancel" onClick={cancelEdit} variant="secondary" />
                                    </div>
                                </div>
                            ) if showConfirmDelete else None}

                            {(
                                <div className="rs-panel-section">
                                    <div className="rs-section-heading rs-section-heading-assumptions">
                                        <span className="rs-section-dot rs-section-dot-assumptions"></span>
                                        Assumptions
                                    </div>
                                    {assumptionElements}
                                </div>
                            ) if sel_has_assumptions else None}

                            {(
                                <div className="rs-panel-section">
                                    <div className="rs-section-heading rs-section-heading-info">
                                        <span className="rs-section-dot rs-section-dot-info"></span>
                                        More Information
                                    </div>
                                    <div className="rs-more-info-box">{sel_more_info}</div>
                                </div>
                            ) if sel_has_more_info else None}

                            {(
                                <div className="rs-panel-section">
                                    <div className="rs-section-heading rs-section-heading-evidence">
                                        <span className="rs-section-dot rs-section-dot-evidence"></span>
                                        Evidence Details
                                    </div>
                                    <div className="rs-evidence-box">
                                        <div className="rs-evidence-row">
                                            <span className="rs-evidence-key">Category</span>
                                            <span className="rs-evidence-value">{sel_ev_cat_display}</span>
                                        </div>
                                        <div className="rs-evidence-row">
                                            <span className="rs-evidence-key">Quality Score</span>
                                            <span style={{"fontWeight": "600", "color": sel_str_color}}>
                                                {str(sel_node_score)}%
                                            </span>
                                        </div>
                                        {(
                                            <div className="rs-source-divider">
                                                <div className="rs-source-row">
                                                    <span className="rs-evidence-key">Source</span>
                                                    <a href={sel_source_url} target="_blank"
                                                        rel="noopener noreferrer"
                                                        className="rs-source-link">
                                                        {sel_source_url}
                                                    </a>
                                                </div>
                                            </div>
                                        ) if sel_has_source else None}
                                    </div>
                                </div>
                            ) if sel_is_evidence else None}

                            {(
                                <div className="rs-panel-section">
                                    <div className="rs-section-heading rs-section-heading-score">
                                        <span className="rs-section-dot rs-section-dot-score"></span>
                                        Node Score
                                    </div>
                                    <div className="rs-node-score-box">
                                        <div className="rs-node-score-number"
                                            style={{"color": sel_str_color}}>
                                            {str(sel_node_score)}
                                        </div>
                                        <div className="rs-node-score-label">Node Quality</div>
                                    </div>
                                </div>
                            ) if sel_has_node_score else None}

                        </div>
                    </div>
                ) if selectedNode else (
                    <div className="rs-default-panel">

                        <div className="rs-saving-overlay"
                            style={{"display": saving_overlay_display}}>
                            <div className="rs-saving-indicator">Saving...</div>
                        </div>

                        <div className="rs-default-scroll">
                            <div className="rs-default-section-header">
                                <span>📈</span>
                                <span className="rs-default-section-title">Reasoning Score</span>
                            </div>

                            <div className="rs-score-block">
                                <div className="rs-score-big"
                                    style={{"color": scoreColor}}>{overall}</div>
                                <div className="rs-score-sub">out of 100</div>
                                <div className="rs-score-bar">
                                    <div className="rs-score-bar-fill"
                                        style={{"width": f"{overall}%", "background": scoreColor}}></div>
                                </div>
                                {(
                                    <div className="rs-score-delta-big"
                                        style={{"color": delta_color}}>{delta_text}</div>
                                ) if delta_text else None}
                            </div>

                            <div className="rs-breakdown-item">
                                <div className="rs-breakdown-row">
                                    <span className="rs-breakdown-label">Support Quality (30%)</span>
                                    <span className="rs-breakdown-value">{support_val}%</span>
                                </div>
                                <div className="rs-breakdown-bar">
                                    <div className="rs-breakdown-bar-fill"
                                        style={{"width": f"{support_val}%", "background": support_bar_color}}></div>
                                </div>
                            </div>
                            <div className="rs-breakdown-item">
                                <div className="rs-breakdown-row">
                                    <span className="rs-breakdown-label">Logical Soundness (25%)</span>
                                    <span className="rs-breakdown-value">{premise_val}%</span>
                                </div>
                                <div className="rs-breakdown-bar">
                                    <div className="rs-breakdown-bar-fill"
                                        style={{"width": f"{premise_val}%", "background": premise_bar_color}}></div>
                                </div>
                            </div>
                            <div className="rs-breakdown-item">
                                <div className="rs-breakdown-row">
                                    <span className="rs-breakdown-label">Coherence (20%)</span>
                                    <span className="rs-breakdown-value">{coherence_val}%</span>
                                </div>
                                <div className="rs-breakdown-bar">
                                    <div className="rs-breakdown-bar-fill"
                                        style={{"width": f"{coherence_val}%", "background": coherence_bar_color}}></div>
                                </div>
                            </div>
                            <div className="rs-breakdown-item rs-breakdown-item-last">
                                <div className="rs-breakdown-row">
                                    <span className="rs-breakdown-label">Counterargument Handling (25%)</span>
                                    <span className="rs-breakdown-value">{counter_val}%</span>
                                </div>
                                <div className="rs-breakdown-bar">
                                    <div className="rs-breakdown-bar-fill"
                                        style={{"width": f"{counter_val}%", "background": counter_bar_color}}></div>
                                </div>
                            </div>

                            <div className="rs-default-section-header">
                                <span>⚠️</span>
                                <span className="rs-default-section-title">Top Issues</span>
                            </div>
                            <p className="rs-panel-hint">Click on a node to fix it</p>
                            {(
                                <div>{topIssueElements}</div>
                            ) if len(currentIssues) > 0 else (
                                <div className="rs-no-issues-card">
                                    No major issues found! Great work.
                                </div>
                            )}

                            <div className="rs-next-actions-section">
                                <div className="rs-default-section-header">
                                    <span>🧭</span>
                                    <span className="rs-default-section-title">Next 3 Actions</span>
                                </div>
                                {(
                                    <div>{nextActionElements}</div>
                                ) if len(nextActionElements) > 0 else (
                                    <div className="rs-no-issues-card">
                                        Ready to export. No urgent actions found.
                                    </div>
                                )}
                            </div>

                            {(
                                <div className="rs-counterargs-section">
                                    <div className="rs-default-section-header">
                                        <span>⚔️</span>
                                        <span className="rs-default-section-title">
                                            Consider These Counterarguments
                                        </span>
                                    </div>
                                    <p className="rs-panel-hint">
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
