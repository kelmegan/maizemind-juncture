"""Juncture - Revise Screen for editing and improving argument nodes."""

import from "lucide-react" { ArrowLeft, Plus, Check, X, Info }

import from ..components.Alert { Alert }
import from ..components.Badge { Badge }
import from ..components.Button { Button }
import from ..components.Card { Card }

def:pub ReviseScreen(props: any) -> JsxElement {
    navigate = props.navigate;
    screen_data = props.screenData if props.screenData else {};
    initial_node_id = screen_data["nodeId"] if "nodeId" in screen_data else "node_claim_1";

    has nodeId: str = "",
        graphId: str = "",
        currentNode: dict = None,
        nodeIssues: list = [],
        actionType: str = None,
        inputValue: str = "",
        showConfirmDelete: bool = False;

    can with entry {
        nodeId = initial_node_id;
        graphId = "graph_123";

        currentNode = {
            "id": nodeId,
            "type": "CLAIM",
            "content": "Remote work increases productivity"
        };

        nodeIssues = [
            {
                "id": "issue_1",
                "nodeId": nodeId,
                "description": "This claim lacks supporting evidence",
                "suggestedAction": "Add specific examples or data to support this claim"
            }
        ];
    }

    async def handleSave() -> None {
        if not inputValue.strip() {
            print("Please enter some content");
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
    }

    async def handleDelete() -> None {
        await root spawn DeleteNode(
            graphId=graphId,
            nodeId=nodeId
        );
        navigate("review");
    }

    def navigateBack() -> None {
        navigate("review");
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

    nodeColors = {
        "THESIS": "border-purple-400 bg-purple-50",
        "CLAIM": "border-blue-400 bg-blue-50",
        "EVIDENCE": "border-green-400 bg-green-50",
        "ASSUMPTION": "border-yellow-400 bg-yellow-50",
        "COUNTERARGUMENT": "border-red-400 bg-red-50"
    };

    nodeIcons = {
        "THESIS": "🎯",
        "CLAIM": "💭",
        "EVIDENCE": "📊",
        "ASSUMPTION": "🔗",
        "COUNTERARGUMENT": "⚠️"
    };

    if not currentNode {
        return <div className="flex items-center justify-center h-screen">
            <p>Loading...</p>
        </div>;
    }

    return (
        <div className="min-h-screen bg-gray-50">
            <header className="bg-white border-b px-4 py-3">
                <div className="max-w-4xl mx-auto flex items-center gap-4">
                    <Button label={(<><ArrowLeft className="h-4 w-4 mr-2" />Back to Map</>)} variant="ghost" size="sm" onClick={navigateBack} />
                    <h1 className="text-xl font-bold">Revise Node</h1>
                </div>
            </header>

            <div className="max-w-4xl mx-auto p-6 space-y-6">
                <Card
                    title={
                        <div className="flex items-center justify-between">
                            <span className="flex items-center gap-2">
                                <span>{nodeIcons[currentNode["type"]]}</span>
                                {currentNode["type"]}
                            </span>
                            <Badge variant="outline">{currentNode["id"]}</Badge>
                        </div>
                    }
                    className={"border-2 " + nodeColors[currentNode["type"]]}
                >
                    <p className="text-lg">{currentNode["content"]}</p>
                </Card>

                {(
                   <Card title="Issues Detected">
                        <div className="space-y-2">
                            {nodeIssues.map(lambda issue -> any {
                                return <Alert key={issue["id"]}>
                                    <Info className="h-4 w-4" />
                                    <p className="font-medium">{issue["description"]}</p>
                                    <p className="text-sm text-gray-600 mt-1">💡 {issue["suggestedAction"]}</p>
                                </Alert>;
                            })}
                        </div>
                    </Card>
                ) if len(nodeIssues) > 0 else None}

                <Card
                    title="Choose an Action"
                    description="Select what you'd like to do with this node"
                >
                    <div className="space-y-4">
                        <div className="grid grid-cols-2 gap-3">
                            <Button
                                label={(<><span className="font-semibold">📊 Add Evidence</span><span className="text-xs opacity-80">Example, stat, or source</span></>)}
                                variant={"default" if actionType == "evidence" else "outline"}
                                onClick={selectEvidence}
                                className="h-auto py-4 flex flex-col items-start"
                            />

                            <Button
                                label={(<><span className="font-semibold">🔗 Add Assumption</span><span className="text-xs opacity-80">Missing logical link</span></>)}
                                variant={"default" if actionType == "assumption" else "outline"}
                                onClick={selectAssumption}
                                className="h-auto py-4 flex flex-col items-start"
                            />

                            <Button
                                label={(<><span className="font-semibold">✏️ Clarify Wording</span><span className="text-xs opacity-80">Rewrite for clarity</span></>)}
                                variant={"default" if actionType == "clarify" else "outline"}
                                onClick={selectClarify}
                                className="h-auto py-4 flex flex-col items-start"
                            />

                            <Button
                                label={(<><span className="font-semibold">🗑️ Delete Node</span><span className="text-xs opacity-80">Remove from graph</span></>)}
                                variant="outline"
                                onClick={selectDelete}
                                className="h-auto py-4 flex flex-col items-start border-red-200 text-red-600 hover:bg-red-50"
                            />
                        </div>

                        {(
                            <div className="space-y-4 pt-4 border-t">
                                <div className="space-y-2">
                                    <label>
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
                                        className="min-h-[120px]"
                                    />
                                </div>
                                <div className="flex gap-2">
                                    <Button label={(<><Check className="h-4 w-4 mr-2" />Save Changes</>)} onClick={handleSave} className="flex-1" />
                                    <Button label="Cancel" variant="outline" onClick={cancelAction} />
                                </div>
                            </div>
                        ) if actionType and actionType != "delete" else None}

                        {(
                            <Alert className="border-red-200 bg-red-50">
                                <p className="font-medium text-red-900 mb-3">
                                    Are you sure you want to delete this node? This action cannot be undone.
                                </p>
                                <div className="flex gap-2">
                                    <Button label={(<><X className="h-4 w-4 mr-2" />Yes, Delete</>)} variant="destructive" size="sm" onClick={handleDelete} />
                                    <Button label="Cancel" variant="outline" size="sm" onClick={cancelDelete} />    
                                </div>
                            </Alert>
                        ) if showConfirmDelete else None}
                    </div>
                </Card>

                <Card title="💡 Tips for Strong Arguments" className="bg-indigo-50 border-indigo-200">
                    <div className="space-y-2 text-sm">
                        <p><strong>Evidence:</strong> Use specific examples, statistics, or citations from credible sources.</p>
                        <p><strong>Assumptions:</strong> Make implicit logic explicit. State the "because" that connects ideas.</p>
                        <p><strong>Clarity:</strong> Be precise. Avoid vague terms like "some," "many," or "better."</p>
                    </div>
                </Card>
            </div>
        </div>
    );
}