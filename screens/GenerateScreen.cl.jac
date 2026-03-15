"""Juncture - Generate Screen for creating argument maps from notes."""

sv import from ...main { GetContext, GenerateArgumentGraph, UpdateContext }
import from "lucide-react" { Upload, Sparkles, ArrowRight }
import from "pdfjs-dist" { getDocument, GlobalWorkerOptions }
import from "mammoth" { extractRawText }

import from ..components.Button { Button }
import from ..components.Card { Card }
import from ..components.Header { Header }

def:pub GenerateScreen(props: any) -> JsxElement {
    navigate = props.navigate;

    has notes: str = "",
        isGenerating: bool = False,
        generateStatus: str = "",
        currentUserId: str = "",
        isGuest: bool = False,
        showConfirmRegenerate: bool = False,
        hasExistingGraph: bool = False;

    async def loadContext() -> None {
        try {
            ctx = await root spawn GetContext();
            if ctx and ctx["currentUser"] {
                currentUserId = ctx["currentUser"]["id"];
                isGuest = ctx["currentUser"]["isGuest"];
            }
            if ctx and ctx["currentGraph"] {
                hasExistingGraph = True;
            }
        } except Exception {
            # Context not available
        }
    }

    can with entry {
        loadContext();
    }

    async def handleGenerate() -> None {
        if not notes.trim() { return; }

        # If user already has a graph, confirm first
        if hasExistingGraph and not showConfirmRegenerate {
            showConfirmRegenerate = True;
            return;
        }
        showConfirmRegenerate = False;

        isGenerating = True;
        generateStatus = "Step 1/3: Parsing notes into argument structure...";
        setTimeout(lambda -> None {
            if isGenerating {
                generateStatus = "Step 2/3: Analyzing graph and generating critique...";
            }
        }, 1200);
        setTimeout(lambda -> None {
            if isGenerating {
                generateStatus = "Step 3/3: Calculating reasoning score...";
            }
        }, 2600);
        try {
            result = await root spawn GenerateArgumentGraph(
                notes=notes,
                userId=currentUserId
            );

            data = result.reports[0] if result.reports else {};

            # Check for error
            if "error" in data {
                generateStatus = f"Error: {data['error']}. Please try again.";
                isGenerating = False;
                return;
            }

            graphData = data["graph"] if "graph" in data else {};
            scoreData = data["score"] if "score" in data else {};
            issuesData = data["issues"] if "issues" in data else [];
            nextActionsData = data["nextActions"] if "nextActions" in data else [];
            counterargSuggestions = data["suggested_counterarguments"] if "suggested_counterarguments" in data else [];

            # Check for empty graph (LLM returned nothing)
            nodes_list = graphData["nodes"] if "nodes" in graphData else [];
            if len(nodes_list) == 0 {
                generateStatus = "The AI returned an empty graph. This sometimes happens. Please try again.";
                isGenerating = False;
                return;
            }

            isGenerating = False;
            generateStatus = "";
            hasExistingGraph = True;
            navigate("review", {
                "graphData": graphData,
                "scoreData": scoreData,
                "issuesData": issuesData,
                "nextActionsData": nextActionsData,
                "suggestedCounterarguments": counterargSuggestions
            });

            try {
                await root spawn UpdateContext(currentGraph=graphData);
            } except Exception {
                # Context update is non-critical
            }
        } except Exception as e {
            print(f"Generation error: {e}");
            generateStatus = f"Error generating graph. Please try again.";
            isGenerating = False;
        }
    }

    def cancelRegenerate() -> None {
        showConfirmRegenerate = False;
    }

    def loadExampleNotes() -> None {
        notes = "Remote work increases productivity and employee satisfaction. Employees save time without commuting - the average commute is 54 minutes daily. Flexible schedules improve work-life balance. Remote work reduces office distractions. However, remote workers report feeling isolated which could impact morale. Companies also save money on office space costs.";
    }

    def handleDivClick() -> None {
        document.getElementById("file-input").click();
    }

    async def handleFileUpload(e: any) -> None {
        file = e.target.files[0] if e.target.files else None;
        if not file { return; }
        file_name = file.name.toLowerCase();
        if file_name.endswith(".txt") or file_name.endswith(".md") {
            reader = Reflect.construct(FileReader, []);
            reader.onload = lambda event -> None { notes = event.target.result; };
            reader.readAsText(file);
        } elif file_name.endswith(".pdf") {
            GlobalWorkerOptions.workerSrc = "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.0.379/pdf.worker.min.js";
            array_buffer = await file.arrayBuffer();
            pdf = await getDocument({"data": array_buffer}).promise;
            text = "";
            i = 1;
            while i <= pdf.numPages {
                page = await pdf.getPage(i);
                content = await page.getTextContent();
                page_text = content.items.map(lambda item -> any { return item.str; }).join(" ");
                text = text + page_text + "\n";
                i = i + 1;
            }
            notes = text;
        } elif file_name.endswith(".docx") {
            array_buffer = await file.arrayBuffer();
            result = await extractRawText({"arrayBuffer": array_buffer});
            notes = result.value;
        }
    }

    def handleNotesChange(e: any) -> None {
        notes = e.target.value;
    }

    return (
        <div className="generate-page">
            <Header navigate={navigate} screen="generate"/>

            <div className="generate-content">
                <div className="generate-hero">
                    <h2 className="generate-hero-title">Transform Your Notes</h2>
                    <p className="generate-hero-subtitle">
                        Paste your messy notes below, and we'll create an argument map with instant feedback
                    </p>
                </div>

                <Card
                    title={(<span className="card-title-icon"><Sparkles />Your Notes</span>)}
                    description="Paste your research notes, brainstorming, or draft arguments. The messier, the better!"
                >
                    <div className="notes-card-body">
                        <div>
                            <label className="notes-label" htmlFor="notes">Notes</label>
                            <textarea
                                id="notes"
                                placeholder="Example: Remote work has benefits and drawbacks. People save time commuting (about an hour per day on average). They have more flexibility for work-life balance. But some studies show isolation can be an issue. Companies save money on office space. Productivity might increase because fewer distractions..."
                                value={notes}
                                onChange={handleNotesChange}
                                className="notes-textarea"
                                disabled={isGenerating}
                            />
                        </div>

                        <input
                            id="file-input"
                            type="file"
                            accept=".txt,.md,.pdf,.docx"
                            className="file-input-hidden"
                            onChange={handleFileUpload}
                        />
                        <div className="upload-dropzone" onClick={handleDivClick}>
                            <Upload className="upload-icon" />
                            <div className="upload-label">
                                <span className="upload-label-cta">Upload documents</span>
                            </div>
                            <p className="upload-hint">TXT, MD, PDF, DOCX up to 10MB</p>
                        </div>

                        {(
                            <div style={{
                                "padding": "14px", "background": "#fffbeb",
                                "border": "1px solid #fde68a", "borderRadius": "10px",
                                "marginBottom": "12px"
                            }}>
                                <p style={{"fontSize": "13px", "color": "#92400e", "marginBottom": "10px"}}>
                                    You already have a graph. Generating a new one will replace it. Continue?
                                </p>
                                <div style={{"display": "flex", "gap": "8px"}}>
                                    <Button label="Yes, regenerate" onClick={handleGenerate} className="generate-btn" />
                                    <Button label="Cancel" variant="outline" onClick={cancelRegenerate} />
                                </div>
                            </div>
                        ) if showConfirmRegenerate else None}

                        {(
                            <div style={{
                                "padding": "20px", "background": "rgba(99,102,241,0.06)",
                                "border": "1px solid rgba(99,102,241,0.15)", "borderRadius": "12px",
                                "textAlign": "center"
                            }}>
                                <div style={{"display": "flex", "alignItems": "center",
                                              "justifyContent": "center", "gap": "10px", "marginBottom": "8px"}}>
                                    <div style={{
                                        "width": "20px", "height": "20px", "border": "2px solid #6366f1",
                                        "borderTopColor": "transparent", "borderRadius": "50%",
                                        "animation": "spin 1s linear infinite"
                                    }}></div>
                                    <span style={{"fontSize": "14px", "fontWeight": "600", "color": "#6366f1"}}>
                                        Generating...
                                    </span>
                                </div>
                                <p style={{"fontSize": "13px", "color": "#64748b"}}>{generateStatus}</p>
                                <p style={{"fontSize": "11px", "color": "#94a3b8", "marginTop": "8px"}}>
                                    This usually takes 20-40 seconds
                                </p>
                            </div>
                        ) if isGenerating else (
                            <Button
                                label={(<>Generate Argument Map<ArrowRight className="generate-btn-icon" /></>)}
                                onClick={handleGenerate}
                                disabled={not notes.trim()}
                                className="generate-btn"
                            />
                        )}

                        { generateStatus and not isGenerating and
                            <div style={{
                                "padding": "14px", "background": "rgba(239,68,68,0.06)",
                                "border": "1px solid rgba(239,68,68,0.12)", "borderRadius": "10px",
                                "textAlign": "center", "marginTop": "12px"
                            }}>
                                <p style={{"fontSize": "13px", "color": "#dc2626", "marginBottom": "8px"}}>
                                    {generateStatus}
                                </p>
                                <Button label="Try Again" onClick={handleGenerate} className="generate-btn" />
                            </div>
                        }
                    </div>
                </Card>

                <Card
                    title="Quick Start Example"
                    className="quickstart-card"
                >
                    <Button label="Load example notes" variant="ghost" onClick={loadExampleNotes} />
                </Card>
            </div>
        </div>
    );
}
