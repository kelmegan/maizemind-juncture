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
        exportFormat: str = "text",
        copyStatus: str = "";  # "" | "success" | "failure";

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
        if not currentGraph { return ""; }

        nodes = currentGraph["nodes"];
        edges = currentGraph["edges"];

        # Find thesis
        thesis_node = None;
        claim_nodes = [];
        evidence_nodes = {};

        for n in nodes {
            if n["type"] == "THESIS" { thesis_node = n; }
            elif n["type"] == "CLAIM" { claim_nodes.append(n); }
            elif n["type"] == "EVIDENCE" { evidence_nodes[n["id"]] = n; }
        }

        outline = "ARGUMENT OUTLINE\n";
        outline += "==================================================\n\n";

        if thesis_node {
            outline += "THESIS:\n";
            outline += thesis_node["content"] + "\n\n";
        }

        if len(claim_nodes) > 0 {
            outline += "MAIN CLAIMS:\n";
            i = 1;
            for claim in claim_nodes {
                outline += str(i) + ". " + claim["content"] + "\n";

                # Find evidence supporting this claim
                supporting = [];
                for edge in edges {
                    if edge["target"] == claim["id"] and edge["type"] == "SUPPORTS" {
                        if edge["source"] in evidence_nodes {
                            supporting.append(evidence_nodes[edge["source"]]);
                        }
                    }
                }

                if len(supporting) > 0 {
                    outline += "   Supporting Evidence:\n";
                    for ev in supporting {
                        outline += "   • " + ev["content"] + "\n";
                    }
                }

                outline += "\n";  # extra spacing between claims
                i += 1;
            }
        }

        outline += "==================================================\n";
        outline += "Reasoning Score: " + str(currentScore["overall"]) + "/100\n";

        return outline;
    }

    def handleExportText() -> None {
        # TODO: make this work
        show_flags = currentScore["overall"] < 75;
        outline = generateOutlineText(show_flags);
        print("Copy to clipboard:");
        print(outline);
    }

    def handleCopyOutline() -> None {
        # TODO: make this work
        outline_text = generateOutlineText(show_warning);

        result: dict = navigator.clipboard.writeText(text=outline_text);
        if "ok" in result and result["ok"] {
            copyStatus = "success";
        } else {
            copyStatus = "failure";
            print("Copy failed:", result);
        }

        copyStatus = "";
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

    outline_lines: list = [];

    i = 0;
    for line in generateOutlineText(show_warning).split("\n") {
        outline_lines.append(<div key={str(i)}>{line}</div>);
        i += 1;
    }

    return (
        <div className="export-page">
            <Header navigate={navigate} screen="export" title="Export Outline" backTo="review" />

            {(
                <Alert className="export-alert-success">
                    <CheckCircle2 className="export-alert-success-icon" />
                    <p className="export-alert-success-text">Outline copied to clipboard!</p>
                </Alert>
            ) if copyStatus == "success" else (
                <Alert className="export-alert-warning">
                    <AlertTriangle className="export-alert-warning-icon" />
                    <p>Failed to copy outline. Please try again.</p>
                </Alert>
            ) if copyStatus == "failure" else None}
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
                        {outline_lines}
                    </div>
                </Card>

                <Card title="Export Options">
                    <div className="export-options-body">
                        <div className="export-options-grid">
                            <Button label={(<><Copy className="export-btn-icon" />Copy Outline</>)} variant="outline" onClick={handleCopyOutline} />
                            <Button label={(<><Download className="export-btn-icon" />Download PDF</>)} variant="outline" onClick={handleExportPDF} />
                        </div>
                        <Button label={(<><FileText className="export-btn-icon-sm" />Save to History</>)} onClick={handleSaveSession} className="export-save-btn" />
                    </div>
                </Card>
            </div>
        </div>
    );
}
