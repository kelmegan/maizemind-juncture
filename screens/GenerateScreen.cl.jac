"""Juncture - Generate Screen for creating argument maps from notes."""

import from "lucide-react" { Upload, Sparkles, ArrowRight, User }
import from "pdfjs-dist" { getDocument, GlobalWorkerOptions }
import from "mammoth" { extractRawText }

import from ..components.Button { Button }
import from ..components.Card { Card }

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

    def navigateToProfile() -> None {
        navigate("profile");
    }

    def handleNotesChange(e: any) -> None {
        notes = e.target.value;
    }

    return (
        <div className="min-h-screen bg-gray-50">
            <header className="bg-white border-b sticky top-0 z-10">
                <div className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
                    <div className="flex items-center gap-2">
                        <h1 className="text-2xl font-bold bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent">
                            Juncture
                        </h1>
                    </div>
                    <Button
                        label={(<><User className="h-4 w-4 mr-2" />{"Guest" if isGuest else "Profile"}</>)}
                        variant="ghost"
                        size="sm"
                        onClick={navigateToProfile}
                    />
                </div>
            </header>

            <div className="max-w-4xl mx-auto p-6 space-y-6">
                <div className="text-center space-y-2">
                    <h2 className="text-3xl font-bold">Transform Your Notes</h2>
                    <p className="text-gray-600">
                        Paste your messy notes below and we'll create an argument map with instant feedback
                    </p>
                </div>

                <Card
                    title={<><Sparkles className="h-5 w-5 text-indigo-600" />Your Notes</>}
                    description="Paste your research notes, brainstorming, or draft arguments. The messier, the better!"
                >
                    <div className="space-y-4">
                        <div className="space-y-2">
                            <label htmlFor="notes">Notes</label>
                            <textarea
                                id="notes"
                                placeholder="Example: Remote work has benefits and drawbacks. People save time commuting (about an hour per day on average). They have more flexibility for work-life balance. But some studies show isolation can be an issue. Companies save money on office space. Productivity might increase because fewer distractions..."
                                value={notes}
                                onChange={handleNotesChange}
                                className="min-h-[300px] resize-none"
                            />
                        </div>

                        <input
                            id="file-input"
                            type="file"
                            accept=".txt,.md,.pdf,.docx"
                            className="hidden"
                            onChange={handleFileUpload}
                        />
                        <div
                            className="border-2 border-dashed rounded-lg p-8 text-center space-y-2 bg-gray-50 hover:bg-gray-100 transition-colors cursor-pointer"
                            onClick={handleDivClick}
                        >
                            <Upload className="h-8 w-8 mx-auto text-gray-400" />
                            <div className="text-sm text-gray-600">
                                <span className="font-medium text-indigo-600">Upload documents</span> or drag and drop
                            </div>
                            <p className="text-xs text-gray-500">TXT, MD, PDF, DOCX up to 10MB</p>
</div>

                        <Button
                            label={(<><Sparkles className="h-4 w-4 mr-2 animate-spin" />Generating Argument Map...</>) if isGenerating else (<>Generate Argument Map<ArrowRight className="h-4 w-4 ml-2" /></>)}
                            onClick={handleGenerate}
                            disabled={not notes.strip() or isGenerating}
                            className="w-full"
                            size="lg"
                        />
                    </div>
                </Card>

                <Card
                    title="💡 Quick Start Example"
                    className="bg-indigo-50 border-indigo-200"
                >
                    <Button label="Load example notes" variant="ghost" size="sm" onClick={loadExampleNotes} />
                </Card>
            </div>
        </div>
    );
}