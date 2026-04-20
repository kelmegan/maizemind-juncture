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
        layoutHints: dict = {},
        layoutHintGraphId: str = "",
        persistedLayoutPositions: dict = {},
        persistedLayoutGraphId: str = "",
        graphViewVersion: int = 0,
        undoStack: list = [],
        selectedNode: dict | None = None,
        focusBranch: str = None,
        editMode: str = "",
        editInputValue: str = "",
        sourceUrlValue: str = "",
        actionOwnerValue: str = "",
        actionDueDateValue: str = "",
        actionPriorityValue: str = "medium",
        actionStatusValue: str = "open",
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

    def graphMode(graph_data: dict = None) -> str {
        target_graph = graph_data if graph_data else currentGraph;
        if not target_graph {
            return "education_argument";
        }
        if "graph_mode" in target_graph and target_graph["graph_mode"] {
            return str(target_graph["graph_mode"]);
        }
        if "graphMode" in target_graph and target_graph["graphMode"] {
            return str(target_graph["graphMode"]);
        }
        return "education_argument";
    }

    def isBusinessGraph(graph_data: dict = None) -> bool {
        return graphMode(graph_data) == "business_meeting_decision";
    }

    def semanticRole(node_data: dict) -> str {
        if not node_data { return ""; }
        role = str(node_data["role"]).upper() if "role" in node_data and node_data["role"] else "";
        if not role {
            role = str(node_data["semanticRole"]).upper() if "semanticRole" in node_data and node_data["semanticRole"] else "";
        }
        if role == "NEXT_ACTION" { role = "ACTION"; }
        if role { return role; }
        node_type = node_data["type"] if "type" in node_data else "";
        if node_type == "THESIS" { return "DECISION"; }
        if node_type == "EVIDENCE" { return "EVIDENCE"; }
        if node_type == "COUNTERARGUMENT" { return "RISK"; }
        return "OPTION";
    }

    def edgeRole(edge_data: dict) -> str {
        if not edge_data { return ""; }
        role = str(edge_data["role"]).upper() if "role" in edge_data and edge_data["role"] else "";
        if not role {
            role = str(edge_data["type"]).upper() if "type" in edge_data and edge_data["type"] else "";
        }
        if role == "CONTRADICTS" { return "OPPOSES"; }
        if role == "ADDRESSES" { return "RESOLVES"; }
        return role;
    }

    def branchLinkedNodeId(edge_data: dict, current_id: str) -> str {
        if not edge_data or not current_id { return ""; }
        current_role = edgeRole(edge_data);
        if "target" in edge_data and edge_data["target"] == current_id {
            if current_role == "SUPPORTS" or current_role == "RESOLVES" or current_role == "OPPOSES" or current_role == "BLOCKS" or current_role == "DEPENDS_ON" or current_role == "IMPLEMENTS" {
                return edge_data["source"] if "source" in edge_data else "";
            }
        } elif "source" in edge_data and edge_data["source"] == current_id {
            if current_role == "HAS_OPTION" {
                return edge_data["target"] if "target" in edge_data else "";
            }
        }
        return "";
    }

    def computeBranchIds(root_id: str) -> list {
        result: list = [];
        if not currentGraph or not root_id { return result; }
        queue: list = [root_id];
        result.append(root_id);
        graph_edges = currentGraph["edges"] if "edges" in currentGraph else [];
        qi = 0;
        while qi < len(queue) {
            current_id = queue[qi];
            ei = 0;
            while ei < len(graph_edges) {
                linked_id = branchLinkedNodeId(graph_edges[ei], current_id);
                if linked_id and linked_id not in result {
                    result.append(linked_id);
                    queue.append(linked_id);
                }
                ei = ei + 1;
            }
            qi = qi + 1;
        }
        return result;
    }

    def isNodeInFocusedBranch(node_id: str) -> bool {
        if not focusBranch or not node_id { return False; }
        return node_id in computeBranchIds(focusBranch);
    }

    def semanticRoleLabel(role: str, fallback_type: str = "") -> str {
        if role == "DECISION" { return "Decision"; }
        if role == "OPTION" { return "Option"; }
        if role == "EVIDENCE" { return "Evidence"; }
        if role == "RISK" { return "Risk"; }
        if role == "ASSUMPTION" { return "Assumption"; }
        if role == "OPEN_QUESTION" { return "Open Question"; }
        if role == "ACTION" { return "Next Action"; }
        return fallback_type if fallback_type else "Node";
    }

    def firstOwnerText(node_data: dict) -> str {
        if not node_data { return ""; }
        if "owner" in node_data and node_data["owner"] {
            return str(node_data["owner"]);
        }
        if "owners" in node_data and node_data["owners"] {
            owner_candidates = node_data["owners"];
            try {
                if len(owner_candidates) > 0 and owner_candidates[0] {
                    return str(owner_candidates[0]);
                }
            } except Exception as e {
                return str(owner_candidates);
            }
        }
        return "";
    }

    def nodesForRole(node_list: list, role: str) -> list {
        result: list = [];
        ni = 0;
        while ni < len(node_list) {
            if semanticRole(node_list[ni]) == role {
                result.append(node_list[ni]);
            }
            ni = ni + 1;
        }
        return result;
    }

    async def loadGraphData() -> None {
        graph_id = ctx.cachedGraphId
                if ctx.cachedGraphId
                else (loc_state["graphId"] if "graphId" in loc_state else "");
        if not graph_id { return; }
        try {
            result = await root spawn GetGraphWithScoring(graphId=graph_id);
            data = result["reports"][0] if result["reports"] else {};
            if "graph" in data {
                graph_data = data["graph"];
                seed_positions = extractPositionsFromGraph(graph_data);
                currentGraph = applyPositionsAndLocks(graph_data, seed_positions, {});
                layoutHints = seed_positions;
                layoutHintGraphId = graph_id;
                persistedLayoutPositions = seed_positions;
                persistedLayoutGraphId = graph_id;
                graphViewVersion = graphViewVersion + 1;
                undoStack = [];
            }
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

    def clonePositionMap(graph_data: dict, position_map: dict) -> dict {
        result: dict = {};
        if not graph_data or not position_map { return result; }
        graph_nodes = graph_data["nodes"] if "nodes" in graph_data else [];
        gi = 0;
        while gi < len(graph_nodes) {
            position_id = graph_nodes[gi]["id"] if "id" in graph_nodes[gi] else "";
            if position_id in position_map {
                raw_pos = position_map[position_id] if position_map[position_id] else {"x": 0, "y": 0};
                result[position_id] = {
                    "x": float(raw_pos["x"]) if "x" in raw_pos else 0.0,
                    "y": float(raw_pos["y"]) if "y" in raw_pos else 0.0
                };
            }
            gi = gi + 1;
        }
        return result;
    }

    def cloneNodeList(node_list: list) -> list {
        result: list = [];
        if not node_list { return result; }
        ni = 0;
        while ni < len(node_list) {
            node_item = node_list[ni];
            cloned = {
                "id": node_item["id"] if "id" in node_item else "",
                "type": node_item["type"] if "type" in node_item else "",
                "content": node_item["content"] if "content" in node_item else "",
                "confidence": node_item["confidence"] if "confidence" in node_item else 0.5,
                "isWeak": node_item["isWeak"] if "isWeak" in node_item else False,
                "issues": list(node_item["issues"]) if "issues" in node_item and node_item["issues"] else [],
                "llmIssueTypes": list(node_item["llmIssueTypes"]) if "llmIssueTypes" in node_item and node_item["llmIssueTypes"] else [],
                "position": {
                    "x": float(node_item["position"]["x"]) if "position" in node_item and "x" in node_item["position"] else 0.0,
                    "y": float(node_item["position"]["y"]) if "position" in node_item and "y" in node_item["position"] else 0.0
                },
                "evidence_category": node_item["evidence_category"] if "evidence_category" in node_item else "",
                "assumptions": list(node_item["assumptions"]) if "assumptions" in node_item and node_item["assumptions"] else [],
                "nodeScore": node_item["nodeScore"] if "nodeScore" in node_item else 50,
                "sourceUrl": node_item["sourceUrl"] if "sourceUrl" in node_item else "",
                "moreInfo": node_item["moreInfo"] if "moreInfo" in node_item else "",
                "acknowledged": node_item["acknowledged"] if "acknowledged" in node_item else False,
                "layoutLocked": node_item["layoutLocked"] if "layoutLocked" in node_item else False,
                "role": node_item["role"] if "role" in node_item else "",
                "semanticRole": node_item["semanticRole"] if "semanticRole" in node_item else "",
                "source_span_ids": list(node_item["source_span_ids"]) if "source_span_ids" in node_item and node_item["source_span_ids"] else [],
                "speaker_ids": list(node_item["speaker_ids"]) if "speaker_ids" in node_item and node_item["speaker_ids"] else [],
                "origin": node_item["origin"] if "origin" in node_item else "",
                "question": node_item["question"] if "question" in node_item else "",
                "decision_status": node_item["decision_status"] if "decision_status" in node_item else "",
                "resolution_text": node_item["resolution_text"] if "resolution_text" in node_item else "",
                "scope": node_item["scope"] if "scope" in node_item else "",
                "time_horizon": node_item["time_horizon"] if "time_horizon" in node_item else "",
                "option_status": node_item["option_status"] if "option_status" in node_item else "",
                "evidence_kind": node_item["evidence_kind"] if "evidence_kind" in node_item else "",
                "criterion_tags": list(node_item["criterion_tags"]) if "criterion_tags" in node_item and node_item["criterion_tags"] else [],
                "risk_kind": node_item["risk_kind"] if "risk_kind" in node_item else "",
                "severity": node_item["severity"] if "severity" in node_item else "",
                "is_blocker": node_item["is_blocker"] if "is_blocker" in node_item else False,
                "assumption_status": node_item["assumption_status"] if "assumption_status" in node_item else "",
                "question_status": node_item["question_status"] if "question_status" in node_item else "",
                "owner": node_item["owner"] if "owner" in node_item else "",
                "owners": list(node_item["owners"]) if "owners" in node_item and node_item["owners"] else [],
                "dueDate": node_item["dueDate"] if "dueDate" in node_item else "",
                "due_date": node_item["due_date"] if "due_date" in node_item else "",
                "priority": node_item["priority"] if "priority" in node_item else "",
                "taskStatus": node_item["taskStatus"] if "taskStatus" in node_item else "",
                "task_status": node_item["task_status"] if "task_status" in node_item else "",
                "action_status": node_item["action_status"] if "action_status" in node_item else ""
            };
            if "isGhost" in node_item { cloned["isGhost"] = node_item["isGhost"]; }
            if "ghostTarget" in node_item { cloned["ghostTarget"] = node_item["ghostTarget"]; }
            result.append(cloned);
            ni = ni + 1;
        }
        return result;
    }

    def cloneEdgeList(edge_list: list) -> list {
        result: list = [];
        if not edge_list { return result; }
        ei = 0;
        while ei < len(edge_list) {
            edge_item = edge_list[ei];
            cloned = {
                "id": edge_item["id"] if "id" in edge_item else "",
                "source": edge_item["source"] if "source" in edge_item else "",
                "target": edge_item["target"] if "target" in edge_item else "",
                "type": edge_item["type"] if "type" in edge_item else "",
                "role": edge_item["role"] if "role" in edge_item else "",
                "confidence": edge_item["confidence"] if "confidence" in edge_item else 0.5
            };
            if "weight" in edge_item { cloned["weight"] = edge_item["weight"]; }
            if "reasoning_type" in edge_item { cloned["reasoning_type"] = edge_item["reasoning_type"]; }
            if "isGhost" in edge_item { cloned["isGhost"] = edge_item["isGhost"]; }
            result.append(cloned);
            ei = ei + 1;
        }
        return result;
    }

    def cloneIssueList(issue_list: list) -> list {
        result: list = [];
        if not issue_list { return result; }
        di = 0;
        while di < len(issue_list) {
            item = issue_list[di];
            cloned = {
                "id": item["id"] if "id" in item else "",
                "nodeId": item["nodeId"] if "nodeId" in item else "",
                "severity": item["severity"] if "severity" in item else "",
                "type": item["type"] if "type" in item else "",
                "description": item["description"] if "description" in item else "",
                "suggestedAction": item["suggestedAction"] if "suggestedAction" in item else "",
                "area": item["area"] if "area" in item else "",
                "estimatedLift": item["estimatedLift"] if "estimatedLift" in item else 0
            };
            result.append(cloned);
            di = di + 1;
        }
        return result;
    }

    def cloneNextActionList(action_list: list) -> list {
        result: list = [];
        if not action_list { return result; }
        di = 0;
        while di < len(action_list) {
            item = action_list[di];
            cloned = {
                "id": item["id"] if "id" in item else "",
                "nodeId": item["nodeId"] if "nodeId" in item else "",
                "action": item["action"] if "action" in item else "",
                "issueType": item["issueType"] if "issueType" in item else "",
                "rank": item["rank"] if "rank" in item else 0,
                "severity": item["severity"] if "severity" in item else "",
                "area": item["area"] if "area" in item else "",
                "expectedLift": item["expectedLift"] if "expectedLift" in item else 0
            };
            result.append(cloned);
            di = di + 1;
        }
        return result;
    }

    def cloneScoreData(score_data: dict) -> dict {
        if not score_data { return {}; }
        return {
            "overall": score_data["overall"] if "overall" in score_data else 0,
            "support": score_data["support"] if "support" in score_data else 0,
            "premise": score_data["premise"] if "premise" in score_data else 0,
            "coherence": score_data["coherence"] if "coherence" in score_data else 0,
            "counterargument": score_data["counterargument"] if "counterargument" in score_data else 0,
            "consistency": score_data["consistency"] if "consistency" in score_data else 0,
            "rootSupportCoverage": score_data["rootSupportCoverage"] if "rootSupportCoverage" in score_data else 0,
            "evidenceQuality": score_data["evidenceQuality"] if "evidenceQuality" in score_data else 0,
            "dialecticalHandling": score_data["dialecticalHandling"] if "dialecticalHandling" in score_data else 0,
            "structuralCoherence": score_data["structuralCoherence"] if "structuralCoherence" in score_data else 0,
            "assumptionExplicitness": score_data["assumptionExplicitness"] if "assumptionExplicitness" in score_data else 0,
            "thesisClarity": score_data["thesisClarity"] if "thesisClarity" in score_data else 0,
            "decisionClarity": score_data["decisionClarity"] if "decisionClarity" in score_data else 0,
            "decisionFraming": score_data["decisionFraming"] if "decisionFraming" in score_data else 0,
            "optionCoverage": score_data["optionCoverage"] if "optionCoverage" in score_data else 0,
            "optionSetQuality": score_data["optionSetQuality"] if "optionSetQuality" in score_data else 0,
            "evidenceStrength": score_data["evidenceStrength"] if "evidenceStrength" in score_data else 0,
            "riskCoverage": score_data["riskCoverage"] if "riskCoverage" in score_data else 0,
            "riskObjectionHandling": score_data["riskObjectionHandling"] if "riskObjectionHandling" in score_data else 0,
            "openQuestionHandling": score_data["openQuestionHandling"] if "openQuestionHandling" in score_data else 0,
            "assumptionQuestionHandling": score_data["assumptionQuestionHandling"] if "assumptionQuestionHandling" in score_data else 0,
            "actionability": score_data["actionability"] if "actionability" in score_data else 0,
            "actionabilityOwnership": score_data["actionabilityOwnership"] if "actionabilityOwnership" in score_data else 0,
            "traceabilityHygiene": score_data["traceabilityHygiene"] if "traceabilityHygiene" in score_data else 0,
            "readinessStatus": score_data["readinessStatus"] if "readinessStatus" in score_data else "",
            "discussionOnly": score_data["discussionOnly"] if "discussionOnly" in score_data else False,
            "blockerCap": score_data["blockerCap"] if "blockerCap" in score_data else 100,
            "criticalBlockers": score_data["criticalBlockers"] if "criticalBlockers" in score_data else 0,
            "majorBlockers": score_data["majorBlockers"] if "majorBlockers" in score_data else 0,
            "moderateBlockers": score_data["moderateBlockers"] if "moderateBlockers" in score_data else 0,
            "unsupportedClaims": score_data["unsupportedClaims"] if "unsupportedClaims" in score_data else 0,
            "claimsNeedingPremise": score_data["claimsNeedingPremise"] if "claimsNeedingPremise" in score_data else 0,
            "unresolvedContradictions": score_data["unresolvedContradictions"] if "unresolvedContradictions" in score_data else 0,
            "weakInferenceClaims": score_data["weakInferenceClaims"] if "weakInferenceClaims" in score_data else 0,
            "vagueClaims": score_data["vagueClaims"] if "vagueClaims" in score_data else 0,
            "orphanNodes": score_data["orphanNodes"] if "orphanNodes" in score_data else 0,
            "disconnectedClaims": score_data["disconnectedClaims"] if "disconnectedClaims" in score_data else 0,
            "thesisSupported": score_data["thesisSupported"] if "thesisSupported" in score_data else False,
            "passesBar": score_data["passesBar"] if "passesBar" in score_data else False
        };
    }

    def cloneGraphData(graph_data: dict) -> dict {
        if not graph_data { return None; }
        return {
            "id": graph_data["id"] if "id" in graph_data else "",
            "nodes": cloneNodeList(graph_data["nodes"]) if "nodes" in graph_data else [],
            "edges": cloneEdgeList(graph_data["edges"]) if "edges" in graph_data else [],
            "graphMode": graph_data["graphMode"] if "graphMode" in graph_data else "education_argument",
            "graph_mode": graph_data["graph_mode"] if "graph_mode" in graph_data else (graph_data["graphMode"] if "graphMode" in graph_data else "education_argument"),
            "schema_version": graph_data["schema_version"] if "schema_version" in graph_data else "",
            "board_id": graph_data["board_id"] if "board_id" in graph_data else "",
            "primary_decision_id": graph_data["primary_decision_id"] if "primary_decision_id" in graph_data else "",
            "meeting": graph_data["meeting"] if "meeting" in graph_data else {},
            "template": graph_data["template"] if "template" in graph_data else "",
            "title": graph_data["title"] if "title" in graph_data else "",
            "summary": graph_data["summary"] if "summary" in graph_data else "",
            "createdAt": graph_data["createdAt"] if "createdAt" in graph_data else "",
            "updatedAt": graph_data["updatedAt"] if "updatedAt" in graph_data else ""
        };
    }

    def pushUndoSnapshot(actionLabel: str) -> None {
        if not currentGraph { return; }
        snapshot = {
            "label": actionLabel,
            "graph": cloneGraphData(currentGraph),
            "score": cloneScoreData(currentScore) if currentScore else {},
            "issues": cloneIssueList(currentIssues) if currentIssues else [],
            "nextActions": cloneNextActionList(currentNextActions) if currentNextActions else [],
            "layoutHints": clonePositionMap(currentGraph, getStableLayoutPositions()),
            "persistedLayoutPositions": clonePositionMap(currentGraph, persistedLayoutPositions) if persistedLayoutPositions else clonePositionMap(currentGraph, extractPositionsFromGraph(currentGraph)),
            "selectedNodeId": selectedNode["id"] if selectedNode and "id" in selectedNode else "",
            "focusBranch": focusBranch if focusBranch else "",
            "dismissedCounterargTexts": list(dismissedCounterargTexts) if dismissedCounterargTexts else []
        };
        next_stack = list(undoStack);
        next_stack.append(snapshot);
        if len(next_stack) > 20 {
            next_stack = next_stack[1:];
        }
        undoStack = next_stack;
    }

    def findNodeById(graph_data: dict, node_id: str) -> dict | None {
        if not graph_data or not node_id { return None; }
        graph_nodes = graph_data["nodes"] if "nodes" in graph_data else [];
        gi = 0;
        while gi < len(graph_nodes) {
            if graph_nodes[gi]["id"] == node_id {
                return graph_nodes[gi];
            }
            gi = gi + 1;
        }
        return None;
    }

    def extractPositionsFromGraph(graph_data: dict) -> dict {
        result: dict = {};
        if not graph_data or "nodes" not in graph_data { return result; }
        graph_nodes = graph_data["nodes"] if "nodes" in graph_data else [];
        gi = 0;
        while gi < len(graph_nodes) {
            graph_node = graph_nodes[gi];
            graph_id = graph_node["id"] if "id" in graph_node else "";
            graph_pos = graph_node["position"] if "position" in graph_node else {"x": 0, "y": 0};
            result[graph_id] = {
                "x": float(graph_pos["x"]) if "x" in graph_pos else 0.0,
                "y": float(graph_pos["y"]) if "y" in graph_pos else 0.0
            };
            gi = gi + 1;
        }
        return result;
    }

    def extractNodeIdMap(graph_data: dict) -> dict {
        result: dict = {};
        if not graph_data or "nodes" not in graph_data { return result; }
        graph_nodes = graph_data["nodes"] if "nodes" in graph_data else [];
        gi = 0;
        while gi < len(graph_nodes) {
            graph_node = graph_nodes[gi];
            graph_id = graph_node["id"] if "id" in graph_node else "";
            if graph_id { result[graph_id] = True; }
            gi = gi + 1;
        }
        return result;
    }

    def extractLockedNodeIdMap(graph_data: dict) -> dict {
        result: dict = {};
        if not graph_data or "nodes" not in graph_data { return result; }
        graph_nodes = graph_data["nodes"] if "nodes" in graph_data else [];
        gi = 0;
        while gi < len(graph_nodes) {
            graph_node = graph_nodes[gi];
            graph_id = graph_node["id"] if "id" in graph_node else "";
            is_locked = graph_node["layoutLocked"] if "layoutLocked" in graph_node else False;
            if graph_id and is_locked {
                result[graph_id] = True;
            }
            gi = gi + 1;
        }
        return result;
    }

    def extractMovedNodeIdMap(graph_data: dict, candidate_positions: dict) -> dict {
        result = extractLockedNodeIdMap(graph_data);
        if not graph_data or not candidate_positions { return result; }
        graph_nodes = graph_data["nodes"] if "nodes" in graph_data else [];
        gi = 0;
        while gi < len(graph_nodes) {
            graph_node = graph_nodes[gi];
            graph_id = graph_node["id"] if "id" in graph_node else "";
            if graph_id and graph_id in candidate_positions {
                graph_pos = graph_node["position"] if "position" in graph_node else {"x": 0, "y": 0};
                next_pos = candidate_positions[graph_id] if candidate_positions[graph_id] else {"x": 0, "y": 0};
                graph_x = float(graph_pos["x"]) if "x" in graph_pos else 0.0;
                graph_y = float(graph_pos["y"]) if "y" in graph_pos else 0.0;
                next_x = float(next_pos["x"]) if "x" in next_pos else 0.0;
                next_y = float(next_pos["y"]) if "y" in next_pos else 0.0;
                if abs(graph_x - next_x) > 0.5 or abs(graph_y - next_y) > 0.5 {
                    result[graph_id] = True;
                }
            }
            gi = gi + 1;
        }
        return result;
    }

    def positionsDifferFromGraph(graph_data: dict, candidate_positions: dict) -> bool {
        if not graph_data { return False; }
        graph_nodes = graph_data["nodes"] if "nodes" in graph_data else [];
        gi = 0;
        while gi < len(graph_nodes) {
            graph_node = graph_nodes[gi];
            graph_id = graph_node["id"] if "id" in graph_node else "";
            if graph_id not in candidate_positions {
                return True;
            }
            graph_pos = graph_node["position"] if "position" in graph_node else {"x": 0, "y": 0};
            next_pos = candidate_positions[graph_id] if candidate_positions[graph_id] else {"x": 0, "y": 0};
            graph_x = float(graph_pos["x"]) if "x" in graph_pos else 0.0;
            graph_y = float(graph_pos["y"]) if "y" in graph_pos else 0.0;
            next_x = float(next_pos["x"]) if "x" in next_pos else 0.0;
            next_y = float(next_pos["y"]) if "y" in next_pos else 0.0;
            if abs(graph_x - next_x) > 0.5 or abs(graph_y - next_y) > 0.5 {
                return True;
            }
            gi = gi + 1;
        }
        return False;
    }

    def positionsDifferFromSnapshot(graph_data: dict, candidate_positions: dict, baseline_positions: dict) -> bool {
        if not graph_data { return False; }
        graph_nodes = graph_data["nodes"] if "nodes" in graph_data else [];
        gi = 0;
        while gi < len(graph_nodes) {
            graph_node = graph_nodes[gi];
            graph_id = graph_node["id"] if "id" in graph_node else "";
            if graph_id not in candidate_positions or graph_id not in baseline_positions {
                return True;
            }
            base_pos = baseline_positions[graph_id] if baseline_positions[graph_id] else {"x": 0, "y": 0};
            next_pos = candidate_positions[graph_id] if candidate_positions[graph_id] else {"x": 0, "y": 0};
            base_x = float(base_pos["x"]) if "x" in base_pos else 0.0;
            base_y = float(base_pos["y"]) if "y" in base_pos else 0.0;
            next_x = float(next_pos["x"]) if "x" in next_pos else 0.0;
            next_y = float(next_pos["y"]) if "y" in next_pos else 0.0;
            if abs(base_x - next_x) > 0.5 or abs(base_y - next_y) > 0.5 {
                return True;
            }
            gi = gi + 1;
        }
        return False;
    }

    def applyPositionsAndLocks(graph_data: dict, preferred_positions: dict = {}, locked_node_ids: dict = {}) -> dict {
        if not graph_data { return graph_data; }
        graph_nodes = graph_data["nodes"] if "nodes" in graph_data else [];
        gi = 0;
        while gi < len(graph_nodes) {
            graph_node = graph_nodes[gi];
            graph_id = graph_node["id"] if "id" in graph_node else "";
            if graph_id in preferred_positions {
                graph_node["position"] = preferred_positions[graph_id];
            } elif "position" not in graph_node {
                graph_node["position"] = {"x": 0, "y": 0};
            }
            graph_node["layoutLocked"] = graph_id in locked_node_ids;
            graph_nodes[gi] = graph_node;
            gi = gi + 1;
        }
        graph_data["nodes"] = graph_nodes;
        return graph_data;
    }

    def getStableLayoutPositions() -> dict {
        if layoutHints and len(layoutHints) > 0 {
            return layoutHints;
        }
        return extractPositionsFromGraph(currentGraph);
    }

    async def flushLayoutToBackend(force: bool = False) -> None {
        if not currentGraph { return; }
        next_positions = getStableLayoutPositions();
        baseline_positions = persistedLayoutPositions if persistedLayoutGraphId == (currentGraph["id"] if currentGraph and "id" in currentGraph else "") else extractPositionsFromGraph(currentGraph);
        if not force and not positionsDifferFromSnapshot(currentGraph, next_positions, baseline_positions) {
            return;
        }
        graph_id = currentGraph["id"] if "id" in currentGraph else "";
        if not graph_id { return; }
        locked_node_ids = extractLockedNodeIdMap(currentGraph);
        try {
            persistResult = await root spawn PersistGraphLayout(graphId=graph_id, positions=next_positions);
            persistData = persistResult["reports"][0] if persistResult["reports"] else {};
            if "graph" in persistData {
                currentGraph = applyPositionsAndLocks(
                    persistData["graph"],
                    next_positions,
                    locked_node_ids
                );
            } else {
                currentGraph = applyPositionsAndLocks(
                    currentGraph,
                    next_positions,
                    locked_node_ids
                );
            }
            layoutHints = next_positions;
            layoutHintGraphId = graph_id;
            persistedLayoutPositions = next_positions;
            persistedLayoutGraphId = graph_id;
        } except Exception as e {
            print(f"ReviewScreen layout persist error: {e}");
        }
    }

    def applyMutationGraph(mutData: dict, preserved_positions: dict, preserved_node_ids: dict) -> dict {
        if "graph" not in mutData { return currentGraph; }
        next_graph = mutData["graph"];
        next_graph = applyPositionsAndLocks(next_graph, preserved_positions, preserved_node_ids);
        next_layout_hints = clonePositionMap(next_graph, preserved_positions);
        currentGraph = next_graph;
        layoutHints = next_layout_hints;
        layoutHintGraphId = next_graph["id"] if "id" in next_graph else layoutHintGraphId;
        persistedLayoutPositions = next_layout_hints;
        persistedLayoutGraphId = next_graph["id"] if "id" in next_graph else persistedLayoutGraphId;
        return next_graph;
    }

    def syncLayoutLocally(updatedPositions: dict, lock_all_nodes: bool = False) -> None {
        if not currentGraph or not updatedPositions { return; }
        locked_ids = extractMovedNodeIdMap(currentGraph, updatedPositions) if lock_all_nodes else extractLockedNodeIdMap(currentGraph);
        currentGraph = applyPositionsAndLocks(currentGraph, updatedPositions, locked_ids);
        layoutHints = updatedPositions;
        graph_id = currentGraph["id"] if "id" in currentGraph else "";
        layoutHintGraphId = graph_id;
    }

    def handleLayoutResolved(resolvedPositions: dict) -> None {
        if not resolvedPositions or not currentGraph { return; }
        if not positionsDifferFromGraph(currentGraph, resolvedPositions) { return; }
        syncLayoutLocally(resolvedPositions, False);
    }

    async def handleNodePositionsChange(updatedPositions: dict) -> None {
        if not updatedPositions or not currentGraph { return; }
        pushUndoSnapshot("Move node");
        syncLayoutLocally(updatedPositions, True);
        await flushLayoutToBackend(True);
    }

    async def handleUndo() -> None {
        if len(undoStack) == 0 or not currentGraph { return; }
        last_index = len(undoStack) - 1;
        snapshot = undoStack[last_index];
        next_stack = list(undoStack[:last_index]);
        graph_snapshot = snapshot["graph"] if "graph" in snapshot else None;
        if not graph_snapshot { return; }

        isSaving = True;
        try {
            restoreResult = await root spawn RestoreGraphSnapshot(
                graphId=graph_snapshot["id"] if "id" in graph_snapshot else "",
                nodes=graph_snapshot["nodes"] if "nodes" in graph_snapshot else [],
                edges=graph_snapshot["edges"] if "edges" in graph_snapshot else []
            );
            restoreData = restoreResult["reports"][0] if restoreResult["reports"] else {};

            if "graph" in restoreData {
                restored_graph = restoreData["graph"];
                restored_positions = snapshot["layoutHints"] if "layoutHints" in snapshot else extractPositionsFromGraph(restored_graph);
                currentGraph = applyPositionsAndLocks(restored_graph, restored_positions, extractLockedNodeIdMap(graph_snapshot));
                currentScore = restoreData["score"] if "score" in restoreData else (snapshot["score"] if "score" in snapshot else {});
                currentIssues = restoreData["issues"] if "issues" in restoreData else (snapshot["issues"] if "issues" in snapshot else []);
                currentNextActions = restoreData["nextActions"] if "nextActions" in restoreData else (snapshot["nextActions"] if "nextActions" in snapshot else []);
                layoutHints = restored_positions;
                layoutHintGraphId = restored_graph["id"] if "id" in restored_graph else layoutHintGraphId;
                persistedLayoutPositions = snapshot["persistedLayoutPositions"] if "persistedLayoutPositions" in snapshot else restored_positions;
                persistedLayoutGraphId = restored_graph["id"] if "id" in restored_graph else persistedLayoutGraphId;
                graphViewVersion = graphViewVersion + 1;
                dismissedCounterargTexts = snapshot["dismissedCounterargTexts"] if "dismissedCounterargTexts" in snapshot else [];
                focusBranch = snapshot["focusBranch"] if "focusBranch" in snapshot else "";
                selectedNode = findNodeById(currentGraph, snapshot["selectedNodeId"] if "selectedNodeId" in snapshot else "");
                undoStack = next_stack;
            }
        } except Exception as e {
            print(f"ReviewScreen undo error: {e}");
        }
        isSaving = False;
        pushUpdate();
    }

    def handleNodeClick(node_data: any) -> None {
        node_id = node_data["id"] if node_data and "id" in node_data else "";
        next_focus = focusBranch;
        if focusBranch and node_id and not isNodeInFocusedBranch(node_id) {
            next_focus = node_id;
        }
        selectedNode = node_data;
        focusBranch = next_focus;
        editMode = "";
        editInputValue = "";
        sourceUrlValue = "";
        actionOwnerValue = "";
        actionDueDateValue = "";
        actionPriorityValue = "medium";
        actionStatusValue = "open";
        showConfirmDelete = False;
        showScoreDelta = False;
        showAllAssumptions = False;
        investigateResults = [];
        investigateLoading = False;
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
        sourceUrlValue = "";
        actionOwnerValue = "";
        actionDueDateValue = "";
        actionPriorityValue = "medium";
        actionStatusValue = "open";
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
                    sourceUrlValue = "";
                    actionOwnerValue = "";
                    actionDueDateValue = "";
                    actionPriorityValue = "medium";
                    actionStatusValue = "open";
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
        sourceUrlValue = "";
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
        if mode == "next_action" {
            editMode = mode;
            editInputValue = "";
            actionOwnerValue = "";
            actionDueDateValue = "";
            actionPriorityValue = "medium";
            actionStatusValue = "open";
            return;
        }
        if mode == "edit_action" {
            editMode = mode;
            editInputValue = selectedNode["content"] if selectedNode and "content" in selectedNode else "";
            actionOwnerValue = firstOwnerText(selectedNode);
            actionDueDateValue = selectedNode["dueDate"] if selectedNode and "dueDate" in selectedNode else (selectedNode["due_date"] if selectedNode and "due_date" in selectedNode else "");
            actionPriorityValue = selectedNode["priority"] if selectedNode and "priority" in selectedNode and selectedNode["priority"] else "medium";
            actionStatusValue = selectedNode["taskStatus"] if selectedNode and "taskStatus" in selectedNode and selectedNode["taskStatus"] else (selectedNode["action_status"] if selectedNode and "action_status" in selectedNode and selectedNode["action_status"] else "open");
            return;
        }
        editMode = mode;
        editInputValue = "";
        actionOwnerValue = "";
        actionDueDateValue = "";
        actionPriorityValue = "medium";
        actionStatusValue = "open";
    }

    async def handleGenerateCounter() -> None {
        if not selectedNode or not currentGraph { return; }
        isSaving = True;
        pushUndoSnapshot("Generate counter");
        _gcGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _gcNodeId = selectedNode["id"];
        _gcPrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        _gcPreservedPositions = getStableLayoutPositions();
        _gcPreservedNodeIds = extractLockedNodeIdMap(currentGraph);
        try {
            await flushLayoutToBackend();
            mutResult = await root spawn GenerateCounter(graphId=_gcGraphId, targetNodeId=_gcNodeId);
            mutData = mutResult["reports"][0] if mutResult["reports"] else {};
            _freshGraph = applyMutationGraph(mutData, _gcPreservedPositions, _gcPreservedNodeIds);
            if "score" in mutData {
                currentScore = mutData["score"];
                _gcNewScore = currentScore["overall"] if "overall" in currentScore else _gcPrevScore;
                applyScoreDelta(_gcPrevScore, _gcNewScore);
            }
            if "issues" in mutData { currentIssues = mutData["issues"]; }
            if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
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
        pushUndoSnapshot("Add investigated evidence");
        _pirGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _pirNodeId = selectedNode["id"];
        _pirPrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        _pirPreservedPositions = getStableLayoutPositions();
        _pirPreservedNodeIds = extractLockedNodeIdMap(currentGraph);
        try {
            await flushLayoutToBackend();
            mutResult = await root spawn InvestigateNode(
                graphId=_pirGraphId, nodeId=_pirNodeId,
                selectedResultIndex=resultIndex, addAsEvidence=True,
                selectedTitle=pickedTitle, selectedUrl=pickedUrl
            );
            mutData = mutResult["reports"][0] if mutResult["reports"] else {};
            _freshGraph = applyMutationGraph(mutData, _pirPreservedPositions, _pirPreservedNodeIds);
            if "score" in mutData {
                currentScore = mutData["score"];
                _pirNewScore = currentScore["overall"] if "overall" in currentScore else _pirPrevScore;
                applyScoreDelta(_pirPrevScore, _pirNewScore);
            }
            if "issues" in mutData { currentIssues = mutData["issues"]; }
            if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
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
        pushUndoSnapshot("Auto-fix node");
        _afGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _afNodeId = selectedNode["id"];
        _afPrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        _afPreservedPositions = getStableLayoutPositions();
        _afPreservedNodeIds = extractLockedNodeIdMap(currentGraph);
        try {
            await flushLayoutToBackend();
            mutResult = await root spawn InvestigateNode(graphId=_afGraphId, nodeId=_afNodeId, addAsEvidence=True);
            mutData = mutResult["reports"][0] if mutResult["reports"] else {};
            _freshGraph = applyMutationGraph(mutData, _afPreservedPositions, _afPreservedNodeIds);
            if "score" in mutData {
                currentScore = mutData["score"];
                _afNewScore = currentScore["overall"] if "overall" in currentScore else _afPrevScore;
                applyScoreDelta(_afPrevScore, _afNewScore);
            }
            if "issues" in mutData { currentIssues = mutData["issues"]; }
            if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
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
        pushUndoSnapshot("Add evidence");
        _aeGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _aeNodeId = selectedNode["id"];
        _aePrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        _aePreservedPositions = getStableLayoutPositions();
        _aePreservedNodeIds = extractLockedNodeIdMap(currentGraph);
        try {
            await flushLayoutToBackend();
            mutResult = await root spawn AddEvidenceToNode(
                graphId=_aeGraphId, nodeId=_aeNodeId,
                evidenceContent=_aeMoreInfo, sourceUrl=_aeSourceUrl
            );
            mutData = mutResult["reports"][0] if mutResult["reports"] else {};
            _freshGraph = applyMutationGraph(mutData, _aePreservedPositions, _aePreservedNodeIds);
            if "score" in mutData {
                currentScore = mutData["score"];
                _aeNewScore = currentScore["overall"] if "overall" in currentScore else _aePrevScore;
                applyScoreDelta(_aePrevScore, _aeNewScore);
            }
            if "issues" in mutData { currentIssues = mutData["issues"]; }
            if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
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
        actionOwnerValue = "";
        actionDueDateValue = "";
        actionPriorityValue = "medium";
        actionStatusValue = "open";
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

    def handleActionOwnerInput(e: any) -> None {
        actionOwnerValue = e.target.value;
    }

    def handleActionDueDateInput(e: any) -> None {
        actionDueDateValue = e.target.value;
    }

    def handleActionPriorityInput(e: any) -> None {
        actionPriorityValue = e.target.value;
    }

    def handleActionStatusInput(e: any) -> None {
        actionStatusValue = e.target.value;
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
        _undo_label = "Edit graph";
        if editMode == "address" {
            _undo_label = "Add response";
        } elif editMode == "evidence" or editMode == "respond" {
            _undo_label = "Add evidence";
        } elif editMode == "next_action" {
            _undo_label = "Add next action";
        } elif editMode == "edit_action" {
            _undo_label = "Edit next action";
        }
        pushUndoSnapshot(_undo_label);
        _seGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _seNodeId = selectedNode["id"];
        _seMode = editMode;
        _seContent = editInputValue.strip();
        _sePrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        _sePreservedPositions = getStableLayoutPositions();
        _sePreservedNodeIds = extractLockedNodeIdMap(currentGraph);

        _seDefendId = "";
        if _seMode == "address" {
            _seEdges = currentGraph["edges"] if "edges" in currentGraph else [];
            _sei = 0;
            while _sei < len(_seEdges) {
                _see = _seEdges[_sei];
                _seSrc = _see["source"] if "source" in _see else "";
                _seTyp = edgeRole(_see);
                if _seSrc == _seNodeId and _seTyp == ("OPPOSES" if is_business_mode else "CONTRADICTS") {
                    _seDefendId = _see["target"] if "target" in _see else "";
                    break;
                }
                _sei = _sei + 1;
            }
            if not _seDefendId { _seDefendId = _seNodeId; }
        }

        try {
            await flushLayoutToBackend();
            mutResult = None;
            if _seMode == "evidence" or _seMode == "respond" {
                _seSourceUrl = sourceUrlValue.strip() if sourceUrlValue else "";
                mutResult = await root spawn AddEvidenceToNode(
                    graphId=_seGraphId, nodeId=_seNodeId, evidenceContent=_seContent, sourceUrl=_seSourceUrl, evaluate=True
                );
            } elif _seMode == "next_action" {
                mutResult = await root spawn AddNextActionNode(
                    graphId=_seGraphId,
                    targetNodeId=_seNodeId,
                    actionContent=_seContent,
                    owner=actionOwnerValue.strip(),
                    dueDate=actionDueDateValue.strip(),
                    priority=actionPriorityValue.strip(),
                    taskStatus=actionStatusValue.strip()
                );
            } elif _seMode == "edit_action" {
                mutResult = await root spawn UpdateNodeContent(
                    graphId=_seGraphId,
                    nodeId=_seNodeId,
                    newContent=_seContent,
                    owner=actionOwnerValue.strip(),
                    dueDate=actionDueDateValue.strip(),
                    priority=actionPriorityValue.strip(),
                    taskStatus=actionStatusValue.strip()
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
                _freshGraph = applyMutationGraph(mutData, _sePreservedPositions, _sePreservedNodeIds);
                if "score" in mutData {
                    currentScore = mutData["score"];
                    _seNewScore = currentScore["overall"] if "overall" in currentScore else _sePrevScore;
                    applyScoreDelta(_sePrevScore, _seNewScore);
                }
                if "issues" in mutData { currentIssues = mutData["issues"]; }
                if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
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
        actionOwnerValue = "";
        actionDueDateValue = "";
        actionPriorityValue = "medium";
        actionStatusValue = "open";
        isSaving = False;
        pushUpdate();
    }

    async def handleDelete() -> None {
        if not currentGraph { return; }
        _delNodeId = selectedNode["id"] if selectedNode and "id" in selectedNode else "";
        if not _delNodeId { return; }
        pushUndoSnapshot("Delete node");
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
        _delPreservedPositions = getStableLayoutPositions();
        _delPreservedNodeIds = extractLockedNodeIdMap(currentGraph);

        try {
            await flushLayoutToBackend();
            mutResult = await root spawn DeleteNode(graphId=_delGraphId, nodeId=_delNodeId);
            mutData = mutResult["reports"][0] if mutResult["reports"] else {};
            applyMutationGraph(mutData, _delPreservedPositions, _delPreservedNodeIds);
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
        pushUndoSnapshot("Add counterargument");
        _acGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _acPrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        _acPreservedPositions = getStableLayoutPositions();
        _acPreservedNodeIds = extractLockedNodeIdMap(currentGraph);

        try {
            await flushLayoutToBackend();
            addResult = await root spawn AddCounterargumentNode(
                graphId=_acGraphId, targetNodeId=ca_target, counterargContent=ca_text
            );
            addData = addResult["reports"][0] if addResult["reports"] else {};
            applyMutationGraph(addData, _acPreservedPositions, _acPreservedNodeIds);
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
        pushUndoSnapshot("Expand branch");
        _ebGraphId = currentGraph["id"] if "id" in currentGraph else "";
        _ebNodeId = selectedNode["id"];
        _ebPrevScore = currentScore["overall"] if currentScore and "overall" in currentScore else 0;
        _ebPreservedPositions = getStableLayoutPositions();
        _ebPreservedNodeIds = extractLockedNodeIdMap(currentGraph);
        try {
            await flushLayoutToBackend();
            mutResult = await root spawn ExpandBranch(graphId=_ebGraphId, nodeId=_ebNodeId);
            mutData = mutResult["reports"][0] if mutResult["reports"] else {};
            _freshGraph = applyMutationGraph(mutData, _ebPreservedPositions, _ebPreservedNodeIds);
            if "score" in mutData {
                currentScore = mutData["score"];
                _ebNewScore = currentScore["overall"] if "overall" in currentScore else _ebPrevScore;
                applyScoreDelta(_ebPrevScore, _ebNewScore);
            }
            if "issues" in mutData { currentIssues = mutData["issues"]; }
            if "nextActions" in mutData { currentNextActions = mutData["nextActions"]; }
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

    graph_mode = graphMode();
    is_business_mode = isBusinessGraph();
    graph_nodes = currentGraph["nodes"] if "nodes" in currentGraph else [];
    graph_edges = currentGraph["edges"] if "edges" in currentGraph else [];
    graph_title = currentGraph["title"] if "title" in currentGraph and currentGraph["title"] else (
        "Decision board" if is_business_mode else "Argument map"
    );
    graph_summary = currentGraph["summary"] if "summary" in currentGraph else "";

    overall = currentScore["overall"] if "overall" in currentScore else 0;
    overall_display = "—" if is_business_mode and "readinessStatus" in currentScore and currentScore["readinessStatus"] == "DISCUSSION_ONLY" else str(overall);
    score_good_threshold = 85 if is_business_mode else 80;
    score_warn_threshold = 70 if is_business_mode else 65;
    scoreColor = "#16a34a" if overall >= score_good_threshold else ("#ca8a04" if overall >= score_warn_threshold else "#dc2626");

    delta_text = "";
    delta_color = "#16a34a";
    if showScoreDelta and scoreDelta != 0 {
        delta_sign = "+" if scoreDelta > 0 else "";
        delta_text = f"({delta_sign}{scoreDelta})";
        delta_color = "#16a34a" if scoreDelta > 0 else "#dc2626";
    }

    support_val = currentScore["rootSupportCoverage"] if "rootSupportCoverage" in currentScore else (currentScore["support"] if "support" in currentScore else 0);
    premise_val = currentScore["evidenceQuality"] if "evidenceQuality" in currentScore else (currentScore["premise"] if "premise" in currentScore else 0);
    coherence_val = currentScore["structuralCoherence"] if "structuralCoherence" in currentScore else (currentScore["coherence"] if "coherence" in currentScore else 0);
    counter_val = currentScore["dialecticalHandling"] if "dialecticalHandling" in currentScore else (
        currentScore["counterargument"] if "counterargument" in currentScore else (
            currentScore["consistency"] if "consistency" in currentScore else 0
        )
    );
    assumption_val = currentScore["assumptionExplicitness"] if "assumptionExplicitness" in currentScore else (currentScore["premise"] if "premise" in currentScore else 0);
    thesis_val = currentScore["thesisClarity"] if "thesisClarity" in currentScore else 0;
    support_bar_color = "#10b981" if support_val >= 70 else ("#f59e0b" if support_val >= 50 else "#ef4444");
    premise_bar_color = "#10b981" if premise_val >= 70 else ("#f59e0b" if premise_val >= 50 else "#ef4444");
    coherence_bar_color = "#10b981" if coherence_val >= 70 else ("#f59e0b" if coherence_val >= 50 else "#ef4444");
    counter_bar_color = "#10b981" if counter_val >= 70 else ("#f59e0b" if counter_val >= 50 else "#ef4444");
    assumption_bar_color = "#10b981" if assumption_val >= 70 else ("#f59e0b" if assumption_val >= 50 else "#ef4444");
    thesis_bar_color = "#10b981" if thesis_val >= 70 else ("#f59e0b" if thesis_val >= 50 else "#ef4444");

    business_decision_val = currentScore["decisionFraming"] if "decisionFraming" in currentScore else (currentScore["decisionClarity"] if "decisionClarity" in currentScore else 0);
    business_option_val = currentScore["optionSetQuality"] if "optionSetQuality" in currentScore else (currentScore["optionCoverage"] if "optionCoverage" in currentScore else 0);
    business_evidence_val = currentScore["evidenceStrength"] if "evidenceStrength" in currentScore else 0;
    business_risk_val = currentScore["riskObjectionHandling"] if "riskObjectionHandling" in currentScore else (currentScore["riskCoverage"] if "riskCoverage" in currentScore else 0);
    business_question_val = currentScore["assumptionQuestionHandling"] if "assumptionQuestionHandling" in currentScore else (currentScore["openQuestionHandling"] if "openQuestionHandling" in currentScore else 0);
    business_action_val = currentScore["actionabilityOwnership"] if "actionabilityOwnership" in currentScore else (currentScore["actionability"] if "actionability" in currentScore else 0);
    business_traceability_val = currentScore["traceabilityHygiene"] if "traceabilityHygiene" in currentScore else 0;
    readiness_status = currentScore["readinessStatus"] if "readinessStatus" in currentScore else "NEEDS_FOLLOW_UP";
    readiness_color = "#64748b" if readiness_status == "DISCUSSION_ONLY" else ("#16a34a" if readiness_status == "READY" else ("#f59e0b" if readiness_status == "NEEDS_FOLLOW_UP" else "#dc2626"));
    if is_business_mode and readiness_status == "DISCUSSION_ONLY" {
        scoreColor = "#64748b";
    }

    def scoreSignalLabel(score_value: int) -> str {
        if score_value >= 80 { return "Strong"; }
        if score_value >= 60 { return "Watch"; }
        return "Weak";
    }

    def scoreSignalColor(score_value: int) -> str {
        if score_value >= 80 { return "#16a34a"; }
        if score_value >= 60 { return "#d97706"; }
        return "#dc2626";
    }

    business_decision_signal = scoreSignalLabel(business_decision_val);
    business_option_signal = scoreSignalLabel(business_option_val);
    business_evidence_signal = scoreSignalLabel(business_evidence_val);
    business_risk_signal = scoreSignalLabel(business_risk_val);
    business_question_signal = scoreSignalLabel(business_question_val);
    business_action_signal = scoreSignalLabel(business_action_val);
    business_traceability_signal = scoreSignalLabel(business_traceability_val);

    business_decision_color = scoreSignalColor(business_decision_val);
    business_option_color = scoreSignalColor(business_option_val);
    business_evidence_color = scoreSignalColor(business_evidence_val);
    business_risk_color = scoreSignalColor(business_risk_val);
    business_question_color = scoreSignalColor(business_question_val);
    business_action_color = scoreSignalColor(business_action_val);
    business_traceability_color = scoreSignalColor(business_traceability_val);

    typeLegend = [
        {"key": "DECISION", "color": "#3b82f6", "bg": "#DBEAFE", "label": "Decision"},
        {"key": "OPTION", "color": "#9f7aea", "bg": "#e8e0fc", "label": "Option"},
        {"key": "EVIDENCE", "color": "#10b981", "bg": "#d1fae5", "label": "Evidence"},
        {"key": "RISK", "color": "#ef4444", "bg": "#fee2e2", "label": "Risk"}
    ] if is_business_mode else [
        {"key": "THESIS", "color": "#3b82f6", "bg": "#DBEAFE", "label": "Thesis"},
        {"key": "CLAIM", "color": "#9f7aea", "bg": "#e8e0fc", "label": "Claim"},
        {"key": "EVIDENCE", "color": "#10b981", "bg": "#d1fae5", "label": "Evidence"},
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
    sel_role = semanticRole(_fresh_sel) if _fresh_sel else "";

    sel_str_color = "#16a34a" if sel_node_score >= 70 else ("#ca8a04" if sel_node_score >= 50 else "#dc2626");
    sel_str_bg = "rgba(34,197,94,0.1)" if sel_node_score >= 70 else ("rgba(250,204,21,0.15)" if sel_node_score >= 50 else "rgba(239,68,68,0.1)");

    typeColorMap = {
        "THESIS":          "#3b82f6",
        "CLAIM":           "#9f7aea",
        "EVIDENCE":        "#10b981",
        "COUNTERARGUMENT": "#ef4444"
    };
    roleColorMap = {
        "DECISION": "#3b82f6",
        "OPTION": "#9f7aea",
        "EVIDENCE": "#10b981",
        "RISK": "#ef4444",
        "ASSUMPTION": "#64748b",
        "OPEN_QUESTION": "#d97706",
        "ACTION": "#0f766e"
    };
    sel_type_label = semanticRoleLabel(sel_role, sel_type) if is_business_mode else sel_type;
    sel_type_color = roleColorMap[sel_role] if is_business_mode and sel_role in roleColorMap else (typeColorMap[sel_type] if sel_type in typeColorMap else "#3b82f6");

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
    sel_owner = firstOwnerText(_fresh_sel);
    sel_due_date = _fresh_sel["dueDate"] if _fresh_sel and "dueDate" in _fresh_sel else (_fresh_sel["due_date"] if _fresh_sel and "due_date" in _fresh_sel else "");
    sel_priority = _fresh_sel["priority"] if _fresh_sel and "priority" in _fresh_sel else "";
    sel_task_status = _fresh_sel["taskStatus"] if _fresh_sel and "taskStatus" in _fresh_sel else (_fresh_sel["action_status"] if _fresh_sel and "action_status" in _fresh_sel else "");
    sel_is_next_action = sel_role == "ACTION";
    sel_business_context = "";
    if is_business_mode {
        if sel_role == "DECISION" {
            sel_business_context = "This is the current decision framing. Tighten it if the team is still debating what exactly is being decided.";
        } elif sel_role == "OPTION" {
            sel_business_context = "This is one option on the table. Compare it against alternatives, evidence, and risk before closing the meeting.";
        } elif sel_role == "EVIDENCE" {
            sel_business_context = "This is supporting evidence. Use it to justify why an option or the decision is credible enough to move forward.";
        } elif sel_role == "RISK" {
            sel_business_context = "This is a risk or objection. Capture blockers here and add mitigations or owners if the team still plans to proceed.";
        } elif sel_role == "OPEN_QUESTION" {
            sel_business_context = "This is an unresolved question. If it blocks the decision, connect it to a concrete follow-up or owner.";
        } elif sel_role == "ASSUMPTION" {
            sel_business_context = "This is an assumption the team is relying on. Challenge it if the decision depends too heavily on it being true.";
        } elif sel_role == "ACTION" {
            sel_business_context = "This is a follow-up task. Make sure it has a clear owner, timing, and status before the meeting ends.";
        }
    }

    issues_section_title = "Issues & Next Steps" if not is_business_mode else "What still needs follow-up";
    actions_section_title = "Quick Actions" if not is_business_mode else "Decision Actions";
    research_section_title = "Wikipedia Sources" if not is_business_mode else "Supporting Research";
    research_disclaimer_text = "Sources come from Wikipedia and may not be fully reliable. Always verify before citing."
        if not is_business_mode else
        "These research suggestions are directional context for the decision board. Verify them before using them in a real business decision.";
    research_loading_text = "Searching Wikipedia..." if not is_business_mode else "Researching supporting context...";
    context_section_title = "Analysis & Source" if not is_business_mode else "Supporting Context";
    context_empty_text = "No additional analysis available" if not is_business_mode else "No supporting context is attached to this item yet.";
    action_details_title = "Action Details" if not is_business_mode else "Follow-up Details";
    quality_section_title = "Node Quality" if not is_business_mode else "Decision Impact";
    no_issue_text = "No issues found ✓" if not is_business_mode else "This item looks usable right now.";
    add_evidence_label = "📊 Add as Evidence" if not is_business_mode else "Add to Board as Evidence";
    research_dismiss_label = "Dismiss" if not is_business_mode else "Close research";
    sourced_badge_label = "Sourced" if not is_business_mode else "Evidence linked";
    delete_title_text = "Delete this node?" if not is_business_mode else "Remove this item from the board?";
    delete_warning_text = "This will remove the node and all its connections. You can undo this from the review toolbar."
        if not is_business_mode else
        "This will remove the item and its linked relationships from the decision board. You can undo this from the review toolbar.";

    edit_label = "Respond";
    edit_placeholder = "Add evidence, reasoning, or a rebuttal...";
    if editMode == "address" {
        edit_label = "Address This Counterargument" if not is_business_mode else "Address This Risk";
        edit_placeholder = "How would you respond to this counterargument? Provide evidence or reasoning..."
            if not is_business_mode else
            "How would you reduce or respond to this risk? Add mitigation, evidence, or context...";
    } elif editMode == "evidence" {
        edit_label = "Add Evidence";
        edit_placeholder = "Add a fact, statistic, study, or expert quote...";
    } elif editMode == "next_action" {
        edit_label = "Add Next Action";
        edit_placeholder = "Add a concrete follow-up task that helps move this decision forward...";
    } elif editMode == "edit_action" {
        edit_label = "Edit Next Action";
        edit_placeholder = "Update this next action so the team knows exactly what needs to happen...";
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

    business_decision_nodes = nodesForRole(graph_nodes, "DECISION");
    business_option_nodes = nodesForRole(graph_nodes, "OPTION");
    business_evidence_nodes = nodesForRole(graph_nodes, "EVIDENCE");
    business_risk_nodes = nodesForRole(graph_nodes, "RISK");
    business_assumption_nodes = nodesForRole(graph_nodes, "ASSUMPTION");
    business_question_nodes = nodesForRole(graph_nodes, "OPEN_QUESTION");
    business_next_action_nodes = nodesForRole(graph_nodes, "ACTION");
    business_option_count = len(business_option_nodes);
    business_evidence_count = len(business_evidence_nodes);
    business_risk_count = len(business_risk_nodes);
    business_question_count = len(business_question_nodes);
    business_action_total = len(business_next_action_nodes);
    decision_text = business_decision_nodes[0]["content"] if len(business_decision_nodes) > 0 and "content" in business_decision_nodes[0] else "Decision still under discussion";
    decision_summary_text = graph_summary if graph_summary else "Review whether the team has enough evidence, risk coverage, and follow-up to make this decision confidently.";
    readiness_label = readiness_status.replace("_", " ");
    business_readiness_copy = "This board is still in discussion mode. Capture one clear decision before using readiness as the headline signal."
        if readiness_status == "DISCUSSION_ONLY" else (
        "The decision looks ready to share. The remaining work is mostly execution and communication."
        if readiness_status == "READY" else (
            "The team is close, but a few blockers, ownership gaps, or unanswered questions still need follow-up."
            if readiness_status == "NEEDS_FOLLOW_UP" else
            "The board is not ready for a final call yet. It still needs clearer support, fewer blockers, or concrete follow-up."
        ));

    def buildBoardPreviewElements(role_nodes: list, empty_text: str, include_action_meta: bool = False) -> list {
        result: list = [];
        if len(role_nodes) == 0 {
            result.append(<div key="empty" className="rs-business-board-empty">{empty_text}</div>);
            return result;
        }

        node_count = len(role_nodes);
        if node_count > 4 { node_count = 4; }
        ni = 0;
        while ni < node_count {
            role_node = role_nodes[ni];
            row_text = role_node["content"] if "content" in role_node else "";
            meta_text = "";
            if include_action_meta {
                owner_text = firstOwnerText(role_node);
                due_text = role_node["dueDate"] if "dueDate" in role_node else (role_node["due_date"] if "due_date" in role_node else "");
                priority_text = role_node["priority"] if "priority" in role_node else "";
                status_text = role_node["taskStatus"] if "taskStatus" in role_node else (role_node["action_status"] if "action_status" in role_node else "");
                meta_text = owner_text if owner_text else "Owner TBD";
                if due_text { meta_text = meta_text + " · Due " + due_text; }
                if priority_text { meta_text = meta_text + " · " + priority_text + " priority"; }
                if status_text { meta_text = meta_text + " · " + status_text; }
            }
            result.append(
                <div
                    key={role_node["id"] if "id" in role_node else str(ni)}
                    className="rs-business-board-item"
                >
                    <div className="rs-business-board-item-text">{row_text}</div>
                    {(
                        <div className="rs-business-board-item-meta">{meta_text}</div>
                    ) if include_action_meta and meta_text else None}
                </div>
            );
            ni = ni + 1;
        }

        if len(role_nodes) > node_count {
            result.append(
                <div key="more" className="rs-business-board-more">
                    {f"+{len(role_nodes) - node_count} more"}
                </div>
            );
        }
        return result;
    }

    decisionPreviewElements = buildBoardPreviewElements(business_decision_nodes, "No clear decision extracted yet.");
    optionPreviewElements = buildBoardPreviewElements(business_option_nodes, "No explicit options found.");
    evidencePreviewElements = buildBoardPreviewElements(business_evidence_nodes, "No supporting evidence captured yet.");
    riskPreviewElements = buildBoardPreviewElements(business_risk_nodes, "No major risks captured yet.");
    assumptionPreviewElements = buildBoardPreviewElements(business_assumption_nodes, "No clear assumptions extracted.");
    questionPreviewElements = buildBoardPreviewElements(business_question_nodes, "No open questions captured.");
    businessActionPreviewElements = buildBoardPreviewElements(business_next_action_nodes, "No next actions assigned yet.", True);

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
        sev_value = iss["severity"] if "severity" in iss else "moderate";
        sev_bg = "#fef2f2" if sev_value in ["critical", "major", "high"] else ("#fffbeb" if sev_value in ["moderate", "medium"] else "#f8fafc");
        sev_color = "#ef4444" if sev_value in ["critical", "major", "high"] else ("#f59e0b" if sev_value in ["moderate", "medium"] else "#64748b");
        iss_node_id = iss["nodeId"] if "nodeId" in iss else "";
        iss_click_fn = makeIssueClickHandler(iss_node_id);
        topIssueElements.append(
            <div key={iss["id"]} className="rs-issue-card-default" onClick={iss_click_fn}>
                <div className="rs-severity-row">
                    <span className="rs-severity-badge"
                        style={{"background": sev_bg, "color": sev_color}}>
                        {sev_value}
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

    business_high_blocker_count = 0;
    _bhi = 0;
    while _bhi < len(issues_safe) {
        if "severity" in issues_safe[_bhi] and (issues_safe[_bhi]["severity"] == "critical" or issues_safe[_bhi]["severity"] == "major" or issues_safe[_bhi]["severity"] == "high") {
            business_high_blocker_count = business_high_blocker_count + 1;
        }
        _bhi = _bhi + 1;
    }

    business_owned_action_count = 0;
    _boi = 0;
    while _boi < len(business_next_action_nodes) {
        _boa = business_next_action_nodes[_boi];
        _has_owner = len(firstOwnerText(_boa)) > 0;
        if _has_owner {
            business_owned_action_count = business_owned_action_count + 1;
        }
        _boi = _boi + 1;
    }

    business_primary_blocker = issues_safe[0]["description"] if len(issues_safe) > 0 and "description" in issues_safe[0] else "No major blocker surfaced right now.";
    business_primary_followup = next_actions_safe[0]["action"] if len(next_actions_safe) > 0 and "action" in next_actions_safe[0] else (
        business_next_action_nodes[0]["content"] if len(business_next_action_nodes) > 0 and "content" in business_next_action_nodes[0] else "No immediate follow-up has been assigned yet."
    );

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
                <button onClick={ca_accept_fn} className="rs-accept-btn">
                    {"Add to Graph" if not is_business_mode else "Add Risk"}
                </button>
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
                "role": "RISK" if is_business_mode else "",
                "ghostTarget": gca_target
            });
            ghost_edge_role = "OPPOSES" if is_business_mode else "CONTRADICTS";
            ghostEdges.append({
                "id": f"ghost_edge_{_gi}",
                "source": ghost_id,
                "target": gca_target,
                "type": ghost_edge_role,
                "role": ghost_edge_role,
                "isGhost": True
            });
        }
        _gi = _gi + 1;
    }

    allNodes = list(graph_nodes) + ghostNodes;
    allEdges = list(graph_edges) + ghostEdges;
    graph_view_key = f"{currentGraph['id'] if 'id' in currentGraph else 'graph'}:{graphViewVersion}";
    node_count_str = str(len(graph_nodes)) if graph_nodes else "0";
    edge_count_str = str(len(graph_edges)) if graph_edges else "0";
    has_undo = len(undoStack) > 0;
    last_undo_label = undoStack[len(undoStack) - 1]["label"] if has_undo and "label" in undoStack[len(undoStack) - 1] else "last change";

    saving_overlay_display = "flex" if isSaving else "none";

    show_respond = sel_type != "";
    show_add_counter = (sel_type == "CLAIM" or sel_type == "THESIS" or sel_type == "COUNTERARGUMENT") and sel_role != "ACTION";
    show_address = sel_type == "COUNTERARGUMENT";
    show_expand = (sel_type == "CLAIM" or sel_type == "THESIS" or sel_type == "COUNTERARGUMENT") and sel_role != "ACTION";
    show_add_next_action = is_business_mode and selectedNode and sel_role != "ACTION" and sel_type != "EVIDENCE";
    show_edit_next_action = is_business_mode and sel_is_next_action;
    show_source_input = editMode == "evidence" or editMode == "respond";
    show_action_fields = editMode == "next_action" or editMode == "edit_action";
    has_investigate_results = len(investigateResults) > 0;
    counter_button_label = "Counter" if not is_business_mode else "Add Risk";
    counter_button_title = "Generate a counterargument against this claim" if not is_business_mode else "Generate a risk or objection against this option";
    expand_button_label = "Expand" if not is_business_mode else "Expand Branch";
    expand_button_title = "Break this claim into sub-claims and evidence" if not is_business_mode else "Expand this branch into more options, support, or follow-up";
    investigate_button_label = "Investigate" if not is_business_mode else "Research";
    investigate_button_title = "Find Wikipedia sources related to this node" if not is_business_mode else "Find supporting context or evidence for this node";
    respond_button_label = "Respond" if not is_business_mode else ("Address Risk" if show_address else "Add Support");
    review_title = "Review Map" if not is_business_mode else "Decision Review";
    readiness_badge_class = "rs-business-status-badge rs-business-status-ready" if readiness_status == "READY" else (
        "rs-business-status-badge rs-business-status-followup" if readiness_status == "NEEDS_FOLLOW_UP" else
        "rs-business-status-badge rs-business-status-notready"
    );

    return (
        <div className="rs-wrapper">

            <Header screen="review" title={review_title} onExport={lambda -> None {
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
                            key={graph_view_key}
                            nodes={allNodes}
                            edges={allEdges}
                            graphMode={graph_mode}
                            onNodeClick={handleNodeClick}
                            selectedNodeId={selectedNode["id"] if selectedNode else None}
                            focusBranch={focusBranch}
                            onGhostAccept={handleAcceptCounterarg}
                            layoutHints={layoutHints}
                            onLayoutResolved={handleLayoutResolved}
                            onNodePositionsChange={handleNodePositionsChange}
                        />
                    </div>

                    <div className="rs-statusbar">
                        <span className="rs-statusbar-label">{"Sources" if not is_business_mode else "Board"}</span>
                        <span className="rs-statusbar-text">
                            {node_count_str} nodes - {edge_count_str} edges
                        </span>
                        <div style={{"flex": "1"}}></div>
                        <Button
                            label={f"Undo {last_undo_label}" if has_undo else "Undo"}
                            onClick={handleUndo}
                            variant="secondary"
                            disabled={not has_undo or isSaving}
                        />
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
                                    <div className="rs-tutorial-title">{"Explore your argument" if not is_business_mode else "Explore your decision board"}</div>
                                    <div className="rs-tutorial-text">
                                        {"Click any node in the graph to view its quality score and details."
                                            if not is_business_mode else
                                            "Click any node to inspect the current decision, options, evidence, risks, and follow-up details."}
                                    </div>
                                    <button className="rs-tutorial-next" onClick={lambda -> None { tutorialStep = 2; }}>
                                        Next
                                    </button>
                                </div>
                            ) if tutorialStep == 1 else None}
                            {(
                                <div>
                                    <div className="rs-tutorial-step-label">Step 2 of 3</div>
                                    <div className="rs-tutorial-title">{"Take action" if not is_business_mode else "Stress-test the decision"}</div>
                                    <div className="rs-tutorial-text">
                                        {"Use the action buttons to respond, counter, expand, or investigate a node."
                                            if not is_business_mode else
                                            "Use the actions to add risks, supporting evidence, research, and concrete next steps before the meeting ends."}
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
                                    <div className="rs-tutorial-title">{"Improve your score" if not is_business_mode else "Check readiness"}</div>
                                    <div className="rs-tutorial-text">
                                        {"Check the issues panel for weaknesses and follow the suggested next actions to strengthen your argument."
                                            if not is_business_mode else
                                            "Use blockers and next actions to see whether the team is truly ready to decide or still needs follow-up."}
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
                                        {sel_type_label}
                                    </span>
                                </div>
                                <button className="rs-panel-close-btn" onClick={closePanel}>✕</button>
                            </div>
                            <h3 className="rs-panel-node-title">{sel_content}</h3>
                            {(
                                <div className="rs-business-node-context">{sel_business_context}</div>
                            ) if is_business_mode and sel_business_context else None}
                        </div>

                        <div className="rs-panel-scroll">

                            <div className="rs-panel-section">
                                <div className="rs-section-heading rs-section-heading-issues">
                                    <span className="rs-section-dot rs-section-dot-issues"></span>
                                    {issues_section_title}
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
                                    <div className="rs-well-supported">{no_issue_text}</div>
                                )}
                            </div>

                            <div className="rs-panel-section">
                                <div className="rs-section-heading rs-section-heading-actions">
                                    <span className="rs-section-dot rs-section-dot-actions"></span>
                                    {actions_section_title}
                                </div>
                                <div className="rs-actions-grid">
                                    {(
                                        <button className="rs-action-btn rs-action-btn-respond"
                                            onClick={lambda -> None { startEdit("address"); }}
                                            title={"Add evidence or reasoning to address this counterargument" if not is_business_mode else "Add mitigation, ownership, or evidence to address this risk"}>
                                            {respond_button_label}
                                        </button>
                                    ) if show_address else (
                                        <button className="rs-action-btn rs-action-btn-respond"
                                            onClick={lambda -> None { startEdit("respond"); }}
                                            title={"Add supporting evidence or reasoning to this node" if not is_business_mode else "Add support, evidence, or context to this item"}>
                                            {respond_button_label}
                                        </button>
                                    ) if show_respond else None}
                                    {(
                                        <button className="rs-action-btn rs-action-btn-counter"
                                            onClick={lambda -> None { startEdit("counter"); }}
                                            title={counter_button_title}>
                                            {counter_button_label}
                                        </button>
                                    ) if show_add_counter else None}
                                    {(
                                        <button className="rs-action-btn rs-action-btn-expand"
                                            onClick={handleExpandBranch}
                                            title={expand_button_title}>
                                            {expand_button_label}
                                        </button>
                                    ) if show_expand else None}
                                    {(
                                        <button className="rs-action-btn rs-action-btn-default"
                                            onClick={lambda -> None { startEdit("next_action"); }}
                                            title="Add a concrete follow-up action for this business item">
                                            {"Next Action" if not is_business_mode else "Add Follow-up"}
                                        </button>
                                    ) if show_add_next_action else None}
                                    {(
                                        <button className="rs-action-btn rs-action-btn-default"
                                            onClick={lambda -> None { startEdit("edit_action"); }}
                                            title="Edit owner, due date, priority, or status for this next action">
                                            {"Edit Action" if not is_business_mode else "Edit Follow-up"}
                                        </button>
                                    ) if show_edit_next_action else None}
                                    {(
                                        <button className="rs-action-btn rs-action-btn-default"
                                            onClick={lambda -> None { startEdit("investigate"); }}
                                            title={investigate_button_title}>
                                            {investigate_button_label}
                                        </button>
                                    ) if not sel_is_well_sourced else (
                                        <span className="rs-sourced-badge">{sourced_badge_label}</span>
                                    )}
                                </div>
                                <div className="rs-actions-delete-row">
                                    <button className="rs-action-btn rs-action-btn-delete"
                                        onClick={lambda -> None { startEdit("delete"); }}
                                        title="Remove this node and its connections">
                                        {"Delete" if not is_business_mode else "Remove"}
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
                                    {(
                                        <div style={{"display": "grid", "gap": "10px", "marginTop": "12px"}}>
                                            <input type="text"
                                                className="rs-edit-source-input"
                                                value={actionOwnerValue}
                                                onChange={handleActionOwnerInput}
                                                placeholder="Owner (optional)" />
                                            <input type="text"
                                                className="rs-edit-source-input"
                                                value={actionDueDateValue}
                                                onChange={handleActionDueDateInput}
                                                placeholder="Due date (optional, YYYY-MM-DD)" />
                                            <input type="text"
                                                className="rs-edit-source-input"
                                                value={actionPriorityValue}
                                                onChange={handleActionPriorityInput}
                                                placeholder="Priority (low, medium, high)" />
                                            <input type="text"
                                                className="rs-edit-source-input"
                                                value={actionStatusValue}
                                                onChange={handleActionStatusInput}
                                                placeholder="Status (open, blocked, in_progress, done)" />
                                        </div>
                                    ) if show_action_fields else None}
                                    <div className="rs-edit-buttons">
                                        <button className="rs-save-btn" onClick={saveEdit}>Save</button>
                                        <Button label="Cancel" onClick={cancelEdit} variant="secondary" />
                                    </div>
                                </div>
                            ) if editMode else None}

                            {(
                                <div className="rs-delete-box">
                                    <div className="rs-delete-title">{delete_title_text}</div>
                                    <div className="rs-delete-warning">
                                        {delete_warning_text}
                                    </div>
                                    <div className="rs-edit-buttons">
                                        <button className="rs-confirm-delete-btn"
                                            onClick={handleDelete}>{"Delete" if not is_business_mode else "Remove"}</button>
                                        <Button label="Cancel" onClick={cancelEdit} variant="secondary" />
                                    </div>
                                </div>
                            ) if showConfirmDelete else None}

                            {(
                                <div className="rs-panel-section">
                                    <div className="rs-section-heading rs-section-heading-info">
                                        <span className="rs-section-dot rs-section-dot-info"></span>
                                        {research_section_title}
                                    </div>
                                    <div className="rs-wiki-disclaimer">
                                        {research_disclaimer_text}
                                    </div>
                                    {(
                                        <div className="rs-investigate-loading">
                                            {research_loading_text}
                                        </div>
                                    ) if investigateLoading else None}
                                    {investigateResultElements}
                                    <button className="rs-investigate-dismiss-btn"
                                        onClick={lambda -> None { investigateResults = []; }}>
                                        {research_dismiss_label}
                                    </button>
                                </div>
                            ) if has_investigate_results or investigateLoading else None}

                            {(
                                <div className="rs-panel-section">
                                    <div className="rs-section-heading rs-section-heading-info">
                                        <span className="rs-section-dot rs-section-dot-info"></span>
                                        {context_section_title}
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
                                            {add_evidence_label}
                                        </button>
                                    ) if sel_has_more_info and not sel_is_evidence and selectedNode and selectedNode["id"] and selectedNode["id"] not in addedAsEvidenceMap else None}
                                    {(
                                        <div className="rs-analysis-empty">{context_empty_text}</div>
                                    ) if not sel_has_more_info and not sel_has_source else None}
                                </div>
                            ) if sel_is_evidence or sel_has_more_info else None}

                            {(
                                <div className="rs-panel-section">
                                    <div className="rs-section-heading rs-section-heading-info">
                                        <span className="rs-section-dot rs-section-dot-info"></span>
                                        {action_details_title}
                                    </div>
                                    <div className="rs-analysis-text">
                                        {"Owner: " + (sel_owner if sel_owner else "Unassigned")}
                                    </div>
                                    <div className="rs-analysis-text">
                                        {"Due: " + (sel_due_date if sel_due_date else "Not set")}
                                    </div>
                                    <div className="rs-analysis-text">
                                        {"Priority: " + (sel_priority if sel_priority else "Not set")}
                                    </div>
                                    <div className="rs-analysis-text">
                                        {"Status: " + (sel_task_status if sel_task_status else "open")}
                                    </div>
                                </div>
                            ) if show_edit_next_action else None}

                            {(
                                <div className="rs-panel-section">
                                    <div className="rs-section-heading rs-section-heading-score">
                                        <span className="rs-section-dot rs-section-dot-score"></span>
                                        {quality_section_title}
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
                                        {(
                                            <div className="rs-business-quality-note">
                                                {"Higher impact means this item is clearer, better supported, and more decision-ready."}
                                            </div>
                                        ) if is_business_mode else None}
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

                            {(
                                <div className="rs-business-board">
                                    <div className="rs-default-section-header">
                                        <span className="rs-default-section-title">{graph_title}</span>
                                    </div>
                                    <div className="rs-business-hero">
                                        <div className="rs-business-hero-top">
                                            <div className="rs-business-hero-kicker">Current Decision</div>
                                            <span className={readiness_badge_class}>{readiness_label}</span>
                                        </div>
                                        <div className="rs-business-hero-title">
                                            {decision_text}
                                        </div>
                                        <div className="rs-business-hero-summary">
                                            {decision_summary_text}
                                        </div>
                                        <div className="rs-business-hero-note">{business_readiness_copy}</div>
                                        <div className="rs-business-metrics">
                                            <div className="rs-business-metric-card">
                                                <div className="rs-business-metric-label">Options</div>
                                                <div className="rs-business-metric-value">{str(business_option_count)}</div>
                                                <div className="rs-business-metric-sub">choices captured</div>
                                            </div>
                                            <div className="rs-business-metric-card">
                                                <div className="rs-business-metric-label">Evidence</div>
                                                <div className="rs-business-metric-value">{str(business_evidence_count)}</div>
                                                <div className="rs-business-metric-sub">supporting points logged</div>
                                            </div>
                                            <div className="rs-business-metric-card">
                                                <div className="rs-business-metric-label">High blockers</div>
                                                <div className="rs-business-metric-value">{str(business_high_blocker_count)}</div>
                                                <div className="rs-business-metric-sub">need active follow-up</div>
                                            </div>
                                            <div className="rs-business-metric-card">
                                                <div className="rs-business-metric-label">Owned actions</div>
                                                <div className="rs-business-metric-value">
                                                    {f"{business_owned_action_count}/{business_action_total}" if business_action_total > 0 else "0"}
                                                </div>
                                                <div className="rs-business-metric-sub">next steps with an owner</div>
                                            </div>
                                        </div>
                                        <div className="rs-business-signal-grid">
                                            <div className="rs-business-signal-card">
                                                <div className="rs-business-signal-label">Primary blocker</div>
                                                <div className="rs-business-signal-text">{business_primary_blocker}</div>
                                            </div>
                                            <div className="rs-business-signal-card">
                                                <div className="rs-business-signal-label">Most important next move</div>
                                                <div className="rs-business-signal-text">{business_primary_followup}</div>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="rs-business-board-grid">
                                        <div className="rs-business-board-card">
                                            <div className="rs-business-board-card-header">
                                                <div className="rs-business-board-card-title-wrap">
                                                    <span className="rs-business-board-card-accent rs-business-board-card-accent-options"></span>
                                                    <span className="rs-business-board-card-title">Options on the table</span>
                                                </div>
                                                <span className="rs-business-board-card-count">{str(business_option_count)}</span>
                                            </div>
                                            <div className="rs-business-board-list">{optionPreviewElements}</div>
                                        </div>
                                        <div className="rs-business-board-card">
                                            <div className="rs-business-board-card-header">
                                                <div className="rs-business-board-card-title-wrap">
                                                    <span className="rs-business-board-card-accent rs-business-board-card-accent-evidence"></span>
                                                    <span className="rs-business-board-card-title">Evidence to support the call</span>
                                                </div>
                                                <span className="rs-business-board-card-count">{str(business_evidence_count)}</span>
                                            </div>
                                            <div className="rs-business-board-list">{evidencePreviewElements}</div>
                                        </div>
                                        <div className="rs-business-board-card">
                                            <div className="rs-business-board-card-header">
                                                <div className="rs-business-board-card-title-wrap">
                                                    <span className="rs-business-board-card-accent rs-business-board-card-accent-risk"></span>
                                                    <span className="rs-business-board-card-title">Risks and objections</span>
                                                </div>
                                                <span className="rs-business-board-card-count">{str(business_risk_count)}</span>
                                            </div>
                                            <div className="rs-business-board-list">{riskPreviewElements}</div>
                                        </div>
                                        <div className="rs-business-board-card">
                                            <div className="rs-business-board-card-header">
                                                <div className="rs-business-board-card-title-wrap">
                                                    <span className="rs-business-board-card-accent rs-business-board-card-accent-question"></span>
                                                    <span className="rs-business-board-card-title">Open questions to close</span>
                                                </div>
                                                <span className="rs-business-board-card-count">{str(business_question_count)}</span>
                                            </div>
                                            <div className="rs-business-board-list">{questionPreviewElements}</div>
                                        </div>
                                        <div className="rs-business-board-card">
                                            <div className="rs-business-board-card-header">
                                                <div className="rs-business-board-card-title-wrap">
                                                    <span className="rs-business-board-card-accent rs-business-board-card-accent-assumption"></span>
                                                    <span className="rs-business-board-card-title">Assumptions in play</span>
                                                </div>
                                                <span className="rs-business-board-card-count">{str(len(business_assumption_nodes))}</span>
                                            </div>
                                            <div className="rs-business-board-list">{assumptionPreviewElements}</div>
                                        </div>
                                        <div className="rs-business-board-card">
                                            <div className="rs-business-board-card-header">
                                                <div className="rs-business-board-card-title-wrap">
                                                    <span className="rs-business-board-card-accent rs-business-board-card-accent-action"></span>
                                                    <span className="rs-business-board-card-title">Next actions before close</span>
                                                </div>
                                                <span className="rs-business-board-card-count">{str(business_action_total)}</span>
                                            </div>
                                            <div className="rs-business-board-list">{businessActionPreviewElements}</div>
                                        </div>
                                    </div>
                                </div>
                            ) if is_business_mode else None}

                            <div className="rs-default-section-header">
                                <span className="rs-default-section-title">{"Decision Readiness Score" if is_business_mode else "Reasoning Score"}</span>
                            </div>

                            <div className="rs-score-block">
                                <div className="rs-score-big"
                                    style={{"color": scoreColor}}>{overall_display}</div>
                                <div className="rs-score-sub">
                                    {"out of 100" if not is_business_mode else readiness_label}
                                </div>
                                <div className="rs-score-bar">
                                    <div className="rs-score-bar-fill"
                                        style={{"width": f"{overall}%", "background": scoreColor}}></div>
                                </div>
                                {(
                                    <div className="rs-score-delta-big"
                                        style={{"color": delta_color}}>{delta_text}</div>
                                ) if delta_text else None}
                            </div>

                            {(
                                <div className="rs-business-breakdown-grid">
                                    <div className="rs-business-breakdown-card">
                                        <div className="rs-business-breakdown-top">
                                            <div>
                                                <div className="rs-business-breakdown-label">Decision framing</div>
                                                <div className="rs-business-breakdown-weight">15% weight</div>
                                            </div>
                                            <div className="rs-business-breakdown-score" style={{"color": business_decision_color}}>
                                                {business_decision_val}
                                            </div>
                                        </div>
                                        <div className="rs-business-breakdown-status" style={{"color": business_decision_color}}>
                                            {business_decision_signal}
                                        </div>
                                        <div className="rs-business-breakdown-meter">
                                            <div className="rs-business-breakdown-fill"
                                                style={{"width": f"{business_decision_val}%", "background": business_decision_color}}>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="rs-business-breakdown-card">
                                        <div className="rs-business-breakdown-top">
                                            <div>
                                                <div className="rs-business-breakdown-label">Option set quality</div>
                                                <div className="rs-business-breakdown-weight">15% weight</div>
                                            </div>
                                            <div className="rs-business-breakdown-score" style={{"color": business_option_color}}>
                                                {business_option_val}
                                            </div>
                                        </div>
                                        <div className="rs-business-breakdown-status" style={{"color": business_option_color}}>
                                            {business_option_signal}
                                        </div>
                                        <div className="rs-business-breakdown-meter">
                                            <div className="rs-business-breakdown-fill"
                                                style={{"width": f"{business_option_val}%", "background": business_option_color}}>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="rs-business-breakdown-card">
                                        <div className="rs-business-breakdown-top">
                                            <div>
                                                <div className="rs-business-breakdown-label">Evidence strength</div>
                                                <div className="rs-business-breakdown-weight">20% weight</div>
                                            </div>
                                            <div className="rs-business-breakdown-score" style={{"color": business_evidence_color}}>
                                                {business_evidence_val}
                                            </div>
                                        </div>
                                        <div className="rs-business-breakdown-status" style={{"color": business_evidence_color}}>
                                            {business_evidence_signal}
                                        </div>
                                        <div className="rs-business-breakdown-meter">
                                            <div className="rs-business-breakdown-fill"
                                                style={{"width": f"{business_evidence_val}%", "background": business_evidence_color}}>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="rs-business-breakdown-card">
                                        <div className="rs-business-breakdown-top">
                                            <div>
                                                <div className="rs-business-breakdown-label">Risk handling</div>
                                                <div className="rs-business-breakdown-weight">15% weight</div>
                                            </div>
                                            <div className="rs-business-breakdown-score" style={{"color": business_risk_color}}>
                                                {business_risk_val}
                                            </div>
                                        </div>
                                        <div className="rs-business-breakdown-status" style={{"color": business_risk_color}}>
                                            {business_risk_signal}
                                        </div>
                                        <div className="rs-business-breakdown-meter">
                                            <div className="rs-business-breakdown-fill"
                                                style={{"width": f"{business_risk_val}%", "background": business_risk_color}}>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="rs-business-breakdown-card">
                                        <div className="rs-business-breakdown-top">
                                            <div>
                                                <div className="rs-business-breakdown-label">Assumptions & questions</div>
                                                <div className="rs-business-breakdown-weight">10% weight</div>
                                            </div>
                                            <div className="rs-business-breakdown-score" style={{"color": business_question_color}}>
                                                {business_question_val}
                                            </div>
                                        </div>
                                        <div className="rs-business-breakdown-status" style={{"color": business_question_color}}>
                                            {business_question_signal}
                                        </div>
                                        <div className="rs-business-breakdown-meter">
                                            <div className="rs-business-breakdown-fill"
                                                style={{"width": f"{business_question_val}%", "background": business_question_color}}>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="rs-business-breakdown-card">
                                        <div className="rs-business-breakdown-top">
                                            <div>
                                                <div className="rs-business-breakdown-label">Actionability & ownership</div>
                                                <div className="rs-business-breakdown-weight">15% weight</div>
                                            </div>
                                            <div className="rs-business-breakdown-score" style={{"color": business_action_color}}>
                                                {business_action_val}
                                            </div>
                                        </div>
                                        <div className="rs-business-breakdown-status" style={{"color": business_action_color}}>
                                            {business_action_signal}
                                        </div>
                                        <div className="rs-business-breakdown-meter">
                                            <div className="rs-business-breakdown-fill"
                                                style={{"width": f"{business_action_val}%", "background": business_action_color}}>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="rs-business-breakdown-card">
                                        <div className="rs-business-breakdown-top">
                                            <div>
                                                <div className="rs-business-breakdown-label">Traceability & hygiene</div>
                                                <div className="rs-business-breakdown-weight">10% weight</div>
                                            </div>
                                            <div className="rs-business-breakdown-score" style={{"color": business_traceability_color}}>
                                                {business_traceability_val}
                                            </div>
                                        </div>
                                        <div className="rs-business-breakdown-status" style={{"color": business_traceability_color}}>
                                            {business_traceability_signal}
                                        </div>
                                        <div className="rs-business-breakdown-meter">
                                            <div className="rs-business-breakdown-fill"
                                                style={{"width": f"{business_traceability_val}%", "background": business_traceability_color}}>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            ) if is_business_mode else (
                                <div>
                                    <div className="rs-breakdown-item">
                                        <div className="rs-breakdown-row">
                                            <span className="rs-breakdown-label">Root support coverage (25%)</span>
                                            <span className="rs-breakdown-value">{support_val}%</span>
                                        </div>
                                        <div className="rs-breakdown-bar">
                                            <div className="rs-breakdown-bar-fill"
                                                style={{"width": f"{support_val}%", "background": support_bar_color}}></div>
                                        </div>
                                    </div>
                                    <div className="rs-breakdown-item">
                                        <div className="rs-breakdown-row">
                                            <span className="rs-breakdown-label">Evidence quality (20%)</span>
                                            <span className="rs-breakdown-value">{premise_val}%</span>
                                        </div>
                                        <div className="rs-breakdown-bar">
                                            <div className="rs-breakdown-bar-fill"
                                                style={{"width": f"{premise_val}%", "background": premise_bar_color}}></div>
                                        </div>
                                    </div>
                                    <div className="rs-breakdown-item">
                                        <div className="rs-breakdown-row">
                                            <span className="rs-breakdown-label">Dialectical handling (20%)</span>
                                            <span className="rs-breakdown-value">{counter_val}%</span>
                                        </div>
                                        <div className="rs-breakdown-bar">
                                            <div className="rs-breakdown-bar-fill"
                                                style={{"width": f"{counter_val}%", "background": counter_bar_color}}></div>
                                        </div>
                                    </div>
                                    <div className="rs-breakdown-item">
                                        <div className="rs-breakdown-row">
                                            <span className="rs-breakdown-label">Structural coherence (15%)</span>
                                            <span className="rs-breakdown-value">{coherence_val}%</span>
                                        </div>
                                        <div className="rs-breakdown-bar">
                                            <div className="rs-breakdown-bar-fill"
                                                style={{"width": f"{coherence_val}%", "background": coherence_bar_color}}></div>
                                        </div>
                                    </div>
                                    <div className="rs-breakdown-item">
                                        <div className="rs-breakdown-row">
                                            <span className="rs-breakdown-label">Assumption explicitness (10%)</span>
                                            <span className="rs-breakdown-value">{assumption_val}%</span>
                                        </div>
                                        <div className="rs-breakdown-bar">
                                            <div className="rs-breakdown-bar-fill"
                                                style={{"width": f"{assumption_val}%", "background": assumption_bar_color}}></div>
                                        </div>
                                    </div>
                                    <div className="rs-breakdown-item rs-breakdown-item-last">
                                        <div className="rs-breakdown-row">
                                            <span className="rs-breakdown-label">Thesis clarity (10%)</span>
                                            <span className="rs-breakdown-value">{thesis_val}%</span>
                                        </div>
                                        <div className="rs-breakdown-bar">
                                            <div className="rs-breakdown-bar-fill"
                                                style={{"width": f"{thesis_val}%", "background": thesis_bar_color}}></div>
                                        </div>
                                    </div>
                                </div>
                            )}

                            <div className="rs-default-section-header">
                                <span className="rs-default-section-title">{"Top Issues" if not is_business_mode else "Top Blockers"}</span>
                            </div>
                            {(
                                <div>
                                    <p className="rs-panel-hint">
                                        {"Click on a node to fix it" if not is_business_mode else "Click a blocker to jump to the part of the board that still needs follow-up."}
                                    </p>
                                    <div>{topIssueElements}</div>
                                </div>
                            ) if len(currentIssues) > 0 else (
                                <div className="rs-no-issues-card">
                                    {"No major issues found!" if not is_business_mode else "No major blockers surfaced right now."}
                                </div>
                            )}

                            <div className="rs-next-actions-section">
                                <div className="rs-default-section-header">
                                    <span className="rs-default-section-title">{"Next 3 Actions" if not is_business_mode else "Top Next Actions"}</span>
                                </div>
                                {(
                                <div>{nextActionElements}</div>
                            ) if len(nextActionElements) > 0 else (
                                <div className="rs-no-issues-card">
                                    {"No urgent actions found. Your argument is ready to export!"
                                        if not is_business_mode else
                                        "No urgent follow-up is captured yet. Add one if the team still has open risks or questions."}
                                </div>
                            )}
                            </div>

                            {(
                                <div className="rs-counterargs-section">
                                    <div className="rs-default-section-header">
                                        <span className="rs-default-section-title">
                                            {"Consider These Counterarguments" if not is_business_mode else "Suggested Risks / Objections"}
                                        </span>
                                    </div>
                                    <p className="rs-panel-hint">
                                        {"Strengthen your argument by addressing opposing views"
                                            if not is_business_mode else
                                            "Pressure-test the decision by adding unresolved objections to the board"}
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
