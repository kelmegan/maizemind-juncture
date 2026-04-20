"""MaizeMind - Generate Screen for creating argument maps from notes."""

import from "@jac/runtime" { useNavigate }
import from react { useContext }
import from "lucide-react" { Upload, Sparkles, ArrowRight, FileText, X }
import from "pdfjs-dist" { getDocument, GlobalWorkerOptions }
import from "mammoth" { extractRawText }
import from ..screens.AppContext { getAppContext }
import from ..components.Button { Button }
import from ..components.Card { Card }
import from ..components.Header { Header }
import from ..components.Alert { Alert }

def:pub GenerateScreen(props: any) -> JsxElement {
    nav = useNavigate();
    _AppCtx = getAppContext();
    ctx = useContext(_AppCtx);

    has notes: str = "",
        generationMode: str = "education_argument",
        generationTemplate: str = "",
        isGenerating: bool = False,
        generateStatus: str = "",
        currentUserId: str = "",
        showConfirmRegenerate: bool = False,
        hasExistingGraph: bool = False,
        uploadAlert: any = None,
        uploadedFiles: list = [];

    def showUploadAlert(message: str, variant: str) -> None {
        uploadAlert = {"message": message, "variant": variant};
        setTimeout(lambda -> None {
            uploadAlert = None;
        }, 3000);
    }

    async def handleGenerate() -> None {
        if not notes.trim() { return; }

        if hasExistingGraph and not showConfirmRegenerate and ctx.isLoggedIn {
            showConfirmRegenerate = True;
            return;
        }
        showConfirmRegenerate = False;

        isGenerating = True;
        generateStatus = "Step 1/3: Parsing notes into argument structure..."
            if generationMode == "education_argument"
            else "Step 1/3: Structuring meeting decisions, options, and risks...";
        setTimeout(lambda -> None {
            if isGenerating {
                generateStatus = "Step 2/3: Analyzing graph and generating critique..."
                    if generationMode == "education_argument"
                    else "Step 2/3: Evaluating decision readiness and unresolved blockers...";
            }
        }, 1200);
        setTimeout(lambda -> None {
            if isGenerating {
                generateStatus = "Step 3/3: Calculating reasoning score..."
                    if generationMode == "education_argument"
                    else "Step 3/3: Building your decision board...";
            }
        }, 2600);
        try {
            combined_uploaded = uploadedFiles.map(lambda f -> any { return f["content"]; }).join("\n");
            result = await root spawn GenerateArgumentGraph(
                notes=notes + combined_uploaded,
                userId=currentUserId,
                mode=generationMode,
                template=generationTemplate
            );

            data = result["reports"][0] if result["reports"] else {};

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

            nodes_list = graphData["nodes"] if "nodes" in graphData else [];
            if len(nodes_list) == 0 {
                generateStatus = "The AI returned an empty graph. This sometimes happens. Please try again.";
                isGenerating = False;
                return;
            }

            isGenerating = False;
            generateStatus = "";
            hasExistingGraph = True;
            ctx.setGraphCache(graphData["id"], counterargSuggestions);
            nav("/review", {"state": {"graphId": graphData["id"], "suggestedCounterarguments": counterargSuggestions}});
        } except Exception as e {
            print(f"Generation error: {e}");
            generateStatus = f"Error generating graph. Please try again.";
            isGenerating = False;
        }
    }

    def cancelRegenerate() -> None {
        showConfirmRegenerate = False;
    }

    def handleDivClick() -> None {
        document.getElementById("file-input").click();
    }

    async def handleFileUpload(e: any) -> None {
        file = e.target.files[0] if e.target.files else None;
        if not file { return; }
        file_name = file.name.toLowerCase();
        array_buffer = None;
        result = None;
        try {
            if file_name.endsWith(".txt") or file_name.endsWith(".md") {
                reader = Reflect.construct(FileReader, []);
                reader.onload = lambda event -> None {
                    uploadedFiles = uploadedFiles + [{"name": file.name, "content": event.target.result}];
                };
                reader.readAsText(file);
            } elif file_name.endsWith(".pdf") {
                GlobalWorkerOptions.workerSrc = "https://unpkg.com/pdfjs-dist@4.10.38/build/pdf.worker.min.mjs";
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
                uploadedFiles = uploadedFiles + [{"name": file.name, "content": text}];
            } elif file_name.endsWith(".docx") {
                array_buffer = await file.arrayBuffer();
                result = await extractRawText({"arrayBuffer": array_buffer});
                uploadedFiles = uploadedFiles + [{"name": file.name, "content": result.value}];
            }
            showUploadAlert(f"\"{file.name}\" uploaded successfully", "default");
        } except Exception as err {
            print(f"Upload error: {err}");
            showUploadAlert(f"\"{file.name}\" failed to upload", "destructive");
        }
    }

    def handleRemoveFile(name: str) -> None {
        new_files = [];
        for f in uploadedFiles {
            if f["name"] != name {
                new_files = new_files + [f];
            }
        }
        uploadedFiles = new_files;
    }

    def handleOpenPreviousGraph() -> None {
        nav("/review", {"state": {"graphId": ctx.cachedGraphId, "suggestedCounterarguments": ctx.cachedCounterargSuggestions}});
        showConfirmRegenerate = False;
    }

    def handleNotesChange(e: any) -> None {
        notes = e.target.value;
    }

    def selectGenerationMode(mode: str) -> None {
        generationMode = mode;
        generationTemplate = "business_meeting_decision" if mode == "business_meeting_decision" else "";
    }

    mode_title = "Transform Your Notes" if generationMode == "education_argument" else "Build a Decision Board";
    mode_subtitle = "Paste your messy notes below, and we'll create an argument map with instant feedback"
        if generationMode == "education_argument"
        else "Paste meeting notes or a transcript, and we'll turn it into a decision board with options, risks, and next actions";
    notes_description = "Paste your research notes, brainstorming, or draft arguments. The messier, the better!"
        if generationMode == "education_argument"
        else "Paste meeting notes, call transcripts, or planning docs. We'll extract the decision, options, blockers, and follow-ups.";
    notes_placeholder = "Example: Remote work has benefits and drawbacks. People save time commuting (about an hour per day on average). They have more flexibility for work-life balance. But some studies show isolation can be an issue. Companies save money on office space. Productivity might increase because fewer distractions..."
        if generationMode == "education_argument"
        else "Example: We need to decide whether to launch the pilot in Q3. Option A is an internal-only rollout. Option B is a limited customer beta. Engineering says the core infrastructure is almost ready, but legal review is still incomplete. Megan will confirm the compliance timeline by May 2. Open question: can support staff the beta without delaying onboarding?";
    generate_label = "Generate Argument Map" if generationMode == "education_argument" else "Generate Decision Board";
    generate_note = "This can take a moment" if generationMode == "education_argument" else "This can take a moment while we structure the meeting";

    return (
        <div className="generate-page">
            <Header screen="generate"/>

            <div className="generate-content">
                <div className="generate-hero">
                    <h2 className="generate-hero-title">{mode_title}</h2>
                    <p className="generate-hero-subtitle">
                        {mode_subtitle}
                    </p>
                </div>

                <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "14px", "marginBottom": "20px"}}>
                    <button
                        onClick={lambda -> None { selectGenerationMode("education_argument"); }}
                        disabled={isGenerating}
                        style={{
                            "padding": "16px",
                            "borderRadius": "16px",
                            "border": "2px solid " + ("#2563eb" if generationMode == "education_argument" else "#dbe3f0"),
                            "background": "#eff6ff" if generationMode == "education_argument" else "#ffffff",
                            "textAlign": "left",
                            "cursor": "pointer"
                        }}
                    >
                        <div style={{"fontWeight": "700", "fontSize": "15px", "marginBottom": "6px"}}>Education / Argument</div>
                        <div style={{"fontSize": "13px", "color": "#4b5563"}}>
                            Default mode for essays, class notes, claims, evidence, and counterarguments.
                        </div>
                    </button>
                    <button
                        onClick={lambda -> None { selectGenerationMode("business_meeting_decision"); }}
                        disabled={isGenerating}
                        style={{
                            "padding": "16px",
                            "borderRadius": "16px",
                            "border": "2px solid " + ("#0f766e" if generationMode == "business_meeting_decision" else "#dbe3f0"),
                            "background": "#ecfeff" if generationMode == "business_meeting_decision" else "#ffffff",
                            "textAlign": "left",
                            "cursor": "pointer"
                        }}
                    >
                        <div style={{"fontWeight": "700", "fontSize": "15px", "marginBottom": "6px"}}>Business Meeting Decision</div>
                        <div style={{"fontSize": "13px", "color": "#4b5563"}}>
                            Optional mode for decisions, options, risks, open questions, and next actions.
                        </div>
                    </button>
                </div>

                <Card
                    title={(<span className="card-title-icon"><Sparkles />Your Notes</span>)}
                    description={notes_description}
                >
                    <div className="notes-card-body">
                        <div>
                            <label className="notes-label" htmlFor="notes">Notes</label>
                            <textarea
                                id="notes"
                                placeholder={notes_placeholder}
                                value={notes}
                                onChange={handleNotesChange}
                                className="notes-textarea"
                                disabled={isGenerating}
                            />
                        </div>

                        {uploadAlert and (
                            <Alert
                                variant={uploadAlert["variant"]}
                                description={uploadAlert["message"]}
                            />
                        )}

                        {len(uploadedFiles) > 0 and (
                            <div className="upload-file-chips">
                                {uploadedFiles.map(lambda f -> any {
                                    return (
                                        <div className="upload-file-chip" key={f["name"]}>
                                            <FileText className="upload-file-chip-icon" />
                                            <span className="upload-file-chip-name">{f["name"]}</span>
                                            <button
                                                className="upload-file-chip-remove"
                                                onClick={lambda -> None { handleRemoveFile(f["name"]); }}
                                                aria-label="Remove file"
                                            >
                                                <X className="upload-file-chip-remove-icon" />
                                            </button>
                                        </div>
                                    );
                                })}
                            </div>
                        )}

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
                            <div className="generate-confirm-box">
                                <p className="generate-confirm-text">
                                    You already have a graph. What would you like to do?
                                </p>
                                <div className="generate-confirm-actions">
                                    <Button label="Generate new graph" onClick={handleGenerate} className="generate-btn" />
                                    <Button label="Open previous graph" variant="outline" onClick={handleOpenPreviousGraph} />
                                    <Button label="Cancel" variant="outline" onClick={cancelRegenerate} />
                                </div>
                            </div>
                        ) if showConfirmRegenerate else None}

                        {(
                            <div className="generate-spinner-box">
                                <div className="generate-spinner-row">
                                    <div className="generate-spinner-wheel"></div>
                                    <span className="generate-spinner-label">Generating...</span>
                                </div>
                                <p className="generate-spinner-status">{generateStatus}</p>
                                <p className="generate-spinner-note">{generate_note}</p>
                            </div>
                        ) if isGenerating else (
                            <Button
                                label={(<>{generate_label}<ArrowRight className="generate-btn-icon" /></>)}
                                onClick={handleGenerate}
                                disabled={not notes.trim()}
                                className="generate-btn"
                            />
                        )}

                        { generateStatus and not isGenerating and
                            <div className="generate-error-box">
                                <p className="generate-error-text">{generateStatus}</p>
                                <Button label="Try Again" onClick={handleGenerate} className="generate-btn" />
                            </div>
                        }
                    </div>
                </Card>
            </div>
        </div>
    );
}
