"""Export Screen"""

import from "lucide-react" { Download, FileText, AlertTriangle, CheckCircle2, Copy }

import from ..components.Alert { Alert }
import from ..components.Badge { Badge }
import from ..components.Button { Button }
import from ..components.Card { Card }
import from ..components.Header { Header }

def:pub ExportScreen(props: any) -> JsxElement {
    navigate = props.navigate;

    has currentGraph: dict = None,
        currentScore: dict = None,
        currentIssues: list = [],
        currentNotes: str = "",
        userId: str = "",
        exportFormat: str = "text";

    async def loadContext() -> None {
        ctx = await root spawn GetContext();
        if ctx and "currentUser" in ctx and ctx["currentUser"] {
            userId = ctx["currentUser"]["id"];
        }
        currentGraph = {
            "nodes": [
                {"id": "node_thesis", "type": "THESIS", "content": "Remote work increases productivity"},
                {"id": "node_claim_1", "type": "CLAIM", "content": "Eliminates commute time"},
                {"id": "node_evidence_1", "type": "EVIDENCE", "content": "Average commute is 54 minutes"}
            ],
            "edges": [
                {"source": "node_claim_1", "target": "node_thesis", "type": "SUPPORTS"},
                {"source": "node_evidence_1", "target": "node_claim_1", "type": "SUPPORTS"}
            ]
        };

        currentScore = {
            "overall": 75,
            "support": 70,
            "premise": 75,
            "consistency": 80,
            "unsupportedClaims": 0,
            "unresolvedContradictions": 0
        };
    }

    can with entry {
        loadContext();
    }

    def generateOutlineText(includeFlags: bool) -> str {
        if not currentGraph {
            return "";
        }
        nodes = currentGraph["nodes"];
        edges = currentGraph["edges"];
        thesis = None;
        claims = [];
        evidence = [];

        for node in nodes {
            if node["type"] == "THESIS" {
                thesis = node;
            } elif node["type"] == "CLAIM" {
                claims.append(node);
            } elif node["type"] == "EVIDENCE" {
                evidence.append(node);
            }
        }

        outline = "ARGUMENT OUTLINE\n";
        outline += "==================================================\n\n";
        if thesis {
            outline += "THESIS:\n";
            outline += thesis["content"] + "\n\n";
        }
        outline += "MAIN CLAIMS:\n";

        i = 0;
        for claim in claims {
            claim_evidence = [];

            for edge in edges {
                if edge["target"] == claim["id"] and edge["type"] == "SUPPORTS" {
                    for ev in evidence {
                        if ev["id"] == edge["source"] {
                            claim_evidence.append(ev);
                            break;
                        }
                    }
                }
            }

            outline += f"\n{i + 1}. {claim['content']}\n";

            if len(claim_evidence) > 0 {
                outline += "   Supporting Evidence:\n";
                for ev in claim_evidence {
                    outline += f"   • {ev['content']}\n";
                }
            }
            i += 1;
        }

        outline += "\n==================================================\n";
        outline += f"Reasoning Score: {currentScore['overall']}/100\n";

        return outline;
    }

    def handleExportText() -> None {
        # TODO: make this work
        show_flags = currentScore["overall"] < 75;
        outline = generateOutlineText(show_flags);
        print("Copy to clipboard:");
        print(outline);
    }

    def handleExportPDF() -> None {
        # TODO: make this work
        show_flags = currentScore["overall"] < 75;
        outline = generateOutlineText(show_flags);
        print("Export PDF:");
        print(outline);
    }

    async def handleSaveSession() -> None {
        walker_result = await root spawn SaveSessionToHistory(
            userId=userId,
            graphId="graph_1",
            notes=currentNotes,
            score=currentScore
        );
        print(walker_result);
    }

    if not currentGraph or not currentScore {
        return <div className="export-loading"><p>Loading...</p></div>;
    }

    show_warning = currentScore["overall"] < 75;

    return (
        <div className="export-page">
            <Header navigate={navigate} screen="export" title="Export Outline" backTo="revise" />

            <div className="export-content">
                <Card
                    title={
                        <div className="export-score-header">
                            <span>Final Score</span>
                            <Badge
                                variant={"default" if currentScore["overall"] >= 75 else "destructive"}
                                className="export-score-badge"
                            >
                                {currentScore["overall"]}/100
                            </Badge>
                        </div>
                    }
                    description={"Your argument is well-structured and ready to export!"
                        if currentScore["overall"] >= 75 else
                        "Your argument could be improved before exporting."}
                />

                {(
                    <Alert className="export-alert-success">
                        <CheckCircle2 className="export-alert-success-icon" />
                        <p className="export-alert-success-text">Great work! Your argument is ready to export.</p>
                    </Alert>
                ) if not show_warning else (
                    <Alert className="export-alert-warning">
                        <AlertTriangle className="export-alert-warning-icon" />
                        <p>Some issues were detected before export.</p>
                    </Alert>
                )}

                <Card title="Outline Preview">
                    <div className="export-preview">
                        {generateOutlineText(show_warning)}
                    </div>
                </Card>

                <Card title="Export Options">
                    <div className="export-options-body">
                        <div className="export-options-grid">
                            <Button label={(<><Copy className="export-btn-icon" />Copy Outline</>)} variant="outline" onClick={handleExportText} />
                            <Button label={(<><Download className="export-btn-icon" />Download PDF</>)} variant="outline" onClick={handleExportPDF} />
                        </div>
                        <Button label={(<><FileText className="export-btn-icon-sm" />Save to History</>)} onClick={handleSaveSession} className="export-save-btn" />
                    </div>
                </Card>
            </div>
        </div>
    );
}
