"""Juncture - Review Screen for visualizing and analyzing argument maps."""

import from "lucide-react" { AlertTriangle, TrendingUp, ChevronRight }

import from ..components.ArgumentGraphView { ArgumentGraphView }
import from ..components.Badge { Badge }
import from ..components.Button { Button }
import from ..components.Card { Card }
import from ..components.Header { Header }
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
                {"id": "node_thesis",       "type": "THESIS",          "content": "Remote work increases overall productivity",             "position": {"x": 280, "y": 40},  "issues": [], "isWeak": False},
                {"id": "node_claim_1",      "type": "CLAIM",           "content": "Eliminates commute time waste",                         "position": {"x": 60,  "y": 220}, "issues": [], "isWeak": False},
                {"id": "node_claim_2",      "type": "CLAIM",           "content": "Reduces office distractions",                           "position": {"x": 500, "y": 220}, "issues": [{"id": "i1"}], "isWeak": False},
                {"id": "node_evidence_1",   "type": "EVIDENCE",        "content": "Study: average commute is 54 minutes daily",            "position": {"x": 60,  "y": 420}, "issues": [], "isWeak": False},
                {"id": "node_assumption_1", "type": "ASSUMPTION",      "content": "Time saved from commuting is redirected to work tasks",  "position": {"x": 300, "y": 420}, "issues": [], "isWeak": False},
                {"id": "node_counter_1",    "type": "COUNTERARGUMENT", "content": "Remote workers report higher rates of isolation",        "position": {"x": 500, "y": 420}, "issues": [], "isWeak": False}
            ],
            "edges": [
                {"id": "edge_1", "source": "node_claim_1",      "target": "node_thesis",  "type": "SUPPORTS"},
                {"id": "edge_2", "source": "node_claim_2",      "target": "node_thesis",  "type": "SUPPORTS"},
                {"id": "edge_3", "source": "node_evidence_1",   "target": "node_claim_1", "type": "SUPPORTS"},
                {"id": "edge_4", "source": "node_assumption_1", "target": "node_claim_1", "type": "DEPENDS_ON"},
                {"id": "edge_5", "source": "node_counter_1",    "target": "node_thesis",  "type": "CONTRADICTS"}
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

    def getScoreClass(score: int) -> str {
        if score >= 75 { return "score-number-good"; }
        if score >= 50 { return "score-number-warning"; }
        return "score-number-bad";
    }

    def handleNodeClick(node_data: any) -> None {
        navigate("revise", {"nodeId": node_data["id"]});
    }

    def handleIssueClick(nodeId: str) -> None {
        navigate("revise", {"nodeId": nodeId});
    }

    topIssues = currentIssues[:3] if currentIssues else [];

    if not currentGraph or not currentScore {
        return <div className="review-loading"><p>Loading...</p></div>;
    }

    return (
        <div className="review-page">
            <Header navigate={navigate} screen="review" title="Argument Map" backTo="generate" />

            <div className="review-body">
                <div className="review-graph-area">
                    <ArgumentGraphView
                        nodes={currentGraph["nodes"]}
                        edges={currentGraph["edges"]}
                        onNodeClick={handleNodeClick}
                    />
                </div>

                <div className="review-sidebar">
                    <div className="review-sidebar-header">
                        <h2 className="review-sidebar-title">
                            <TrendingUp />
                            Reasoning Score
                        </h2>
                    </div>

                    <div className="review-sidebar-scroll">
                        <div className="review-sidebar-content">

                            <Card>
                                <div className="score-display">
                                    <div className={"score-number " + getScoreClass(currentScore["overall"])}>
                                        {currentScore["overall"]}
                                    </div>
                                    <p className="score-label">out of 100</p>
                                    <Progress value={currentScore["overall"]} />
                                </div>
                            </Card>

                            <Card title="Score Breakdown">
                                <div className="score-breakdown-group">
                                    <div>
                                        <div className="score-breakdown-row">
                                            <span className="score-breakdown-label">Support Coverage (40%)</span>
                                            <Badge variant="outline">{currentScore["support"]}%</Badge>
                                        </div>
                                        <Progress value={currentScore["support"]} />
                                    </div>
                                    <div>
                                        <div className="score-breakdown-row">
                                            <span className="score-breakdown-label">Premise Coverage (40%)</span>
                                            <Badge variant="outline">{currentScore["premise"]}%</Badge>
                                        </div>
                                        <Progress value={currentScore["premise"]} />
                                    </div>
                                    <div>
                                        <div className="score-breakdown-row">
                                            <span className="score-breakdown-label">Consistency (20%)</span>
                                            <Badge variant="outline">{currentScore["consistency"]}%</Badge>
                                        </div>
                                        <Progress value={currentScore["consistency"]} />
                                    </div>
                                </div>
                            </Card>

                            <Card
                                title={(<span className="card-title-icon"><AlertTriangle />Top 3 Issues</span>)}
                                description="Click on an issue to fix it"
                            >
                                <div>
                                    {(
                                        <p className="issue-empty">No major issues found! 🎉</p>
                                    ) if len(topIssues) == 0 else (
                                        topIssues.map(lambda issue, index -> any {
                                            return <div
                                                key={issue["id"]}
                                                onClick={lambda -> None { handleIssueClick(issue["nodeId"]); }}
                                                className="issue-item"
                                            >
                                                <div className="issue-item-inner">
                                                    <div className="issue-item-body">
                                                        <div className="issue-item-meta">
                                                            <Badge variant={"destructive" if issue["severity"] == "high" else "default" if issue["severity"] == "medium" else "secondary"}>
                                                                {issue["severity"]}
                                                            </Badge>
                                                            <span className="issue-item-number">Issue #{index + 1}</span>
                                                        </div>
                                                        <p className="issue-item-description">{issue["description"]}</p>
                                                    </div>
                                                    <ChevronRight className="issue-item-chevron" />
                                                </div>
                                            </div>;
                                        })
                                    )}
                                </div>
                            </Card>

                            <Card
                                title="Start Here"
                                description="Recommended next steps in order"
                            >
                                <div>
                                    {(
                                        <p className="issue-empty">Great work! Ready to export.</p>
                                    ) if len(topIssues) == 0 else (
                                        topIssues.map(lambda issue, index -> any {
                                            return <div key={issue["id"]} className="step-item">
                                                <div className="step-number">{index + 1}</div>
                                                <div className="step-body">
                                                    <p className="step-action">{issue["suggestedAction"]}</p>
                                                    <button className="step-fix-btn" onClick={lambda -> None { handleIssueClick(issue["nodeId"]); }}>
                                                        Fix now →
                                                    </button>
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
