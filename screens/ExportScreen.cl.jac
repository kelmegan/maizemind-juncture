"""Export Screen"""

sv import from ...main { GetContext, CreateSession }
import from "lucide-react" { Download, FileText, AlertTriangle, CheckCircle2, Copy }
import from "jspdf" { jsPDF }

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
        exportFormat: str = "text",
        copyStatus: str = "", # "" | "success" | "failure" | "pdf-success" | "pdf-failure"
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

        NL = chr(10);

        thesis_node = None;
        claim_nodes = [];
        evidence_nodes = {};

        for node in nodes {
            if node["type"] == "THESIS" { thesis_node = node; }
            elif node["type"] == "CLAIM" { claim_nodes.append(node); }
            elif node["type"] == "EVIDENCE" { evidence_nodes[node["id"]] = node; }
        }

        outline = "ARGUMENT OUTLINE" + NL;
        outline += "==================================================" + NL + NL;

        if thesis_node {
            outline += "THESIS:" + NL;
            outline += thesis_node["content"] + NL + NL;
        }

        if len(claim_nodes) > 0 {
            outline += "MAIN CLAIMS:" + NL;
            i = 1;
            for claim in claim_nodes {
                outline += str(i) + ". " + claim["content"] + NL;

                supporting = [];
                for edge in edges {
                    if edge["target"] == claim["id"] and edge["type"] == "SUPPORTS" {
                        if edge["source"] in evidence_nodes {
                            supporting.append(evidence_nodes[edge["source"]]);
                        }
                    }
                }

                if len(supporting) > 0 {
                    outline += "   Supporting Evidence:" + NL;
                    for ev in supporting {
                        outline += "   - " + ev["content"] + NL;
                    }
                }

                outline += NL;
                i += 1;
            }
        }

        outline += "==================================================" + NL;
        outline += "Reasoning Score: " + str(currentScore["overall"]) + "/100" + NL;

        return outline;
    }

    def handleExportText() -> None {
        show_flags = currentScore["overall"] < 75;
        outline_text = generateOutlineText(show_flags);

        navigator.clipboard.writeText(outline_text)
            .then(lambda _: any -> None {
                copyStatus = "success";
                setTimeout(lambda -> None { copyStatus = ""; }, 3000);
            })
            .catch(lambda _: any -> None {
                copyStatus = "failure";
                setTimeout(lambda -> None { copyStatus = ""; }, 3000);
            });
    }

    def handleExportPDF() -> None {
        show_flags = currentScore["overall"] < 75;
        outline = generateOutlineText(show_flags);

        # Reflect.construct is required because JAC bans the `new` keyword.
        # jsPDF() with no args defaults to portrait, mm units, A4 page size.
        doc = Reflect.construct(jsPDF, []);

        # jsPDF.splitTextToSize wraps long lines to fit within the page width.
        # A4 usable width is ~190mm (210mm - 10mm margin each side).
        margin = 10;
        page_width = doc.internal.pageSize.getWidth();
        usable_width = page_width - (margin * 2);

        doc.setFont("courier", "normal");
        doc.setFontSize(10);

        y = margin;
        line_height = 5;

        for raw_line in outline.split(chr(10)) {
            # Wrap the line if it's too wide, then write each wrapped segment.
            wrapped = doc.splitTextToSize(raw_line, usable_width);
            for segment in wrapped {
                # Add a new page if we've run out of vertical space.
                if y + line_height > doc.internal.pageSize.getHeight() - margin {
                    doc.addPage();
                    y = margin;
                }
                doc.text(segment, margin, y);
                y += line_height;
            }
        }

        doc.save("argument-outline.pdf");
        copyStatus = "pdf-success";
        setTimeout(lambda -> None { copyStatus = ""; }, 3000);
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

    outline_lines = [];
    i = 0;
    for line in generateOutlineText(show_warning).split(chr(10)) {
        outline_lines.append(<div key={str(i)}>{line}</div>);
        i += 1;
    }

    return (
        <div className="export-page">
            <Header navigate={navigate} screen="export" title="Export Outline" backTo="review" />

            {(
                <Alert className="export-alert-success">
                    <CheckCircle2 className="export-alert-success-icon" />
                    <p className="export-alert-success-text">Outline copied to clipboard successfully!</p>
                </Alert>
            ) if copyStatus == "success" else (
                <Alert className="export-alert-warning">
                    <AlertTriangle className="export-alert-warning-icon" />
                    <p>Copy to clipboard failed. Please try again.</p>
                </Alert>
            ) if copyStatus == "failure" else (
                <Alert className="export-alert-success">
                    <CheckCircle2 className="export-alert-success-icon" />
                    <p className="export-alert-success-text">Outline downloaded successfully!</p>
                </Alert>
            ) if copyStatus == "pdf-success" else (
                <Alert className="export-alert-warning">
                    <AlertTriangle className="export-alert-warning-icon" />
                    <p>Download failed. Please try again.</p>
                </Alert>
            ) if copyStatus == "pdf-failure" else None}
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
                        {outline_lines}
                    </div>
                </Card>

                <Card title="Export Options">
                    <div className="export-options-body">
                        <div className="export-options-grid">
                            <Button label={(<><Copy className="export-btn-icon" />Copy Outline</>)} variant="outline" onClick={handleCopyOutline} />
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
