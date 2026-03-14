"""Export Screen"""

sv import from ...main { GetContext, CreateSession }
import from "lucide-react" { Download, FileText, AlertTriangle, CheckCircle2, Copy }

import from ..components.Alert { Alert }
import from ..components.Badge { Badge }
import from ..components.Button { Button }
import from ..components.Card { Card }
import from ..components.Header { Header }

def:pub ExportScreen(props: any) -> JsxElement {
    navigate = props.navigate;
    screen_data = props.screenData if props.screenData else {};

    has currentGraph: dict = None,
        currentScore: dict = None,
        currentIssues: list = [],
        userId: str = "",
        saved: bool = False;

    async def loadContext() -> None {
        try {
            ctx = await root spawn GetContext();
            if ctx and "currentUser" in ctx and ctx["currentUser"] {
                userId = ctx["currentUser"]["id"] if "id" in ctx["currentUser"] else "";
            }
        } except Exception {
            # Context not available
        }

        currentGraph = screen_data["graphData"] if "graphData" in screen_data else None;
        currentScore = screen_data["scoreData"] if "scoreData" in screen_data else None;
        currentIssues = screen_data["issuesData"] if "issuesData" in screen_data else [];
    }

    can with entry {
        loadContext();
    }

    def generateOutlineText(includeFlags: bool) -> str {
        if not currentGraph {
            return "";
        }
        nodes = currentGraph["nodes"] if "nodes" in currentGraph else [];
        edges = currentGraph["edges"] if "edges" in currentGraph else [];
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
            } elif includeFlags {
                outline += "   • Needs evidence\n";
            }
            i += 1;
        }

        outline += "\n==================================================\n";
        outline += f"Reasoning Score: {currentScore['overall']}/100\n";

        return outline;
    }

    def handleExportText() -> None {
        show_flags = currentScore["overall"] < 75;
        outline = generateOutlineText(show_flags);
        navigator.clipboard.writeText(outline);
    }

    def handleExportPDF() -> None {
        show_flags = currentScore["overall"] < 75;
        outline = generateOutlineText(show_flags);
        print("Export PDF:");
        print(outline);
    }

    async def handleSaveSession() -> None {
        if not userId or saved {
            return;
        }
        graphId = currentGraph["id"] if currentGraph and "id" in currentGraph else "";
        await root spawn CreateSession(
            userId=userId,
            graphId=graphId,
            notes="",
            score=currentScore
        );
        saved = True;
    }

    if not currentGraph or not currentScore {
        return <div className="export-loading"><p>Loading...</p></div>;
    }

    show_warning = currentScore["overall"] < 75;

    return (
        <div className="export-page">
            <Header navigate={navigate} screen="export" title="Export Outline" backTo="review" />

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
                        <Button
                            label={(<><FileText className="export-btn-icon-sm" />{("Saved!" if saved else "Save to History")}</>)}
                            onClick={handleSaveSession}
                            disabled={saved or not userId}
                            className="export-save-btn"
                        />
                    </div>
                </Card>
            </div>
        </div>
    );
}
