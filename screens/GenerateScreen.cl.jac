"""Juncture - Generate Screen for creating argument maps from notes."""

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
        currentUserId: str = "",
        isGuest: bool = False,
        isDragging: bool = False;

    async def loadContext() -> None {
        ctx = await root spawn GetContext();
        if ctx and ctx["currentUser"] {
            currentUserId = ctx["currentUser"]["id"];
            isGuest = ctx["currentUser"]["isGuest"];
        }
    }

    can with entry {
        loadContext();
    }

    async def handleGenerate() -> None {
        if not notes.strip() {
            return;
        }
        isGenerating = True;
        navigate("review");
        isGenerating = False;
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

        file_name = file.name.lower();

        if file_name.endswith(".txt") or file_name.endswith(".md") {
            reader = Reflect.construct(FileReader, []);
            reader.onload = lambda event -> None {
                notes = event.target.result;
            };
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

                        <Button
                            label={(<><Sparkles className="generate-btn-icon" />Generating Argument Map...</>) if isGenerating else (<>Generate Argument Map<ArrowRight className="generate-btn-icon" /></>)}
                            onClick={handleGenerate}
                            disabled={not notes.strip() or isGenerating}
                            className="generate-btn"
                        />
                    </div>
                </Card>

                <Card
                    title="💡 Quick Start Example"
                    className="quickstart-card"
                >
                    <Button label="Load example notes" variant="ghost" onClick={loadExampleNotes} />
                </Card>
            </div>
        </div>
    );
}
