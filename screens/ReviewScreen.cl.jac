"""Juncture - Review Screen for visualizing and analyzing argument maps."""

import from "lucide-react" { ArrowLeft, FileText, AlertTriangle, TrendingUp, ChevronRight }

import from ..components.ArgumentGraphView { ArgumentGraphView }
import from ..components.Badge { Badge }
import from ..components.Button { Button }
import from ..components.Card { Card }
import from ..components.Progress { Progress }

def:pub ReviewScreen(props: any) -> JsxElement {
    navigate = props.navigate;

    has currentGraph: dict = None,
        currentScore: dict = None,
        currentIssues: list = [],
        selectedNodeId: str = None;

    can async with entry {
        currentGraph = {
            "nodes": [
                {"id": "node_thesis", "type": "THESIS", "content": "Remote work increases overall productivity", "position": {"x": 250, "y": 50}},
                {"id": "node_claim_1", "type": "CLAIM", "content": "Eliminates commute time waste", "position": {"x": 100, "y": 200}},
                {"id": "node_claim_2", "type": "CLAIM", "content": "Reduces office distractions", "position": {"x": 400, "y": 200}}
            ],
            "edges": [
                {"id": "edge_1", "source": "node_claim_1", "target": "node_thesis", "type": "SUPPORTS"}
            ]
        };

        currentScore = {
            "overall": 65,
            "support": 60,
            "premise": 70,
            "consistency": 65,
            "unsupportedClaims": 1,
            "unresolvedContradictions": 0
        };

        currentIssues = [
            {
                "id": "issue_1",
                "nodeId": "node_claim_2",
                "severity": "high",
                "description": "This claim lacks supporting evidence",
                "suggestedAction": "Add evidence or data to support this claim"
            }
        ];
    }

    def getScoreColor(score: int) -> str {
        if score >= 75 { return "text-green-600"; }
        if score >= 50 { return "text-yellow-600"; }
        return "text-red-600";
    }

    def handleNodeClick(node_data: any) -> None {
        navigate("revise", {"nodeId": node_data["id"]});
    }

    def handleIssueClick(nodeId: str) -> None {
        navigate("revise", {"nodeId": nodeId});
    }

    def navigateBack() -> None {
        navigate("generate");
    }

    def navigateToExport() -> None {
        navigate("export");
    }

    topIssues = currentIssues[:3] if currentIssues else [];

    if not currentGraph or not currentScore {
        return <div className="flex items-center justify-center h-screen"><p>Loading...</p></div>;
    }

    return (
        <div className="h-screen flex flex-col bg-gray-50">
            <header className="bg-white border-b px-4 py-3 flex items-center justify-between">
                <div className="flex items-center gap-4">
                    <Button label={(<><ArrowLeft className="h-4 w-4 mr-2" />Back</>)} variant="ghost" size="sm" onClick={navigateBack} />
                    <h1 className="text-xl font-bold">Argument Map</h1>
                </div>
                <Button label={(<><FileText className="h-4 w-4 mr-2" />Export</>)} variant="outline" size="sm" onClick={navigateToExport} />
            </header>

            <div className="flex-1 flex overflow-hidden">
                <div className="flex-1 relative">
                    <ArgumentGraphView
                        nodes={currentGraph["nodes"]}
                        edges={currentGraph["edges"]}
                        onNodeClick={handleNodeClick}
                    />
                </div>

                <div className="w-96 bg-white border-l flex flex-col overflow-hidden">
                    <div className="p-4 border-b flex-shrink-0">
                        <h2 className="font-semibold flex items-center gap-2">
                            <TrendingUp className="h-5 w-5 text-indigo-600" />
                            Reasoning Score
                        </h2>
                    </div>

                    <div className="flex-1 overflow-y-auto">
                        <div className="p-4 space-y-6">
                            <Card>
                                <div className="text-center space-y-2 pt-6">
                                    <div className={"text-5xl font-bold " + getScoreColor(currentScore["overall"])}>
                                        {currentScore["overall"]}
                                    </div>
                                    <p className="text-sm text-gray-600">out of 100</p>
                                    <Progress value={currentScore["overall"]} className="h-2" />
                                </div>
                            </Card>

                            <Card title={<span className="text-sm">Score Breakdown</span>}>
                                <div className="space-y-3">
                                    <div className="flex items-center justify-between">
                                        <span className="text-sm">Support Coverage (40%)</span>
                                        <Badge variant="outline">{currentScore["support"]}%</Badge>
                                    </div>
                                    <Progress value={currentScore["support"]} className="h-1.5" />

                                    <div className="flex items-center justify-between">
                                        <span className="text-sm">Premise Coverage (40%)</span>
                                        <Badge variant="outline">{currentScore["premise"]}%</Badge>
                                    </div>
                                    <Progress value={currentScore["premise"]} className="h-1.5" />

                                    <div className="flex items-center justify-between">
                                        <span className="text-sm">Consistency (20%)</span>
                                        <Badge variant="outline">{currentScore["consistency"]}%</Badge>
                                    </div>
                                    <Progress value={currentScore["consistency"]} className="h-1.5" />
                                </div>
                            </Card>

                            <Card
                                title={<span className="flex items-center gap-2 text-sm"><AlertTriangle className="h-4 w-4 text-amber-500" />Top 3 Issues</span>}
                                description="Click on an issue to fix it"
                            >
                                <div className="space-y-2">
                                    {(
                                        <p className="text-sm text-gray-500 text-center py-4">No major issues found! 🎉</p>
                                    ) if len(topIssues) == 0 else (
                                        topIssues.map(lambda issue, index -> any {
                                            return <div
                                                key={issue["id"]}
                                                onClick={lambda -> None { handleIssueClick(issue["nodeId"]); }}
                                                className="p-3 border rounded-lg hover:bg-gray-50 cursor-pointer transition-colors"
                                            >
                                                <div className="flex items-start justify-between gap-2">
                                                    <div className="flex-1">
                                                        <div className="flex items-center gap-2 mb-1">
                                                            <Badge
                                                                variant={
                                                                    "destructive" if issue["severity"] == "high"
                                                                    else "default" if issue["severity"] == "medium"
                                                                    else "secondary"
                                                                }
                                                                className="text-xs"
                                                            >
                                                                {issue["severity"]}
                                                            </Badge>
                                                            <span className="text-xs text-gray-500">Issue #{index + 1}</span>
                                                        </div>
                                                        <p className="text-sm font-medium">{issue["description"]}</p>
                                                    </div>
                                                    <ChevronRight className="h-4 w-4 text-gray-400 flex-shrink-0" />
                                                </div>
                                            </div>;
                                        })
                                    )}
                                </div>
                            </Card>

                            <Card
                                title={<span className="text-sm">Start Here</span>}
                                description="Recommended next steps in order"
                            >
                                <div className="space-y-3">
                                    {(
                                        <p className="text-sm text-gray-500 text-center py-2">Great work! Ready to export.</p>
                                    ) if len(topIssues) == 0 else (
                                        topIssues.map(lambda issue, index -> any {
                                            return <div key={issue["id"]} className="flex items-start gap-3">
                                                <div className="flex-shrink-0 w-6 h-6 rounded-full bg-indigo-100 text-indigo-600 flex items-center justify-center text-xs font-bold">
                                                    {index + 1}
                                                </div>
                                                <div className="flex-1">
                                                    <p className="text-sm">{issue["suggestedAction"]}</p>
                                                    <Button label="Fix now →" variant="link" size="sm" className="h-auto p-0 text-xs" onClick={lambda -> None { handleIssueClick(issue["nodeId"]); }} />
                                                </div>
                                            </div>;
                                        })
                                    )}
                                </div>
                            </Card>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}