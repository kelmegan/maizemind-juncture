"""Export Screen"""

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
        currentNextActions: list = [],
        userId: str = "",
        exportFormat: str = "text",
        copyStatus: str = "",
        saved: bool = False,
        isLoading: bool = True,
        isGuest: bool = True;

    async def loadContext() -> None {
        isLoading = True;
        saved = False;
        ctx = None;
        try {
            raw = await root spawn GetContext();
            if raw and raw["reports"] {
                ctx = raw["reports"][0];
            }
            if ctx and "currentUser" in ctx and ctx["currentUser"] {
                userId = ctx["currentUser"]["id"] if "id" in ctx["currentUser"] else "";
                isGuest = ctx["currentUser"]["isGuest"];
            }
        } except Exception {
            # Context not available
        }

        if not currentGraph and ctx and "currentGraph" in ctx {
            currentGraph = ctx["currentGraph"];
        }

        if currentGraph and not currentScore and "id" in currentGraph {
            try {
                scored = await root spawn GetGraphWithScoring(graphId=currentGraph["id"]);
                scored_data = scored["reports"][0] if scored["reports"] else {};
                if "error" not in scored_data {
                    currentGraph = scored_data["graph"] if "graph" in scored_data else currentGraph;
                    currentScore = scored_data["score"] if "score" in scored_data else currentScore;
                    currentIssues = scored_data["issues"] if "issues" in scored_data else currentIssues;
                    currentNextActions = scored_data["nextActions"] if "nextActions" in scored_data else currentNextActions;
                }
            } except Exception {
                # Keep whatever we have
            }
        }

        isLoading = False;
    }

    can with entry {
        if "graphData" in screen_data { currentGraph = screen_data["graphData"]; }
        if "scoreData" in screen_data { currentScore = screen_data["scoreData"]; }
        if "issuesData" in screen_data { currentIssues = screen_data["issuesData"]; }
        if "nextActionsData" in screen_data { currentNextActions = screen_data["nextActionsData"]; }
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
            thesis_supporting = [];
            for edge in edges {
                if edge["target"] == thesis_node["id"] and edge["type"] == "SUPPORTS" {
                    if edge["source"] in evidence_nodes {
                        thesis_supporting.append(evidence_nodes[edge["source"]]);
                    }
                }
            }
            thesis_suffix = " (Needs evidence)" if includeFlags and len(thesis_supporting) == 0 else "";
            outline += thesis_node["content"] + thesis_suffix + NL + NL;
        }

        if len(claim_nodes) > 0 {
            outline += "MAIN CLAIMS:" + NL;
            i = 1;
            for claim in claim_nodes {
                supporting = [];
                for edge in edges {
                    if edge["target"] == claim["id"] and edge["type"] == "SUPPORTS" {
                        if edge["source"] in evidence_nodes {
                            supporting.append(evidence_nodes[edge["source"]]);
                        }
                    }
                }
                claim_suffix = " (Needs evidence)" if includeFlags and len(supporting) == 0 else "";
                outline += str(i) + ". " + claim["content"] + claim_suffix + NL;

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

    def handleCopyOutline() -> None {
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

    def handleFixTopIssues() -> None {
        navigate("review", {
            "graphData": currentGraph,
            "scoreData": currentScore,
            "issuesData": currentIssues,
            "nextActionsData": currentNextActions
        });
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

    if isLoading {
        return <div className="export-loading"><p>Loading...</p></div>;
    }

    if not currentGraph or not currentScore {
        return (
            <div className="export-loading">
                <p>No data available. Please generate an argument map first.</p>
                <Button label="Go to Generate" onClick={lambda -> None { navigate("generate"); }} />
            </div>
        );
    }


    show_warning = currentScore["overall"] < 75;
    unsupported_claims = currentScore["unsupportedClaims"] if "unsupportedClaims" in currentScore else 0;
    fix_count = unsupported_claims;
    if fix_count > 3 { fix_count = 3; }
    if fix_count < 1 {
        fix_count = min(3, len(currentIssues));
    }
    if fix_count < 1 { fix_count = 1; }

    outline_lines = [];
    i = 0;
    for line in generateOutlineText(show_warning).split(chr(10)) {
        outline_lines.append(<div key={str(i)}>{line}</div>);
        i += 1;
    }

    return (
        <div className="export-page">
            <Header navigate={navigate} screen="export" title="Export" backTo="review" />

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
                        <div>
                            <p>Export now, but {' ' + unsupported_claims} claims are unsupported. Want to fix the top {' ' + fix_count} issues first?</p>
                            <div style={{"marginTop": "10px"}}>
                                <Button label="Fix Top Issues First" variant="outline" onClick={handleFixTopIssues} />
                            </div>
                        </div>
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
                        {<Button
                            label={(<><FileText className="export-btn-icon-sm" />{("Saved!" if saved else "Save to History")}</>)}
                            onClick={handleSaveSession}
                            disabled={saved or not userId}
                            className="export-save-btn"
                        /> if not isGuest else None}
                    </div>
                </Card>
            </div>
        </div>
    );
}
