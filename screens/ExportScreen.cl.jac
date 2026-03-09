"""Juncture - Export Screen for exporting argument outlines and saving sessions."""

# Import UI components
import from .components.ui.button { Button }
import from .components.ui.card { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from .components.ui.alert { Alert, AlertDescription }
import from .components.ui.badge { Badge }

# Import icons
import from .components.icons { 
    ArrowLeft, Download, FileText, AlertTriangle, 
    CheckCircle2, Copy 
}

# Import node types
import from .WelcomeScreen { User, Session, ArgumentGraph }

# Walker to save session to user's history
walker SaveSessionToHistory {
    has userId: str,
        graphId: str,
        notes: str,
        score: dict;
    
    can save_session with `root entry {
        # Find user node
        user_node = None;
        for user in -->`root[?User] {
            if user.id == self.userId {
                user_node = user;
                break;
            }
        }
        
        if not user_node {
            report {"error": "User not found"};
            return;
        }
        
        # Find graph node
        graph_node = None;
        for graph in -->`root[?ArgumentGraph] {
            if graph.id == self.graphId {
                graph_node = graph;
                break;
            }
        }
        
        # Generate session title from graph thesis
        title = "Untitled Argument";
        if graph_node {
            thesis_nodes = [n for n in graph_node.nodes if n["type"] == "THESIS"];
            if len(thesis_nodes) > 0 {
                thesis_content = thesis_nodes[0]["content"];
                title = thesis_content[:50] + "..." if len(thesis_content) > 50 else thesis_content;
            }
        }
        
        # Create new session
        new_session = Session(
            id=f"session_{str(time.time()).replace('.', '')}",
            date=str(datetime.now()),
            title=title,
            initialScore=self.score["overall"],
            finalScore=self.score["overall"],
            notes=self.notes
        );
        
        # Connect session to user and graph
        user_node ++> new_session;
        if graph_node {
            new_session ++> graph_node;
        }
        
        report {"success": True, "session": new_session};
    }
}

# Walker to get user sessions
walker GetUserSessions {
    has userId: str;
    
    can get_sessions with `root entry {
        # Find user node
        user_node = None;
        for user in -->`root[?User] {
            if user.id == self.userId {
                user_node = user;
                break;
            }
        }
        
        if not user_node {
            report [];
            return;
        }
        
        # Get all connected sessions
        sessions = [];
        for session in -->user_node[?Session] {
            sessions.append(session);
        }
        
        report sessions;
    }
}

# Client-side component
def:pub ExportScreen -> JsxElement {
    has currentGraph: dict = None,
        currentScore: dict = None,
        currentIssues: list = [],
        currentNotes: str = "",
        exportFormat: str = "text",  # "text" | "pdf"
        userId: str = "";
    
    # TODO: Get data from context/state when implemented
    can with entry {
        # userId = getCurrentUser().id;
        # graphId = getCurrentGraphId();
        # currentGraph = getCurrentGraph();
        # currentScore = getCurrentScore();
        # currentIssues = getCurrentIssues();
        # currentNotes = getCurrentNotes();
        
        # Mock data for now
        userId = "user_123";
        
        currentGraph = {
            "nodes": [
                {"id": "node_thesis", "type": "THESIS", "content": "Remote work increases overall productivity"},
                {"id": "node_claim_1", "type": "CLAIM", "content": "Eliminates commute time waste"},
                {"id": "node_evidence_1", "type": "EVIDENCE", "content": "Average commute is 54 minutes daily"}
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
        
        currentIssues = [];
        currentNotes = "Example notes about remote work";
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
        outline += "=" * 50 + "\n\n";
        
        if thesis {
            outline += f"THESIS:\n{thesis['content']}\n\n";
        }
        
        outline += "MAIN CLAIMS:\n";
        
        for i, claim in enumerate(claims) {
            # Find supporting evidence
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
            
            # Check if claim has issues
            has_issues = any([i for i in currentIssues if i["nodeId"] == claim["id"]]);
            
            outline += f"\n{i + 1}. {claim['content']}";
            
            if includeFlags and has_issues {
                outline += " (⚠️ Needs evidence)";
            }
            
            outline += "\n";
            
            if len(claim_evidence) > 0 {
                outline += "   Supporting Evidence:\n";
                for ev in claim_evidence {
                    outline += f"   • {ev['content']}\n";
                }
            }
        }
        
        outline += "\n" + "=" * 50 + "\n";
        outline += f"Reasoning Score: {currentScore['overall']}/100\n";
        
        if includeFlags and len(currentIssues) > 0 {
            plural = "s" if len(currentIssues) > 1 else "";
            outline += f"\n⚠️ {len(currentIssues)} issue{plural} detected\n";
        }
        
        return outline;
    }
    
    def handleExportText() -> None {
        show_flags = currentScore["overall"] < 75;
        outline = generateOutlineText(show_flags);
        
        # Copy to clipboard
        # TODO: Implement clipboard API when available
        # navigator.clipboard.writeText(outline);
        
        print("Outline copied to clipboard");
        # TODO: Show success toast
    }
    
    def handleExportPDF() -> None {
        # TODO: Implement PDF generation when jsPDF is available
        # For now, just log
        show_flags = currentScore["overall"] < 75;
        outline = generateOutlineText(show_flags);
        
        print("Exporting as PDF:");
        print(outline);
        
        # TODO: Show success toast
    }
    
    async def handleSaveSession() -> None {
        # TODO: Replace with actual walker call when backend is integrated
        # walker_result = root spawn SaveSessionToHistory(
        #     userId=userId,
        #     graphId=currentGraph.id,
        #     notes=currentNotes,
        #     score=currentScore
        # );
        
        print("Session saved to history");
        # TODO: Show success toast
    }
    
    def navigateBack() -> None {
        # TODO: Navigate back to review screen
        # navigate("/review");
        print("Navigate back to review");
    }
    
    def navigateToGenerate() -> None {
        # TODO: Navigate to generate screen
        # navigate("/generate");
        print("Navigate to generate");
    }
    
    def navigateToProfile() -> None {
        # TODO: Navigate to profile screen
        # navigate("/profile");
        print("Navigate to profile");
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
                    <Button variant="ghost" size="sm" onClick={navigateBack}>
                        <ArrowLeft className="h-4 w-4 mr-2" />
                        Back to Map
                    </Button>
                    <h1 className="text-xl font-bold">Export Outline</h1>
                </div>
            </header>

            <div className="max-w-4xl mx-auto p-6 space-y-6">
                <Card>
                    <CardHeader>
                        <CardTitle className="flex items-center justify-between">
                            <span>Final Score</span>
                            <Badge
                                variant={"default" if currentScore["overall"] >= 75 else "destructive"}
                                className="text-lg px-4 py-1"
                            >
                                {currentScore["overall"]}/100
                            </Badge>
                        </CardTitle>
                        <CardDescription>
                            {"Your argument is well-structured and ready to export!"
                                if currentScore["overall"] >= 75 else
                                "Your argument could be improved before exporting."}
                        </CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-4">
                        <div className="grid grid-cols-3 gap-4">
                            <div className="text-center p-3 bg-gray-50 rounded-lg">
                                <div className="text-2xl font-bold text-gray-900">
                                    {currentScore["support"]}%
                                </div>
                                <div className="text-xs text-gray-600">Support</div>
                            </div>
                            <div className="text-center p-3 bg-gray-50 rounded-lg">
                                <div className="text-2xl font-bold text-gray-900">
                                    {currentScore["premise"]}%
                                </div>
                                <div className="text-xs text-gray-600">Premise</div>
                            </div>
                            <div className="text-center p-3 bg-gray-50 rounded-lg">
                                <div className="text-2xl font-bold text-gray-900">
                                    {currentScore["consistency"]}%
                                </div>
                                <div className="text-xs text-gray-600">Consistency</div>
                            </div>
                        </div>
                    </CardContent>
                </Card>

                {(
                    <Alert className="border-amber-200 bg-amber-50">
                        <AlertTriangle className="h-4 w-4 text-amber-600" />
                        <AlertDescription>
                            <p className="font-medium text-amber-900 mb-2">
                                Your outline will export now, but we found some issues:
                            </p>
                            <ul className="text-sm space-y-1 text-amber-800">
                                {(
                                    <li>• {unsupported_count} claim{"s are"  if unsupported_count > 1 else " is"} unsupported</li>
                                ) if unsupported_count > 0 else None}
                                {(
                                    <li>• {contradiction_count} unresolved contradiction{"s" if contradiction_count > 1 else ""}</li>
                                ) if contradiction_count > 0 else None}
                            </ul>
                            <div className="mt-3">
                                <Button
                                    variant="outline"
                                    size="sm"
                                    onClick={navigateBack}
                                    className="border-amber-300 hover:bg-amber-100"
                                >
                                    Fix Top 3 Issues First
                                </Button>
                            </div>
                        </AlertDescription>
                    </Alert>
                ) if show_warning else (
                    <Alert className="border-green-200 bg-green-50">
                        <CheckCircle2 className="h-4 w-4 text-green-600" />
                        <AlertDescription className="text-green-900">
                            <p className="font-medium">
                                Great work! Your argument is well-structured and ready to export.
                            </p>
                        </AlertDescription>
                    </Alert>
                )}

                <Card>
                    <CardHeader>
                        <CardTitle>Outline Preview</CardTitle>
                        <CardDescription>
                            This is what will be exported
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <div className="bg-gray-50 rounded-lg p-4 font-mono text-sm whitespace-pre-wrap max-h-[400px] overflow-y-auto border">
                            {generateOutlineText(show_warning)}
                        </div>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader>
                        <CardTitle>Export Options</CardTitle>
                        <CardDescription>
                            Choose your export format
                        </CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-4">
                        <div className="grid grid-cols-2 gap-4">
                            <Button
                                variant="outline"
                                onClick={handleExportText}
                                className="h-auto py-6 flex flex-col gap-2"
                            >
                                <Copy className="h-8 w-8" />
                                <div>
                                    <div className="font-semibold">Copy to Clipboard</div>
                                    <div className="text-xs opacity-70">
                                        Paste into Google Docs
                                    </div>
                                </div>
                            </Button>

                            <Button
                                variant="outline"
                                onClick={handleExportPDF}
                                className="h-auto py-6 flex flex-col gap-2"
                            >
                                <Download className="h-8 w-8" />
                                <div>
                                    <div className="font-semibold">Download PDF</div>
                                    <div className="text-xs opacity-70">
                                        Save as document
                                    </div>
                                </div>
                            </Button>
                        </div>

                        <div className="pt-4 border-t">
                            <Button
                                variant="default"
                                onClick={handleSaveSession}
                                className="w-full"
                            >
                                <FileText className="h-4 w-4 mr-2" />
                                Save to History
                            </Button>
                        </div>
                    </CardContent>
                </Card>
                
                <Card className="bg-indigo-50 border-indigo-200">
                    <CardHeader>
                        <CardTitle className="text-sm">What's Next?</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-2 text-sm">
                        <p>
                            <strong>Google Docs:</strong> Paste your outline and format as
                            needed for your paper or presentation.
                        </p>
                        <p>
                            <strong>Slides:</strong> Use each main claim as a slide title with
                            evidence as bullet points.
                        </p>
                        <p>
                            <strong>Improve:</strong> Go back to the review screen to address
                            any remaining issues.
                        </p>
                    </CardContent>
                </Card>

                <div className="flex gap-3">
                    <Button variant="outline" onClick={navigateToGenerate} className="flex-1">
                        Start New Argument
                    </Button>
                    <Button variant="outline" onClick={navigateToProfile} className="flex-1">
                        View Profile
                    </Button>
                </div>
            </div>
        </div>;
}
