"""Juncture - Revise Screen for editing and improving argument nodes."""

sv import from ...main { AddEvidenceToNode, AddAssumptionToNode, UpdateNodeContent, DeleteNode, GetGraphWithScoring }
import from "lucide-react" { Plus, Check, X, Info }

import from ..components.Alert { Alert }
import from ..components.Badge { Badge }
import from ..components.Button { Button }
import from ..components.Card { Card }
import from ..components.Header { Header }

def:pub ReviseScreen(props: any) -> JsxElement {
    navigate = props.navigate;
    screen_data = props.screenData if props.screenData else {};

    has nodeId: str = "",
        graphId: str = "",
        graphData: dict = None,
        scoreData: dict = None,
        issuesData: list = [],
        currentNode: dict = None,
        nodeIssues: list = [],
        actionType: str = None,
        inputValue: str = "",
        showConfirmDelete: bool = False;

    can with entry {
        nodeId = screen_data["nodeId"] if "nodeId" in screen_data else "";
        graphData = screen_data["graphData"] if "graphData" in screen_data else None;
        scoreData = screen_data["scoreData"] if "scoreData" in screen_data else None;
        issuesData = screen_data["issuesData"] if "issuesData" in screen_data else [];

        if graphData {
            graphId = graphData["id"] if "id" in graphData else "";

            nodes_list = graphData["nodes"] if "nodes" in graphData else [];
            for n in nodes_list {
                if n["id"] == nodeId {
                    currentNode = n;
                    break;
                }
            }
        }

        if not currentNode {
            currentNode = {
                "id": nodeId,
                "type": "CLAIM",
                "content": "Node not found"
            };
        }

        nodeIssues = [iss for iss in issuesData if (iss["nodeId"] if "nodeId" in iss else "") == nodeId];
    }

    async def handleSave() -> None {
        if not inputValue.trim() {
            return;
        }

        if actionType == "evidence" {
            await root spawn AddEvidenceToNode(
                graphId=graphId,
                nodeId=nodeId,
                evidenceContent=inputValue
            );
        } elif actionType == "assumption" {
            await root spawn AddAssumptionToNode(
                graphId=graphId,
                nodeId=nodeId,
                assumptionContent=inputValue
            );
        } elif actionType == "clarify" {
            await root spawn UpdateNodeContent(
                graphId=graphId,
                nodeId=nodeId,
                newContent=inputValue
            );
        }

        actionType = None;
        inputValue = "";

        await refreshAndNavigateBack();
    }

    async def handleDelete() -> None {
        await root spawn DeleteNode(
            graphId=graphId,
            nodeId=nodeId
        );
        await refreshAndNavigateBack();
    }

    async def refreshAndNavigateBack() -> None {
        if graphId {
            try {
                result = await root spawn GetGraphWithScoring(graphId=graphId);
                data = result.reports[0] if result.reports else {};
                if "error" not in data {
                    navigate("review", {
                        "graphData": data["graph"] if "graph" in data else graphData,
                        "scoreData": data["score"] if "score" in data else scoreData,
                        "issuesData": data["issues"] if "issues" in data else issuesData
                    });
                    return;
                }
            } except Exception as e {
                print(f"Error refreshing graph: {e}");
            }
        }
        navigate("review", {
            "graphData": graphData,
            "scoreData": scoreData,
            "issuesData": issuesData
        });
    }

    def selectEvidence() -> None {
        actionType = "evidence";
        inputValue = "";
    }

    def selectAssumption() -> None {
        actionType = "assumption";
        inputValue = "";
    }

    def selectClarify() -> None {
        actionType = "clarify";
        inputValue = currentNode["content"];
    }

    def selectDelete() -> None {
        showConfirmDelete = True;
    }

    def handleBackToReview() -> None {
        navigate("review", {
            "graphData": graphData,
            "scoreData": scoreData,
            "issuesData": issuesData
        });
    }

    def cancelAction() -> None {
        actionType = None;
        inputValue = "";
    }

    def cancelDelete() -> None {
        showConfirmDelete = False;
    }

    def handleInputChange(e: any) -> None {
        inputValue = e.target.value;
    }

    nodeColorClasses = {
        "THESIS":           "revise-node-card-thesis",
        "CLAIM":            "revise-node-card-claim",
        "EVIDENCE":         "revise-node-card-evidence",
        "ASSUMPTION":       "revise-node-card-assumption",
        "COUNTERARGUMENT":  "revise-node-card-counterargument"
    };

    nodeIcons = {
        "THESIS": "🎯",
        "CLAIM": "💭",
        "EVIDENCE": "📊",
        "ASSUMPTION": "🔗",
        "COUNTERARGUMENT": "⚠️"
    };

    if not currentNode {
        return <div className="revise-loading">
            <p>Loading...</p>
        </div>;
    }

    return (
        <div className="revise-page">
            <Header navigate={navigate} screen="revise" title="Revise Node" backTo="review"
                onBack={lambda -> None {
                    navigate("review", {
                        "graphData": graphData,
                        "scoreData": scoreData,
                        "issuesData": issuesData
                    });
                }}
            />

            <div className="revise-content">
                <Card
                    title={
                        <div className="revise-node-header">
                            <span className="revise-node-type">
                                <span>{nodeIcons[currentNode["type"]] if currentNode["type"] in nodeIcons else "💭"}</span>
                                {currentNode["type"]}
                            </span>
                            <Badge variant="outline">{currentNode["id"]}</Badge>
                        </div>
                    }
                    className={nodeColorClasses[currentNode["type"]] if currentNode["type"] in nodeColorClasses else "revise-node-card-claim"}
                >
                    <p className="revise-node-content">{currentNode["content"]}</p>
                </Card>

                {(
                    <Card title="Issues Detected">
                        <div className="revise-issues-list">
                            {nodeIssues.map(lambda issue -> any {
                                return <Alert key={issue["id"]}>
                                    <Info className="revise-issue-icon" />
                                    <p className="revise-issue-description">{issue["description"]}</p>
                                    <p className="revise-issue-suggestion">💡 {issue["suggestedAction"]}</p>
                                </Alert>;
                            })}
                        </div>
                    </Card>
                ) if len(nodeIssues) > 0 else None}

                <Card
                    title="Choose an Action"
                    description="Select what you'd like to do with this node"
                >
                    <div className="revise-actions-body">
                        <div className="revise-actions-grid">
                            <Button
                                label={(<><span className="revise-action-label">📊 Add Evidence</span><span className="revise-action-sub">Example, statatistic, or source</span></>)}
                                variant={"default" if actionType == "evidence" else "outline"}
                                onClick={selectEvidence}
                                className="revise-action-btn"
                            />

                            <Button
                                label={(<><span className="revise-action-label">🔗 Add Assumption</span><span className="revise-action-sub">Missing logical link</span></>)}
                                variant={"default" if actionType == "assumption" else "outline"}
                                onClick={selectAssumption}
                                className="revise-action-btn"
                            />

                            <Button
                                label={(<><span className="revise-action-label">✏️ Clarify Wording</span><span className="revise-action-sub">Rewrite for clarity</span></>)}
                                variant={"default" if actionType == "clarify" else "outline"}
                                onClick={selectClarify}
                                className="revise-action-btn"
                            />

                            <Button
                                label={(<><span className="revise-action-label revise-action-label-danger">🗑️ Delete Node</span><span className="revise-action-sub">Remove from graph</span></>)}
                                variant="outline"
                                onClick={selectDelete}
                                className="revise-action-btn revise-action-btn-danger"
                            />
                        </div>

                        {(
                            <div className="revise-input-section">
                                <div className="revise-input-group">
                                    <label className="revise-input-label">
                                        {"Enter your evidence" if actionType == "evidence" else
                                        "State the assumption" if actionType == "assumption" else
                                        "Clarify the wording"}
                                    </label>
                                    <textarea
                                        value={inputValue}
                                        onChange={handleInputChange}
                                        placeholder={
                                            "e.g., A 2024 Stanford study found that 87% of remote workers reported higher productivity..."
                                            if actionType == "evidence" else
                                            "e.g., Assumes that reduced commute time is used productively..."
                                            if actionType == "assumption" else
                                            "Enter clearer wording..."
                                        }
                                        className="revise-textarea"
                                    />
                                </div>
                                <div className="revise-input-actions">
                                    <Button label={(<><Check className="revise-btn-icon" />Save Changes</>)} onClick={handleSave} className="revise-save-btn" />
                                    <Button label="Cancel" variant="outline" onClick={cancelAction} />
                                </div>
                            </div>
                        ) if actionType and actionType != "delete" else None}

                        {(
                            <Alert className="revise-delete-alert">
                                <p className="revise-delete-message">
                                    Are you sure you want to delete this node? This action cannot be undone.
                                </p>
                                <div className="revise-delete-actions">
                                    <Button label={(<><X className="revise-btn-icon" />Yes, Delete</>)} variant="destructive" onClick={handleDelete} />
                                    <Button label="Cancel" variant="outline" onClick={cancelDelete} />
                                </div>
                            </Alert>
                        ) if showConfirmDelete else None}
                    </div>
                </Card>

                <Card title="💡 Tips for Strong Arguments" className="revise-tips-card">
                    <div className="revise-tips-body">
                        <p><strong>Evidence:</strong> Use specific examples, statistics, or citations from credible sources.</p>
                        <p><strong>Assumptions:</strong> Make implicit logic explicit. State the "because" that connects ideas.</p>
                        <p><strong>Clarity:</strong> Be precise. Avoid vague terms like "some," "many," or "better."</p>
                    </div>
                </Card>
            </div>
        </div>
    );
}
