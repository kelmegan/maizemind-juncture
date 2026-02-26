import { useState } from "react";
import { useNavigate } from "react-router";
import { Button } from "../components/ui/button";
import { Textarea } from "../components/ui/textarea";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../components/ui/card";
import { useApp } from "../store/AppContext";
import { generateMockGraph } from "../utils/mockGenerator";
import { calculateReasoningScore, identifyIssues } from "../utils/scoring";
import { Upload, Sparkles, ArrowRight, User } from "lucide-react";
import { Label } from "../components/ui/label";

export function GenerateScreen() {
  const navigate = useNavigate();
  const {
    setCurrentGraph,
    setCurrentNotes,
    setCurrentScore,
    setCurrentIssues,
    setCurrentSessionId,
    isGuest,
  } = useApp();

  const [notes, setNotes] = useState("");
  const [isGenerating, setIsGenerating] = useState(false);

  const handleGenerate = () => {
    if (!notes.trim()) return;

    setIsGenerating(true);

    // Simulate AI processing
    setTimeout(() => {
      const graph = generateMockGraph(notes);
      const score = calculateReasoningScore(graph);
      const issues = identifyIssues(graph);

      setCurrentGraph(graph);
      setCurrentNotes(notes);
      setCurrentScore(score);
      setCurrentIssues(issues);
      setCurrentSessionId(`session-${Date.now()}`);

      setIsGenerating(false);
      navigate("/review");
    }, 2000);
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-bold bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent">
              Juncture
            </h1>
          </div>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => navigate("/profile")}
          >
            <User className="h-4 w-4 mr-2" />
            {isGuest ? "Guest" : "Profile"}
          </Button>
        </div>
      </header>

      {/* Main Content */}
      <div className="max-w-4xl mx-auto p-6 space-y-6">
        <div className="text-center space-y-2">
          <h2 className="text-3xl font-bold">Transform Your Notes</h2>
          <p className="text-gray-600">
            Paste your messy notes below and we'll create an argument map with instant feedback
          </p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Sparkles className="h-5 w-5 text-indigo-600" />
              Your Notes
            </CardTitle>
            <CardDescription>
              Paste your research notes, brainstorming, or draft arguments. The messier, the better!
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="notes">Notes</Label>
              <Textarea
                id="notes"
                placeholder="Example: Remote work has benefits and drawbacks. People save time commuting (about an hour per day on average). They have more flexibility for work-life balance. But some studies show isolation can be an issue. Companies save money on office space. Productivity might increase because fewer distractions..."
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                className="min-h-[300px] resize-none"
              />
            </div>

            <div className="border-2 border-dashed rounded-lg p-8 text-center space-y-2 bg-gray-50 hover:bg-gray-100 transition-colors cursor-pointer">
              <Upload className="h-8 w-8 mx-auto text-gray-400" />
              <div className="text-sm text-gray-600">
                <span className="font-medium text-indigo-600">Upload documents</span> or drag and drop
              </div>
              <p className="text-xs text-gray-500">
                PDF, DOCX, TXT up to 10MB
              </p>
            </div>

            <Button
              onClick={handleGenerate}
              disabled={!notes.trim() || isGenerating}
              className="w-full"
              size="lg"
            >
              {isGenerating ? (
                <>
                  <Sparkles className="h-4 w-4 mr-2 animate-spin" />
                  Generating Argument Map...
                </>
              ) : (
                <>
                  Generate Argument Map
                  <ArrowRight className="h-4 w-4 ml-2" />
                </>
              )}
            </Button>
          </CardContent>
        </Card>

        {/* Example Notes */}
        <Card className="bg-indigo-50 border-indigo-200">
          <CardHeader>
            <CardTitle className="text-sm">💡 Quick Start Example</CardTitle>
          </CardHeader>
          <CardContent>
            <Button
              variant="ghost"
              size="sm"
              onClick={() =>
                setNotes(
                  "Remote work increases productivity and employee satisfaction. Employees save time without commuting - the average commute is 54 minutes daily. Flexible schedules improve work-life balance. Remote work reduces office distractions. However, remote workers report feeling isolated which could impact morale. Companies also save money on office space costs."
                )
              }
            >
              Load example notes
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
