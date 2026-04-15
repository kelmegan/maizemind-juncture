"""MaizeMind - Review Screen with inline editing workshop, ghost nodes, and score delta."""

import from "@jac/runtime" { useNavigate, useLocation }
import from react { useContext }
import from ..screens.AppContext { getAppContext }
import from ..components.ArgumentGraphView { ArgumentGraphView }
import from ..components.Button { Button }
import from ..components.Header { Header }

def:pub ReviewScreen(props: any) -> JsxElement {
    nav = useNavigate();
    location = useLocation();
    _AppCtx = getAppContext();
    ctx = useContext(_AppCtx);

    loc_state = location.state if location.state else {};

    has currentGraph: dict = None,
        currentScore: dict = None,
        currentIssues: list = [],
        currentNextActions: list = [],
        selectedNode: dict | None = None,
        focusBranch: str = None,
        editMode: str = "",
        editInputValue: str = "",
        sourceUrlValue: str = "",
        isSaving: bool = False,
        prevScore: int = 0,
        scoreDelta: int = 0,
        showScoreDelta: bool = False,
        showConfirmDelete: bool = False,
        addedAsEvidenceMap: dict = {},
        investigatedAssumptions: list = [],
        investigateResults: list = [],
        investigateLoading: bool = False,
        suggestedCounterargs: list = [],
        dismissedCounterargTexts: list = [],
        undoDelete: dict | None = None,
        showAllAssumptions: bool = False,
        tutorialStep: int = 1,
        showTutorial: bool = True,
        thesisToast: str = "";

    async def loadGraphData() -> None {
        graph_id = loc_state["graphId"] if "graphId" in loc_state else ctx.cachedGraphId;
        if not graph_id { return; }
        try {
            result = await root spawn GetGraphWithScoring(graphId=graph_id);
            data = result["reports"][0] if result["reports"] else {};
            if "graph" in data { currentGraph = data["graph"]; }
            if "score" in data { currentScore = data["score"]; }
            if "issues" in data { currentIssues = data["issues"]; }
            if "nextActions" in data { currentNextActions = data["nextActions"]; }
        } except Exception as e {
            print(f"ReviewScreen load error: {e}");
        }
        if "suggestedCounterarguments" in loc_state and loc_state["suggestedCounterarguments"] {
            suggestedCounterargs = loc_state["suggestedCounterarguments"];
        } elif ctx.cachedCounterargSuggestions {
            suggestedCounterargs = ctx.cachedCounterargSuggestions;
        }
        pushUpdate();
    }

    can with entry {
        loadGraphData();
    }

    def pushUpdate() -> None {
        if currentGraph {
            graph_id = currentGraph["id"] if "id" in currentGraph else "";
            ctx.setGraphCache(graph_id, suggestedCounterargs);
        }
    }

    def handleNodeClick(node_data: any) -> None {
        selectedNode = node_data;
        focusBranch = None;
        editMode = "";
        editInputValue = "";
        showConfirmDelete = False;
        showScoreDelta = False;
        showAllAssumptions = False;
        investigateResults = [];
        investigateLoading = False;
        node_id = node_data["id"] if node_data and "id" in node_data else "";
        if node_id in addedAsEvidenceMap {
            addedAsEvidenceMap[node_id] = True;   # trust the map — skip the graph search
        } else {
            node_more_info = node_data["moreInfo"] if node_data and "moreInfo" in node_data else "";
            if node_more_info and currentGraph {
                _graph_nodes = currentGraph["nodes"] if "nodes" in currentGraph else [];
                _already = False;
                for _gn in _graph_nodes {
                    if _gn["type"] == "EVIDENCE" and "content" in _gn and _gn["content"] == node_more_info {
                        _already = True;
                        break;
                    }
                }
                if _already { addedAsEvidenceMap[node_id] = True; }
            } else {
                addedAsEvidenceMap[node_id] = False;
            }
        }
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
        investigateResults = [];
        investigateLoading = False;
        if mode == "delete" {
            editMode = "";
            showConfirmDelete = True;
            return;
        }
        if mode == "counter" {
            handleGenerateCounter();
            return;
        }
        if mode == "investigate" {
            handleInvestigateNode();
            return;
        }
        if mode == "auto_fix" {
            handleAutoFix();
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
            mutData = mutResult["reports"][0] if mutResult["reports"] else {};
            if "graph" in mutData { currentGraph = mutData["graph"]; }
            if "score" in mutData {
                currentScore = mutData["score"];
                _gcNewScore = currentScore["overall"] if "overall" in currentScore else _gcPrevScore;
                applyScoreDelta(_gcPrevScore, _gcNewScore);
            }
            if "issues" in mutData { currentIssues = mutData["issues"]; }
            if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
            _freshGraph = mutData["graph"] if "graph" in mutData else currentGraph;
            _gcNodes = _freshGraph["nodes"] if _freshGraph and "nodes" in _freshGraph else [];
            _gcFound = None;
            _gci = 0;
            while _gci < len(_gcNodes) {
                if _gcNodes[_gci]["id"] == _gcNodeId { _gcFound = _gcNodes[_gci]; break; }
                _gci = _gci + 1;
            }
            selectedNode = _gcFound;
        } except Exception { }
        isSaving = False;
        pushUpdate();
    }

    async def handleInvestigateNode() -> None {
        if not selectedNode or not currentGraph { return; }
        investigateLoading = True;
        investigateResults = [];
        editMode = "";
        _invGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _invNodeId = selectedNode["id"];
        try {
            mutResult = await root spawn InvestigateNode(graphId=_invGraphId, nodeId=_invNodeId);
            mutData = mutResult["reports"][0] if mutResult["reports"] else {};
            if "error" in mutData {
                print(f"Investigate error: {mutData['error']}");
            }
            if "already_sourced" in mutData {
                _as_msg = mutData["message"] if "message" in mutData else "All relevant sources already used.";
                investigateResults = [{"title": "All Sources Used", "summary": _as_msg, "url": "", "snippet": ""}];
            } elif "wikiResults" in mutData {
                investigateResults = mutData["wikiResults"];
            }
        } except Exception { }
        investigateLoading = False;
    }

    async def handlePickInvestigateResult(resultIndex: int, pickedTitle: str, pickedUrl: str) -> None {
        if not selectedNode or not currentGraph { return; }
        isSaving = True;
        _pirGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _pirNodeId = selectedNode["id"];
        _pirPrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        try {
            mutResult = await root spawn InvestigateNode(
                graphId=_pirGraphId, nodeId=_pirNodeId,
                selectedResultIndex=resultIndex, addAsEvidence=True,
                selectedTitle=pickedTitle, selectedUrl=pickedUrl
            );
            mutData = mutResult["reports"][0] if mutResult["reports"] else {};
            if "graph" in mutData { currentGraph = mutData["graph"]; }
            if "score" in mutData {
                currentScore = mutData["score"];
                _pirNewScore = currentScore["overall"] if "overall" in currentScore else _pirPrevScore;
                applyScoreDelta(_pirPrevScore, _pirNewScore);
            }
            if "issues" in mutData { currentIssues = mutData["issues"]; }
            if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
            _freshGraph = mutData["graph"] if "graph" in mutData else currentGraph;
            _pirNodes = _freshGraph["nodes"] if _freshGraph and "nodes" in _freshGraph else [];
            _pirFound = None;
            _piri = 0;
            while _piri < len(_pirNodes) {
                if _pirNodes[_piri]["id"] == _pirNodeId { _pirFound = _pirNodes[_piri]; break; }
                _piri = _piri + 1;
            }
            selectedNode = _pirFound;
        } except Exception { }
        investigateResults = [];
        isSaving = False;
        pushUpdate();
    }

    def makePickResultHandler(idx: int, title: str, url: str) -> any {
        return lambda -> None { handlePickInvestigateResult(idx, title, url); };
    }

    def handleInvestigateAssumption(assumption: str) -> None {
        investigatedAssumptions = investigatedAssumptions + [assumption];
        handleInvestigateNode();
    }

    def makeInvestigateAssumptionHandler(assumption: str) -> any {
        return lambda -> None { handleInvestigateAssumption(assumption); };
    }

    async def handleAutoFix() -> None {
        if not selectedNode or not currentGraph { return; }
        isSaving = True;
        _afGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _afNodeId = selectedNode["id"];
        _afPrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        try {
            mutResult = await root spawn InvestigateNode(graphId=_afGraphId, nodeId=_afNodeId, addAsEvidence=True);
            mutData = mutResult["reports"][0] if mutResult["reports"] else {};
            if "graph" in mutData { currentGraph = mutData["graph"]; }
            if "score" in mutData {
                currentScore = mutData["score"];
                _afNewScore = currentScore["overall"] if "overall" in currentScore else _afPrevScore;
                applyScoreDelta(_afPrevScore, _afNewScore);
            }
            if "issues" in mutData { currentIssues = mutData["issues"]; }
            if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
            _freshGraph = mutData["graph"] if "graph" in mutData else currentGraph;
            _afNodes = _freshGraph["nodes"] if _freshGraph and "nodes" in _freshGraph else [];
            _afFound = None;
            _afi = 0;
            while _afi < len(_afNodes) {
                if _afNodes[_afi]["id"] == _afNodeId { _afFound = _afNodes[_afi]; break; }
                _afi = _afi + 1;
            }
            selectedNode = _afFound;
        } except Exception { }
        isSaving = False;
        addedAsEvidenceMap[_afNodeId] = True;
        pushUpdate();
    }

    async def handleAddAsEvidence() -> None {
        if not selectedNode or not currentGraph { return; }
        _aeMoreInfo = selectedNode["moreInfo"] if "moreInfo" in selectedNode else "";
        _aeSourceUrl = selectedNode["sourceUrl"] if "sourceUrl" in selectedNode else "";
        if not _aeMoreInfo { return; }
        isSaving = True;
        _aeGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _aeNodeId = selectedNode["id"];
        _aePrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        try {
            mutResult = await root spawn AddEvidenceToNode(
                graphId=_aeGraphId, nodeId=_aeNodeId,
                evidenceContent=_aeMoreInfo, sourceUrl=_aeSourceUrl
            );
            mutData = mutResult["reports"][0] if mutResult["reports"] else {};
            if "graph" in mutData { currentGraph = mutData["graph"]; }
            if "score" in mutData {
                currentScore = mutData["score"];
                _aeNewScore = currentScore["overall"] if "overall" in currentScore else _aePrevScore;
                applyScoreDelta(_aePrevScore, _aeNewScore);
            }
            if "issues" in mutData { currentIssues = mutData["issues"]; }
            if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
            _freshGraph = mutData["graph"] if "graph" in mutData else currentGraph;
            _aeNodes = _freshGraph["nodes"] if _freshGraph and "nodes" in _freshGraph else [];
            _aeFound = None;
            _aei = 0;
            while _aei < len(_aeNodes) {
                if _aeNodes[_aei]["id"] == _aeNodeId { _aeFound = _aeNodes[_aei]; break; }
                _aei = _aei + 1;
            }
            selectedNode = _aeFound;
        } except Exception { }
        isSaving = False;
        addedAsEvidenceMap[_aeNodeId] = True;
        pushUpdate();
    }

    def cancelEdit() -> None {
        editMode = "";
        editInputValue = "";
        sourceUrlValue = "";
        showConfirmDelete = False;
        investigateResults = [];
        investigateLoading = False;
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
            if _seMode == "evidence" or _seMode == "respond" {
                _seSourceUrl = sourceUrlValue.strip() if sourceUrlValue else "";
                mutResult = await root spawn AddEvidenceToNode(
                    graphId=_seGraphId, nodeId=_seNodeId, evidenceContent=_seContent, sourceUrl=_seSourceUrl, evaluate=True
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
                mutData = mutResult["reports"][0] if mutResult["reports"] else {};
                if "graph" in mutData { currentGraph = mutData["graph"]; }
                if "score" in mutData {
                    currentScore = mutData["score"];
                    _seNewScore = currentScore["overall"] if "overall" in currentScore else _sePrevScore;
                    applyScoreDelta(_sePrevScore, _seNewScore);
                }
                if "issues" in mutData { currentIssues = mutData["issues"]; }
                if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
                _freshGraph = mutData["graph"] if "graph" in mutData else currentGraph;
                _seNodes = _freshGraph["nodes"] if _freshGraph and "nodes" in _freshGraph else [];
                _seFound = None;
                _sefi = 0;
                while _sefi < len(_seNodes) {
                    if _seNodes[_sefi]["id"] == _seNodeId { _seFound = _seNodes[_sefi]; break; }
                    _sefi = _sefi + 1;
                }
                selectedNode = _seFound;
            }
        } except Exception { }

        editMode = "";
        editInputValue = "";
        sourceUrlValue = "";
        isSaving = False;
        pushUpdate();
    }

    async def handleDelete() -> None {
        if not currentGraph { return; }
        _delNodeId = selectedNode["id"] if selectedNode and "id" in selectedNode else "";
        if not _delNodeId { return; }
        _delNodeType = selectedNode["type"] if selectedNode and "type" in selectedNode else "";
        _delNodeContent = selectedNode["content"] if selectedNode and "content" in selectedNode else "";

        # Block thesis deletion — show toast instead
        if _delNodeType == "THESIS" {
            showConfirmDelete = False;
            thesisToast = "active";
            setTimeout(lambda -> None {
                thesisToast = "";
            }, 3000);
            return;
        }

        if _delNodeType == "COUNTERARGUMENT" and _delNodeContent and _delNodeContent not in dismissedCounterargTexts {
            dismissedCounterargTexts.append(_delNodeContent);
        }

        # Snapshot for undo
        _undoGraph = currentGraph;
        _undoScore = currentScore;
        _undoIssues = currentIssues;
        _undoActions = currentNextActions;

        isSaving = True;
        _delPrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        _delGraphId = currentGraph["id"] if "id" in currentGraph else "";

        try {
            mutResult = await root spawn DeleteNode(graphId=_delGraphId, nodeId=_delNodeId);
            mutData = mutResult["reports"][0] if mutResult["reports"] else {};
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

        # Show undo toast for 5 seconds
        undoDelete = {
            "graph": _undoGraph,
            "score": _undoScore,
            "issues": _undoIssues,
            "nextActions": _undoActions,
            "nodeName": _delNodeContent[:30] if len(_delNodeContent) > 30 else _delNodeContent
        };
        setTimeout(lambda -> None {
            undoDelete = None;
        }, 5000);

        pushUpdate();
    }

    def handleUndoDelete() -> None {
        if not undoDelete { return; }
        currentGraph = undoDelete["graph"];
        currentScore = undoDelete["score"];
        currentIssues = undoDelete["issues"];
        currentNextActions = undoDelete["nextActions"];
        undoDelete = None;
        pushUpdate();
    }

    async def handleAcceptCounterarg(ca: dict) -> None {
        if not currentGraph { return; }
        ca_text = ca["text"] if "text" in ca else "";
        ca_target = ca["target_node"] if "target_node" in ca else "";
        if not ca_text or not ca_target { return; }

        isSaving = True;
        _acGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _acPrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;

        try {
            addResult = await root spawn AddCounterargumentNode(
                graphId=_acGraphId, targetNodeId=ca_target, counterargContent=ca_text
            );
            addData = addResult["reports"][0] if addResult["reports"] else {};
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
        pushUpdate();
    }

    async def handleExpandBranch() -> None {
        if not selectedNode or not currentGraph { return; }
        isSaving = True;
        _ebGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _ebNodeId = selectedNode["id"];
        _ebPrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        try {
            mutResult = await root spawn ExpandBranch(graphId=_ebGraphId, nodeId=_ebNodeId);
            mutData = mutResult["reports"][0] if mutResult["reports"] else {};
            if "graph" in mutData { currentGraph = mutData["graph"]; }
            if "score" in mutData {
                currentScore = mutData["score"];
                _ebNewScore = currentScore["overall"] if "overall" in currentScore else _ebPrevScore;
                applyScoreDelta(_ebPrevScore, _ebNewScore);
            }
            if "issues" in mutData { currentIssues = mutData["issues"]; }
            if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
            _freshGraph = mutData["graph"] if "graph" in mutData else currentGraph;
            _ebNodes = _freshGraph["nodes"] if _freshGraph and "nodes" in _freshGraph else [];
            _ebFound = None;
            _ebi = 0;
            while _ebi < len(_ebNodes) {
                if _ebNodes[_ebi]["id"] == _ebNodeId { _ebFound = _ebNodes[_ebi]; break; }
                _ebi = _ebi + 1;
            }
            selectedNode = _ebFound;
        } except Exception { }
        isSaving = False;
        pushUpdate();
    }

    if not currentGraph or not currentScore {
        return (
            <div className="rs-loading">
                <p>Loading argument map...</p>
            </div>
        );
    }

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
        {"key": "THESIS",          "color": "#3b82f6", "bg": "#DBEAFE", "label": "Thesis"},
        {"key": "CLAIM",           "color": "#9f7aea", "bg": "#e8e0fc", "label": "Claim"},
        {"key": "EVIDENCE",        "color": "#10b981", "bg": "#d1fae5", "label": "Evidence"},
        {"key": "COUNTERARGUMENT", "color": "#ef4444", "bg": "#fee2e2", "label": "Counter"}
    ];

    sel_type = selectedNode["type"] if selectedNode and "type" in selectedNode else "CLAIM";
    sel_content = selectedNode["content"] if selectedNode and "content" in selectedNode else "";

    # Always read the freshest node data from currentGraph to avoid stale scores
    _fresh_sel = selectedNode;
    if selectedNode and currentGraph {
        _fsnId = selectedNode["id"] if "id" in selectedNode else "";
        _fsnNodes = currentGraph["nodes"] if "nodes" in currentGraph else [];
        _fsni = 0;
        while _fsni < len(_fsnNodes) {
            if _fsnNodes[_fsni]["id"] == _fsnId {
                _fresh_sel = _fsnNodes[_fsni];
                break;
            }
            _fsni = _fsni + 1;
        }
    }
    sel_node_score = _fresh_sel["nodeScore"] if _fresh_sel and "nodeScore" in _fresh_sel else -1;
    sel_has_node_score = sel_node_score >= 0;

    sel_str_color = "#16a34a" if sel_node_score >= 70 else ("#ca8a04" if sel_node_score >= 50 else "#dc2626");
    sel_str_bg = "rgba(34,197,94,0.1)" if sel_node_score >= 70 else ("rgba(250,204,21,0.15)" if sel_node_score >= 50 else "rgba(239,68,68,0.1)");

    typeColorMap = {
        "THESIS":          "#3b82f6",
        "CLAIM":           "#9f7aea",
        "EVIDENCE":        "#10b981",
        "COUNTERARGUMENT": "#ef4444"
    };
    sel_type_color = typeColorMap[sel_type] if sel_type in typeColorMap else "#3b82f6";

    sel_is_evidence = sel_type == "EVIDENCE";
    sel_ev_category = "";
    sel_assumptions: list = [];
    sel_has_assumptions = False;
    sel_source_url = "";
    if _fresh_sel {
        sel_ev_category = _fresh_sel["evidence_category"] if "evidence_category" in _fresh_sel else "";
        sel_assumptions = _fresh_sel["assumptions"] if "assumptions" in _fresh_sel else [];
        sel_has_assumptions = len(sel_assumptions) > 0;
        sel_source_url = _fresh_sel["sourceUrl"] if "sourceUrl" in _fresh_sel else "";
    }
    sel_has_source = len(sel_source_url) > 0 if sel_source_url else False;
    sel_is_well_sourced = sel_has_source and sel_is_evidence;
    sel_ev_cat_display = sel_ev_category.replace("_", " ") if sel_ev_category else "logical reasoning";

    sel_more_info = "";
    if _fresh_sel {
        sel_more_info = _fresh_sel["moreInfo"] if "moreInfo" in _fresh_sel else "";
    }
    sel_has_more_info = len(sel_more_info) > 0 if sel_more_info else False;

    edit_label = "Respond";
    edit_placeholder = "Add evidence, reasoning, or a rebuttal...";
    if editMode == "address" {
        edit_label = "Address This Counterargument";
        edit_placeholder = "How would you respond to this counterargument? Provide evidence or reasoning...";
    } elif editMode == "evidence" {
        edit_label = "Add Evidence";
        edit_placeholder = "Add a fact, statistic, study, or expert quote...";
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
        fix_mode = "respond";
        if iss_type == "weak_evidence" or iss_type == "unsupported_claim" or iss_type == "low_quality_evidence" or iss_type == "weak_foundation" {
            fix_mode = "investigate";
        } elif iss_type == "contradiction" or iss_type == "unresolved_contradiction" {
            fix_mode = "address";
        } elif iss_type == "orphan_node" {
            fix_mode = "delete";
        }
        fix_click_fn = makeFixHandler(fix_mode);
        nodeIssueElements.append(
            <div key={iss["id"]} className="rs-issue-card">
                <div className="rs-issue-inner">
                    <div className="rs-issue-body">
                        <div className="rs-issue-description">{iss["description"]}</div>
                        <div className="rs-issue-next-step">
                            <span className="rs-next-step-arrow">→</span>
                            {iss["suggestedAction"]}
                        </div>
                    </div>
                    <button onClick={fix_click_fn} className="rs-fix-btn">Fix →</button>
                </div>
            </div>
        );
        _ni = _ni + 1;
    }

    assumptionElements: list = [];
    _maxAssumptions = len(sel_assumptions) if showAllAssumptions else 3;
    if _maxAssumptions > len(sel_assumptions) { _maxAssumptions = len(sel_assumptions); }
    _ai = 0;
    while _ai < _maxAssumptions {
        assumption = sel_assumptions[_ai];
        investigate_fn = makeInvestigateAssumptionHandler(assumption);
        assumptionElements.append(
            <div key={f"assumption_{str(_ai)}"} className="rs-assumption-step-card">
                <div className="rs-assumption-step-label">Assumed</div>
                <div className="rs-assumption-step-text">{assumption}</div>
                {(
                    <div>
                        <div className="rs-issue-next-step">
                            <span className="rs-next-step-arrow">→</span>
                            Provide evidence to support or address this assumption
                        </div>
                        <button className="rs-assumption-action-btn"
                            onClick={investigate_fn}>
                            Find Evidence →
                        </button>
                    </div>
                ) if assumption not in investigatedAssumptions else None}
            </div>
        );
        _ai = _ai + 1;
    }
    _hiddenAssumptionCount = len(sel_assumptions) - _maxAssumptions;

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
                            <span className="rs-next-action-lift">{"+" + str(next_lift) + " pts"}</span>
                        ) if next_lift > 0 else None}
                    </div>
                    <button onClick={next_click_fn} className="rs-next-action-btn">Go to node →</button>
                </div>
            </div>
        );
        _na = _na + 1;
    }

    visibleCounterargs: list = [];
    _vci = 0;
    _graph_nodes_for_filter = currentGraph["nodes"] if "nodes" in currentGraph else [];
    while _vci < len(suggestedCounterargs) {
        _vc = suggestedCounterargs[_vci];
        _vc_text = _vc["text"] if "text" in _vc else "";
        if _vc_text in dismissedCounterargTexts {
            _vci = _vci + 1;
            continue;
        }
        _already_in_graph = False;
        _gni = 0;
        while _gni < len(_graph_nodes_for_filter) {
            _gn = _graph_nodes_for_filter[_gni];
            if ("type" in _gn and _gn["type"] == "COUNTERARGUMENT") and ("content" in _gn and _gn["content"] == _vc_text) {
                _already_in_graph = True;
                break;
            }
            _gni = _gni + 1;
        }
        if not _already_in_graph { visibleCounterargs.append(_vc); }
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

    # Build investigate result cards
    investigateResultElements: list = [];
    _iri = 0;
    while _iri < len(investigateResults) {
        _ir = investigateResults[_iri];
        _ir_title = _ir["title"] if "title" in _ir else "";
        _ir_summary = _ir["summary"] if "summary" in _ir else "";
        _ir_url = _ir["url"] if "url" in _ir else "";
        _ir_pick_fn = makePickResultHandler(_iri, _ir_title, _ir_url);
        investigateResultElements.append(
            <div key={f"inv_{str(_iri)}"} className="rs-investigate-card">
                <div className="rs-investigate-title">{_ir_title}</div>
                <div className="rs-investigate-summary">{_ir_summary}</div>
                {(
                    <a href={_ir_url} target="_blank" rel="noopener noreferrer"
                        className="rs-investigate-link">
                        {_ir_url}
                    </a>
                ) if _ir_url else None}
                <button className="rs-investigate-add-btn" onClick={_ir_pick_fn}>
                    ➕ Add as Evidence
                </button>
            </div>
        );
        _iri = _iri + 1;
    }

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

    show_respond = sel_type != "";
    show_add_counter = sel_type == "CLAIM" or sel_type == "THESIS" or sel_type == "COUNTERARGUMENT";
    show_address = sel_type == "COUNTERARGUMENT";
    show_expand = sel_type == "CLAIM" or sel_type == "THESIS" or sel_type == "COUNTERARGUMENT";
    show_source_input = editMode == "evidence" or editMode == "respond";
    has_investigate_results = len(investigateResults) > 0;

    return (
        <div className="rs-wrapper">

            <Header screen="review" title="Review Map" onExport={lambda -> None {
                nav("/export", {"state": {
                    "graph": currentGraph,
                    "score": currentScore,
                    "issues": currentIssues,
                    "nextActions": currentNextActions
                }});
            }} />

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
                    <span className="rs-legend-label">Quality Score</span>
                    <div className="rs-legend-type-item">
                        <div className="rs-strength-dot rs-strength-dot-good"></div>
                        <span className="rs-legend-value">Good</span>
                    </div>
                    <div className="rs-legend-type-item">
                        <div className="rs-strength-dot rs-strength-dot-warning"></div>
                        <span className="rs-legend-value">Moderate</span>
                    </div>
                    <div className="rs-legend-type-item">
                        <div className="rs-strength-dot rs-strength-dot-bad"></div>
                        <span className="rs-legend-value">Poor</span>
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

                    {(
                        <div className="rs-undo-toast">
                            <span className="rs-undo-toast-text">
                                Deleted node
                            </span>
                            <button className="rs-undo-toast-btn" onClick={handleUndoDelete}>
                                Undo
                            </button>
                        </div>
                    ) if undoDelete else None}

                    {(
                        <div className="rs-thesis-toast">
                            The thesis is the foundation of your argument and cannot be deleted.
                        </div>
                    ) if thesisToast else None}

                    {(
                        <div className="rs-tutorial-popup">
                            <button className="rs-tutorial-close" onClick={lambda -> None { showTutorial = False; }}>
                                x
                            </button>
                            {(
                                <div>
                                    <div className="rs-tutorial-step-label">Step 1 of 3</div>
                                    <div className="rs-tutorial-title">Explore your argument</div>
                                    <div className="rs-tutorial-text">
                                        Click any node in the graph to view its quality score and details.
                                    </div>
                                    <button className="rs-tutorial-next" onClick={lambda -> None { tutorialStep = 2; }}>
                                        Next
                                    </button>
                                </div>
                            ) if tutorialStep == 1 else None}
                            {(
                                <div>
                                    <div className="rs-tutorial-step-label">Step 2 of 3</div>
                                    <div className="rs-tutorial-title">Take action</div>
                                    <div className="rs-tutorial-text">
                                        Use the action buttons to respond, counter, expand, or investigate a node.
                                    </div>
                                    <div className="rs-tutorial-nav">
                                        <button className="rs-tutorial-back" onClick={lambda -> None { tutorialStep = 1; }}>
                                            Back
                                        </button>
                                        <button className="rs-tutorial-next" onClick={lambda -> None { tutorialStep = 3; }}>
                                            Next
                                        </button>
                                    </div>
                                </div>
                            ) if tutorialStep == 2 else None}
                            {(
                                <div>
                                    <div className="rs-tutorial-step-label">Step 3 of 3</div>
                                    <div className="rs-tutorial-title">Improve your score</div>
                                    <div className="rs-tutorial-text">
                                        Check the issues panel for weaknesses and follow the suggested next actions to strengthen your argument.
                                    </div>
                                    <button className="rs-tutorial-next" onClick={lambda -> None { showTutorial = False; }}>
                                        Got it
                                    </button>
                                </div>
                            ) if tutorialStep == 3 else None}
                        </div>
                    ) if showTutorial else None}
                </div>

                {(
                    <div className="rs-selected-panel">

                        <div className="rs-saving-overlay"
                            style={{"display": saving_overlay_display}}>
                            <div className="rs-saving-indicator">Updating...</div>
                        </div>

                        <div className="rs-panel-header">
                            <div className="rs-panel-header-row">
                                <div className="rs-panel-header-left">
                                    <span className="rs-panel-type-label"
                                        style={{"color": sel_type_color}}>
                                        {sel_type}
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
                                    Issues & Next Steps
                                </div>
                                {(
                                    <div>
                                        {nodeIssueElements}
                                        {(
                                            <div className="rs-assumptions-in-issues">
                                                {assumptionElements}
                                                {(
                                                    <button className="rs-show-more-btn"
                                                        onClick={lambda -> None { showAllAssumptions = True; }}>
                                                        {f"Show {_hiddenAssumptionCount} more"}
                                                    </button>
                                                ) if _hiddenAssumptionCount > 0 else None}
                                                {(
                                                    <button className="rs-show-more-btn"
                                                        onClick={lambda -> None { showAllAssumptions = False; }}>
                                                        Show less
                                                    </button>
                                                ) if showAllAssumptions and len(sel_assumptions) > 3 else None}
                                            </div>
                                        ) if sel_has_assumptions else None}
                                    </div>
                                ) if has_node_issues or sel_has_assumptions else (
                                    <div className="rs-well-supported">No issues found ✓</div>
                                )}
                            </div>

                            <div className="rs-panel-section">
                                <div className="rs-section-heading rs-section-heading-actions">
                                    <span className="rs-section-dot rs-section-dot-actions"></span>
                                    Quick Actions
                                </div>
                                <div className="rs-actions-grid">
                                    {(
                                        <button className="rs-action-btn rs-action-btn-respond"
                                            onClick={lambda -> None { startEdit("address"); }}
                                            title="Add evidence or reasoning to address this counterargument">
                                            Respond
                                        </button>
                                    ) if show_address else (
                                        <button className="rs-action-btn rs-action-btn-respond"
                                            onClick={lambda -> None { startEdit("respond"); }}
                                            title="Add supporting evidence or reasoning to this node">
                                            Respond
                                        </button>
                                    ) if show_respond else None}
                                    {(
                                        <button className="rs-action-btn rs-action-btn-counter"
                                            onClick={lambda -> None { startEdit("counter"); }}
                                            title="Generate a counterargument against this claim">
                                            Counter
                                        </button>
                                    ) if show_add_counter else None}
                                    {(
                                        <button className="rs-action-btn rs-action-btn-expand"
                                            onClick={handleExpandBranch}
                                            title="Break this claim into sub-claims and evidence">
                                            Expand
                                        </button>
                                    ) if show_expand else None}
                                    {(
                                        <button className="rs-action-btn rs-action-btn-default"
                                            onClick={lambda -> None { startEdit("investigate"); }}
                                            title="Find Wikipedia sources related to this node">
                                            Investigate
                                        </button>
                                    ) if not sel_is_well_sourced else (
                                        <span className="rs-sourced-badge">Sourced</span>
                                    )}
                                </div>
                                <div className="rs-actions-delete-row">
                                    <button className="rs-action-btn rs-action-btn-delete"
                                        onClick={lambda -> None { startEdit("delete"); }}
                                        title="Remove this node and its connections">
                                        Delete
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
                                        This will remove the node and all its connections.
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
                                    <div className="rs-section-heading rs-section-heading-info">
                                        <span className="rs-section-dot rs-section-dot-info"></span>
                                        Wikipedia Sources
                                    </div>
                                    <div className="rs-wiki-disclaimer">
                                        Sources come from Wikipedia and may not be fully reliable. Always verify before citing.
                                    </div>
                                    {(
                                        <div className="rs-investigate-loading">Searching Wikipedia...</div>
                                    ) if investigateLoading else None}
                                    {investigateResultElements}
                                    <button className="rs-investigate-dismiss-btn"
                                        onClick={lambda -> None { investigateResults = []; }}>
                                        Dismiss
                                    </button>
                                </div>
                            ) if has_investigate_results or investigateLoading else None}

                            {(
                                <div className="rs-panel-section">
                                    <div className="rs-section-heading rs-section-heading-info">
                                        <span className="rs-section-dot rs-section-dot-info"></span>
                                        Analysis & Source
                                    </div>
                                    {(
                                        <div className="rs-analysis-text">{sel_more_info}</div>
                                    ) if sel_has_more_info else None}
                                    {(
                                        <div className="rs-source-block">
                                            <span className="rs-evidence-key">Source</span>
                                            <a href={sel_source_url} target="_blank"
                                                rel="noopener noreferrer"
                                                className="rs-source-link">
                                                {sel_source_url}
                                            </a>
                                        </div>
                                    ) if sel_has_source else None}
                                    {(
                                        <button className="rs-add-evidence-btn"
                                            onClick={handleAddAsEvidence}
                                            disabled={isSaving}>
                                            📊 Add as Evidence
                                        </button>
                                    ) if sel_has_more_info and not sel_is_evidence and selectedNode and selectedNode["id"] and selectedNode["id"] not in addedAsEvidenceMap else None}
                                    {(
                                        <div className="rs-analysis-empty">No additional analysis available</div>
                                    ) if not sel_has_more_info and not sel_has_source else None}
                                </div>
                            ) if sel_is_evidence or sel_has_more_info else None}

                            {(
                                <div className="rs-panel-section">
                                    <div className="rs-section-heading rs-section-heading-score">
                                        <span className="rs-section-dot rs-section-dot-score"></span>
                                        Node Quality
                                    </div>
                                    <div className="rs-quality-box">
                                        <div className="rs-quality-score-row">
                                            <div className="rs-quality-score-number"
                                                style={{"color": sel_str_color}}>
                                                {str(sel_node_score)}
                                            </div>
                                            <div className="rs-quality-score-meta">
                                                <div className="rs-quality-score-label">
                                                    {"Strong" if sel_node_score >= 70 else ("Fair" if sel_node_score >= 50 else "Weak")}
                                                </div>
                                                {(
                                                    <div className="rs-quality-category">
                                                        {sel_ev_cat_display}
                                                    </div>
                                                ) if sel_is_evidence else None}
                                            </div>
                                        </div>
                                        <div className="rs-quality-bar">
                                            <div className="rs-quality-bar-fill"
                                                style={{"width": f"{sel_node_score}%", "background": sel_str_color}}>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            ) if sel_has_node_score else None}

                        </div>
                    </div>
                ) if selectedNode else (
                    <div className="rs-default-panel">

                        <div className="rs-saving-overlay"
                            style={{"display": saving_overlay_display}}>
                            <div className="rs-saving-indicator">Updating...</div>
                        </div>

                        <div className="rs-default-scroll">

                            <div className="rs-default-section-header">
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
                                <span className="rs-default-section-title">Top Issues</span>
                            </div>
                            {(
                                <div>
                                    <p className="rs-panel-hint">Click on a node to fix it</p>
                                    <div>{topIssueElements}</div>
                                </div>
                            ) if len(currentIssues) > 0 else (
                                <div className="rs-no-issues-card">
                                    No major issues found!
                                </div>
                            )}

                            <div className="rs-next-actions-section">
                                <div className="rs-default-section-header">
                                    <span className="rs-default-section-title">Next 3 Actions</span>
                                </div>
                                {(
                                    <div>{nextActionElements}</div>
                                ) if len(nextActionElements) > 0 else (
                                    <div className="rs-no-issues-card">
                                        No urgent actions found. Your argument is ready to export!
                                    </div>
                                )}
                            </div>

                            {(
                                <div className="rs-counterargs-section">
                                    <div className="rs-default-section-header">
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
