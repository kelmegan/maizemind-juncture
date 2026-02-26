import { useState, useEffect } from "react";
import { useNavigate, useParams } from "react-router";
import { useApp } from "../store/AppContext";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../components/ui/card";
import { Textarea } from "../components/ui/textarea";
import { Label } from "../components/ui/label";
import { Badge } from "../components/ui/badge";
import {
  addEvidenceToNode,
  addAssumptionToNode,
  updateNodeContent,
  deleteNode,
} from "../utils/mockGenerator";
import { calculateReasoningScore, identifyIssues } from "../utils/scoring";
import { ArrowLeft, Plus, Check, X, Info } from "lucide-react";
import { toast } from "sonner";
import { Alert, AlertDescription } from "../components/ui/alert";

export function ReviseScreen() {
  const navigate = useNavigate();
  const { nodeId } = useParams<{ nodeId: string }>();
  const { currentGraph, setCurrentGraph, setCurrentScore, setCurrentIssues } =
    useApp();

  const [actionType, setActionType] = useState<
    "evidence" | "assumption" | "clarify" | null
  >(null);
  const [inputValue, setInputValue] = useState("");
  const [showConfirmDelete, setShowConfirmDelete] = useState(false);

  const node = currentGraph?.nodes.find((n) => n.id === nodeId);
  const nodeIssues = currentGraph
    ? identifyIssues(currentGraph).filter((i) => i.nodeId === nodeId)
    : [];

  useEffect(() => {
    if (!currentGraph || !node) {
      navigate("/review");
    }
  }, [currentGraph, node, navigate]);

  if (!currentGraph || !node) {
    return null;
  }

  const handleSave = () => {
    if (!inputValue.trim()) {
      toast.error("Please enter some content");
      return;
    }

    let updatedGraph = currentGraph;

    switch (actionType) {
      case "evidence":
        updatedGraph = addEvidenceToNode(currentGraph, nodeId!, inputValue);
        toast.success("Evidence added successfully");
        break;
      case "assumption":
        updatedGraph = addAssumptionToNode(currentGraph, nodeId!, inputValue);
        toast.success("Assumption added successfully");
        break;
      case "clarify":
        updatedGraph = updateNodeContent(currentGraph, nodeId!, inputValue);
        toast.success("Content updated successfully");
        break;
    }

    // Update graph and recalculate score
    setCurrentGraph(updatedGraph);
    const newScore = calculateReasoningScore(updatedGraph);
    const newIssues = identifyIssues(updatedGraph);
    setCurrentScore(newScore);
    setCurrentIssues(newIssues);

    // Reset form
    setActionType(null);
    setInputValue("");

    // Show score improvement
    toast.success(`Score updated! Check the review screen.`);
  };

  const handleDelete = () => {
    const updatedGraph = deleteNode(currentGraph, nodeId!);
    setCurrentGraph(updatedGraph);

    const newScore = calculateReasoningScore(updatedGraph);
    const newIssues = identifyIssues(updatedGraph);
    setCurrentScore(newScore);
    setCurrentIssues(newIssues);

    toast.success("Node deleted successfully");
    navigate("/review");
  };

  const nodeColors = {
    THESIS: "border-purple-400 bg-purple-50",
    CLAIM: "border-blue-400 bg-blue-50",
    EVIDENCE: "border-green-400 bg-green-50",
    ASSUMPTION: "border-yellow-400 bg-yellow-50",
    COUNTERARGUMENT: "border-red-400 bg-red-50",
  };

  const nodeIcons = {
    THESIS: "🎯",
    CLAIM: "💭",
    EVIDENCE: "📊",
    ASSUMPTION: "🔗",
    COUNTERARGUMENT: "⚠️",
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b px-4 py-3">
        <div className="max-w-4xl mx-auto flex items-center gap-4">
          <Button variant="ghost" size="sm" onClick={() => navigate("/review")}>
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back to Map
          </Button>
          <h1 className="text-xl font-bold">Revise Node</h1>
        </div>
      </header>

      <div className="max-w-4xl mx-auto p-6 space-y-6">
        {/* Current Node */}
        <Card className={`border-2 ${nodeColors[node.type]}`}>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="flex items-center gap-2">
                <span>{nodeIcons[node.type]}</span>
                {node.type}
              </CardTitle>
              <Badge variant="outline">{node.id}</Badge>
            </div>
          </CardHeader>
          <CardContent>
            <p className="text-lg">{node.content}</p>
          </CardContent>
        </Card>

        {/* Issues */}
        {nodeIssues.length > 0 && (
          <Card>
            <CardHeader>
              <CardTitle className="text-sm">Issues Detected</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              {nodeIssues.map((issue) => (
                <Alert key={issue.id}>
                  <Info className="h-4 w-4" />
                  <AlertDescription>
                    <p className="font-medium">{issue.description}</p>
                    <p className="text-sm text-gray-600 mt-1">
                      💡 {issue.suggestedAction}
                    </p>
                  </AlertDescription>
                </Alert>
              ))}
            </CardContent>
          </Card>
        )}

        {/* Actions */}
        <Card>
          <CardHeader>
            <CardTitle>Choose an Action</CardTitle>
            <CardDescription>
              Select what you'd like to do with this node
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <Button
                variant={actionType === "evidence" ? "default" : "outline"}
                onClick={() => {
                  setActionType("evidence");
                  setInputValue("");
                }}
                className="h-auto py-4 flex flex-col items-start"
              >
                <span className="font-semibold">📊 Add Evidence</span>
                <span className="text-xs opacity-80">
                  Example, stat, or source
                </span>
              </Button>

              <Button
                variant={actionType === "assumption" ? "default" : "outline"}
                onClick={() => {
                  setActionType("assumption");
                  setInputValue("");
                }}
                className="h-auto py-4 flex flex-col items-start"
              >
                <span className="font-semibold">🔗 Add Assumption</span>
                <span className="text-xs opacity-80">
                  Missing logical link
                </span>
              </Button>

              <Button
                variant={actionType === "clarify" ? "default" : "outline"}
                onClick={() => {
                  setActionType("clarify");
                  setInputValue(node.content);
                }}
                className="h-auto py-4 flex flex-col items-start"
              >
                <span className="font-semibold">✏️ Clarify Wording</span>
                <span className="text-xs opacity-80">
                  Rewrite for clarity
                </span>
              </Button>

              <Button
                variant="outline"
                onClick={() => setShowConfirmDelete(true)}
                className="h-auto py-4 flex flex-col items-start border-red-200 text-red-600 hover:bg-red-50"
              >
                <span className="font-semibold">🗑️ Delete Node</span>
                <span className="text-xs opacity-80">
                  Remove from graph
                </span>
              </Button>
            </div>

            {/* Input Area */}
            {actionType && actionType !== "delete" && (
              <div className="space-y-4 pt-4 border-t">
                <div className="space-y-2">
                  <Label htmlFor="revision-input">
                    {actionType === "evidence" && "Enter your evidence"}
                    {actionType === "assumption" && "State the assumption"}
                    {actionType === "clarify" && "Clarify the wording"}
                  </Label>
                  <Textarea
                    id="revision-input"
                    value={inputValue}
                    onChange={(e) => setInputValue(e.target.value)}
                    placeholder={
                      actionType === "evidence"
                        ? "e.g., A 2024 Stanford study found that 87% of remote workers reported higher productivity..."
                        : actionType === "assumption"
                        ? "e.g., Assumes that reduced commute time is used productively..."
                        : "Enter clearer wording..."
                    }
                    className="min-h-[120px]"
                  />
                </div>

                <div className="flex gap-2">
                  <Button onClick={handleSave} className="flex-1">
                    <Check className="h-4 w-4 mr-2" />
                    Save Changes
                  </Button>
                  <Button
                    variant="outline"
                    onClick={() => {
                      setActionType(null);
                      setInputValue("");
                    }}
                  >
                    Cancel
                  </Button>
                </div>
              </div>
            )}

            {/* Delete Confirmation */}
            {showConfirmDelete && (
              <Alert className="border-red-200 bg-red-50">
                <AlertDescription>
                  <p className="font-medium text-red-900 mb-3">
                    Are you sure you want to delete this node? This action
                    cannot be undone.
                  </p>
                  <div className="flex gap-2">
                    <Button
                      variant="destructive"
                      size="sm"
                      onClick={handleDelete}
                    >
                      <X className="h-4 w-4 mr-2" />
                      Yes, Delete
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setShowConfirmDelete(false)}
                    >
                      Cancel
                    </Button>
                  </div>
                </AlertDescription>
              </Alert>
            )}
          </CardContent>
        </Card>

        {/* Further Reading */}
        <Card className="bg-indigo-50 border-indigo-200">
          <CardHeader>
            <CardTitle className="text-sm">💡 Tips for Strong Arguments</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm">
            <p>
              <strong>Evidence:</strong> Use specific examples, statistics, or
              citations from credible sources.
            </p>
            <p>
              <strong>Assumptions:</strong> Make implicit logic explicit. State
              the "because" that connects ideas.
            </p>
            <p>
              <strong>Clarity:</strong> Be precise. Avoid vague terms like
              "some," "many," or "better."
            </p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
