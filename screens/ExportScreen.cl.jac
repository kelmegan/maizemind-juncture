"""Export Screen"""

import from "lucide-react" { ArrowLeft, Download, FileText, AlertTriangle, CheckCircle2, Copy }

import from ..components.Alert { Alert }
import from ..components.Badge { Badge }
import from ..components.Button { Button }
import from ..components.Card { Card }

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
        show_flags = currentScore["overall"] < 75;

        outline = generateOutlineText(show_flags);

        print("Copy to clipboard:");
        print(outline);
    }

    def handleExportPDF() -> None {
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

    def navigateBack() -> None {
        navigate("review");
    }

    def navigateToGenerate() -> None {
        navigate("generate");
    }

    def navigateToProfile() -> None {
        navigate("profile");
    }

    if not currentGraph or not currentScore {
        return <div className="flex items-center justify-center h-screen">
            <p>Loading...</p>
        </div>;
    }

    show_warning = currentScore["overall"] < 75;
    unsupported_count = currentScore["unsupportedClaims"];
    contradiction_count = currentScore["unresolvedContradictions"];

    return
        <div className="min-h-screen bg-gray-50">
            <header className="bg-white border-b px-4 py-3">
                <div className="max-w-4xl mx-auto flex items-center gap-4">
                    <Button label={(<><ArrowLeft className="h-4 w-4 mr-2" />Back to Map</>)} variant="ghost" size="sm" onClick={navigateBack} />
                    <h1 className="text-xl font-bold">
                        Export Outline
                    </h1>
                </div>
            </header>
            <div className="max-w-4xl mx-auto p-6 space-y-6">
                <Card
                    title={
                        <div className="flex items-center justify-between">
                            <span>Final Score</span>
                            <Badge
                                variant={"default" if currentScore["overall"] >= 75 else "destructive"}
                                className="text-lg px-4 py-1"
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
                    <Alert className="border-green-200 bg-green-50">
                        <CheckCircle2 className="h-4 w-4 text-green-600" />
                        <p className="font-medium text-green-900">Great work! Your argument is ready to export.</p>
                    </Alert>
                ) if not show_warning else (
                    <Alert className="border-amber-200 bg-amber-50">
                        <AlertTriangle className="h-4 w-4 text-amber-600" />
                        <p>Some issues were detected before export.</p>
                    </Alert>
                )}
                <Card title="Outline Preview">
                    <div className="bg-gray-50 rounded-lg p-4 font-mono text-sm whitespace-pre-wrap border">
                        {generateOutlineText(show_warning)}
                    </div>
                </Card>
                <Card title="Export Options">
                    <div className="space-y-4">
                        <div className="grid grid-cols-2 gap-4">
                            <Button label={(<><Copy className="h-6 w-6" />Copy Outline</>)} variant="outline" onClick={handleExportText} />
                            <Button label={(<><Download className="h-6 w-6" />Download PDF</>)} variant="outline" onClick={handleExportPDF} />
                        </div>
                        <Button label={(<><FileText className="h-4 w-4 mr-2" />Save to History</>)} variant="default" onClick={handleSaveSession} className="w-full" />
                    </div>
                </Card>
                <div className="flex gap-3">
                    <Button label="Start New Argument" variant="outline" onClick={navigateToGenerate} className="flex-1" />
                    <Button label="View Profile" variant="outline" onClick={navigateToProfile} className="flex-1" />
                </div>
            </div>
        </div>;
}