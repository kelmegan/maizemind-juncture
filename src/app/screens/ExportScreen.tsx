import { useState } from "react";
import { useNavigate } from "react-router";
import { useApp } from "../store/AppContext";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../components/ui/card";
import { Alert, AlertDescription } from "../components/ui/alert";
import { Badge } from "../components/ui/badge";
import { ArrowLeft, Download, FileText, AlertTriangle, CheckCircle2, Copy } from "lucide-react";
import { jsPDF } from "jspdf";
import { toast } from "sonner";

export function ExportScreen() {
  const navigate = useNavigate();
  const { currentGraph, currentScore, currentIssues, addSession, setCurrentSessionId } = useApp();
  const [exportFormat, setExportFormat] = useState<"text" | "pdf">("text");

  if (!currentGraph || !currentScore) {
    navigate("/review");
    return null;
  }

  const generateOutlineText = (includeFlags: boolean = true) => {
    const thesis = currentGraph.nodes.find((n) => n.type === "THESIS");
    const claims = currentGraph.nodes.filter((n) => n.type === "CLAIM");
    const evidence = currentGraph.nodes.filter((n) => n.type === "EVIDENCE");

    let outline = "ARGUMENT OUTLINE\n";
    outline += "=".repeat(50) + "\n\n";

    if (thesis) {
      outline += `THESIS:\n${thesis.content}\n\n`;
    }

    outline += "MAIN CLAIMS:\n";
    claims.forEach((claim, index) => {
      const claimEvidence = currentGraph.edges
        .filter((e) => e.target === claim.id && e.type === "SUPPORTS")
        .map((e) => evidence.find((ev) => ev.id === e.source))
        .filter(Boolean);

      const hasIssues = currentIssues.some((i) => i.nodeId === claim.id);

      outline += `\n${index + 1}. ${claim.content}`;
      if (includeFlags && hasIssues) {
        outline += " (⚠️ Needs evidence)";
      }
      outline += "\n";

      if (claimEvidence.length > 0) {
        outline += "   Supporting Evidence:\n";
        claimEvidence.forEach((ev) => {
          outline += `   • ${ev?.content}\n`;
        });
      }
    });

    outline += "\n" + "=".repeat(50) + "\n";
    outline += `Reasoning Score: ${currentScore.overall}/100\n`;

    if (includeFlags && currentIssues.length > 0) {
      outline += `\n⚠️ ${currentIssues.length} issue${currentIssues.length > 1 ? "s" : ""} detected\n`;
    }

    return outline;
  };

  const handleExportText = () => {
    const outline = generateOutlineText(currentScore.overall < 75);
    navigator.clipboard.writeText(outline);
    toast.success("Outline copied to clipboard!");
  };

  const handleExportPDF = () => {
    const doc = new jsPDF();
    const outline = generateOutlineText(currentScore.overall < 75);
    const lines = doc.splitTextToSize(outline, 180);

    let y = 20;
    lines.forEach((line: string) => {
      if (y > 280) {
        doc.addPage();
        y = 20;
      }
      doc.text(line, 15, y);
      y += 7;
    });

    doc.save("argument-outline.pdf");
    toast.success("PDF downloaded successfully!");
  };

  const handleSaveSession = () => {
    const session = {
      id: `session-${Date.now()}`,
      date: new Date().toISOString(),
      title: currentGraph.nodes.find((n) => n.type === "THESIS")?.content.slice(0, 50) || "Untitled",
      initialScore: currentScore.overall,
      finalScore: currentScore.overall,
      graph: currentGraph,
      notes: "",
    };

    addSession(session);
    setCurrentSessionId(session.id);
    toast.success("Session saved to history!");
  };

  const showWarning = currentScore.overall < 75;
  const unsupportedCount = currentScore.unsupportedClaims;
  const contradictionCount = currentScore.unresolvedContradictions;

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b px-4 py-3">
        <div className="max-w-4xl mx-auto flex items-center gap-4">
          <Button variant="ghost" size="sm" onClick={() => navigate("/review")}>
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back to Map
          </Button>
          <h1 className="text-xl font-bold">Export Outline</h1>
        </div>
      </header>

      <div className="max-w-4xl mx-auto p-6 space-y-6">
        {/* Score Summary */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              <span>Final Score</span>
              <Badge
                variant={currentScore.overall >= 75 ? "default" : "destructive"}
                className="text-lg px-4 py-1"
              >
                {currentScore.overall}/100
              </Badge>
            </CardTitle>
            <CardDescription>
              {currentScore.overall >= 75
                ? "Your argument is well-structured and ready to export!"
                : "Your argument could be improved before exporting."}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-3 gap-4">
              <div className="text-center p-3 bg-gray-50 rounded-lg">
                <div className="text-2xl font-bold text-gray-900">
                  {currentScore.support}%
                </div>
                <div className="text-xs text-gray-600">Support</div>
              </div>
              <div className="text-center p-3 bg-gray-50 rounded-lg">
                <div className="text-2xl font-bold text-gray-900">
                  {currentScore.premise}%
                </div>
                <div className="text-xs text-gray-600">Premise</div>
              </div>
              <div className="text-center p-3 bg-gray-50 rounded-lg">
                <div className="text-2xl font-bold text-gray-900">
                  {currentScore.consistency}%
                </div>
                <div className="text-xs text-gray-600">Consistency</div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Warning Banner */}
        {showWarning && (
          <Alert className="border-amber-200 bg-amber-50">
            <AlertTriangle className="h-4 w-4 text-amber-600" />
            <AlertDescription>
              <p className="font-medium text-amber-900 mb-2">
                Your outline will export now, but we found some issues:
              </p>
              <ul className="text-sm space-y-1 text-amber-800">
                {unsupportedCount > 0 && (
                  <li>• {unsupportedCount} claim{unsupportedCount > 1 ? "s are" : " is"} unsupported</li>
                )}
                {contradictionCount > 0 && (
                  <li>• {contradictionCount} unresolved contradiction{contradictionCount > 1 ? "s" : ""}</li>
                )}
              </ul>
              <div className="mt-3">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => navigate("/review")}
                  className="border-amber-300 hover:bg-amber-100"
                >
                  Fix Top 3 Issues First
                </Button>
              </div>
            </AlertDescription>
          </Alert>
        )}

        {!showWarning && (
          <Alert className="border-green-200 bg-green-50">
            <CheckCircle2 className="h-4 w-4 text-green-600" />
            <AlertDescription className="text-green-900">
              <p className="font-medium">
                Great work! Your argument is well-structured and ready to export.
              </p>
            </AlertDescription>
          </Alert>
        )}

        {/* Preview */}
        <Card>
          <CardHeader>
            <CardTitle>Outline Preview</CardTitle>
            <CardDescription>
              This is what will be exported
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="bg-gray-50 rounded-lg p-4 font-mono text-sm whitespace-pre-wrap max-h-[400px] overflow-y-auto border">
              {generateOutlineText(showWarning)}
            </div>
          </CardContent>
        </Card>

        {/* Export Options */}
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

        {/* Next Steps */}
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
          <Button variant="outline" onClick={() => navigate("/generate")} className="flex-1">
            Start New Argument
          </Button>
          <Button variant="outline" onClick={() => navigate("/profile")} className="flex-1">
            View Profile
          </Button>
        </div>
      </div>
    </div>
  );
}
