import { useEffect, useMemo, useCallback, useState } from "react";
import { useNavigate } from "react-router";
import ReactFlow, {
  Node,
  Edge,
  Background,
  Controls,
  MiniMap,
  useNodesState,
  useEdgesState,
} from "reactflow";
import "reactflow/dist/style.css";
import { useApp } from "../store/AppContext";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../components/ui/card";
import { Badge } from "../components/ui/badge";
import { Progress } from "../components/ui/progress";
import { ArgumentNodeComponent } from "../components/ArgumentNode";
import { ArrowLeft, FileText, AlertTriangle, TrendingUp, ChevronRight } from "lucide-react";

const nodeTypes = {
  argumentNode: ArgumentNodeComponent,
};

export function ReviewScreen() {
  const navigate = useNavigate();
  const { currentGraph, currentScore, currentIssues } = useApp();
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);

  useEffect(() => {
    if (!currentGraph) {
      navigate("/generate");
    }
  }, [currentGraph, navigate]);

  const handleNodeClick = useCallback((nodeId: string) => {
    setSelectedNodeId(nodeId);
  }, []);

  const onNodeClick = useCallback((event: React.MouseEvent, node: Node) => {
    navigate(`/revise/${node.id}`);
  }, [navigate]);

  const initialNodes: Node[] = useMemo(() => {
    if (!currentGraph) return [];

    return currentGraph.nodes.map((node) => ({
      id: node.id,
      type: "argumentNode",
      position: node.position || { x: 0, y: 0 },
      data: {
        node,
      },
    }));
  }, [currentGraph]);

  const initialEdges: Edge[] = useMemo(() => {
    if (!currentGraph) return [];

    return currentGraph.edges.map((edge) => {
      const getEdgeStyle = () => {
        switch (edge.type) {
          case "SUPPORTS":
            return { stroke: "#10b981", strokeWidth: 2 };
          case "CONTRADICTS":
            return { stroke: "#ef4444", strokeWidth: 2, strokeDasharray: "5,5" };
          case "DEPENDS_ON":
            return { stroke: "#f59e0b", strokeWidth: 2, strokeDasharray: "3,3" };
          case "ADDRESSES":
            return { stroke: "#8b5cf6", strokeWidth: 2 };
          default:
            return { stroke: "#6b7280", strokeWidth: 2 };
        }
      };

      return {
        id: edge.id,
        source: edge.source,
        target: edge.target,
        label: edge.type,
        style: getEdgeStyle(),
        animated: edge.type === "CONTRADICTS",
        labelBgStyle: { fill: "#fff", fillOpacity: 0.9 },
        labelStyle: { fontSize: 10, fontWeight: 600 },
      };
    });
  }, [currentGraph]);

  const [nodes] = useNodesState(initialNodes);
  const [edges] = useEdgesState(initialEdges);

  if (!currentGraph || !currentScore) {
    return null;
  }

  const topIssues = currentIssues.slice(0, 3);
  const nextActions = topIssues.map((issue, index) => ({
    step: index + 1,
    action: issue.suggestedAction,
    nodeId: issue.nodeId,
  }));

  const getScoreColor = (score: number) => {
    if (score >= 75) return "text-green-600";
    if (score >= 50) return "text-yellow-600";
    return "text-red-600";
  };

  const handleIssueClick = (nodeId: string) => {
    navigate(`/revise/${nodeId}`);
  };

  return (
    <div className="h-screen flex flex-col bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="sm" onClick={() => navigate("/generate")}>
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back
          </Button>
          <h1 className="text-xl font-bold">Argument Map</h1>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={() => navigate("/export")}>
            <FileText className="h-4 w-4 mr-2" />
            Export
          </Button>
        </div>
      </header>

      <div className="flex-1 flex overflow-hidden">
        {/* Graph Area */}
        <div className="flex-1 relative">
          <ReactFlow
            nodes={nodes}
            edges={edges}
            nodeTypes={nodeTypes}
            fitView
            minZoom={0.5}
            maxZoom={1.5}
            onNodeClick={onNodeClick}
          >
            <Background />
            <Controls />
            <MiniMap
              nodeColor={(node) => {
                const data = node.data as { node: { type: string } };
                const colors = {
                  THESIS: "#c084fc",
                  CLAIM: "#60a5fa",
                  EVIDENCE: "#34d399",
                  ASSUMPTION: "#fbbf24",
                  COUNTERARGUMENT: "#f87171",
                };
                return colors[data.node.type as keyof typeof colors] || "#9ca3af";
              }}
            />
          </ReactFlow>
        </div>

        {/* Critique Panel */}
        <div className="w-96 bg-white border-l flex flex-col overflow-hidden">
          <div className="p-4 border-b flex-shrink-0">
            <h2 className="font-semibold flex items-center gap-2">
              <TrendingUp className="h-5 w-5 text-indigo-600" />
              Reasoning Score
            </h2>
          </div>

          <div className="flex-1 overflow-y-auto">
            <div className="p-4 space-y-6">
              {/* Overall Score */}
              <Card>
                <CardContent className="pt-6">
                  <div className="text-center space-y-2">
                    <div className={`text-5xl font-bold ${getScoreColor(currentScore.overall)}`}>
                      {currentScore.overall}
                    </div>
                    <p className="text-sm text-gray-600">out of 100</p>
                    <Progress value={currentScore.overall} className="h-2" />
                  </div>
                </CardContent>
              </Card>

              {/* Score Breakdown */}
              <Card>
                <CardHeader>
                  <CardTitle className="text-sm">Score Breakdown</CardTitle>
                </CardHeader>
                <CardContent className="space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-sm">Support Coverage (40%)</span>
                    <Badge variant="outline">{currentScore.support}%</Badge>
                  </div>
                  <Progress value={currentScore.support} className="h-1.5" />

                  <div className="flex items-center justify-between">
                    <span className="text-sm">Premise Coverage (40%)</span>
                    <Badge variant="outline">{currentScore.premise}%</Badge>
                  </div>
                  <Progress value={currentScore.premise} className="h-1.5" />

                  <div className="flex items-center justify-between">
                    <span className="text-sm">Consistency (20%)</span>
                    <Badge variant="outline">{currentScore.consistency}%</Badge>
                  </div>
                  <Progress value={currentScore.consistency} className="h-1.5" />
                </CardContent>
              </Card>

              {/* Top Issues */}
              <Card>
                <CardHeader>
                  <CardTitle className="text-sm flex items-center gap-2">
                    <AlertTriangle className="h-4 w-4 text-amber-500" />
                    Top 3 Issues
                  </CardTitle>
                  <CardDescription>
                    Click on an issue to fix it
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-2">
                  {topIssues.length === 0 ? (
                    <p className="text-sm text-gray-500 text-center py-4">
                      No major issues found! 🎉
                    </p>
                  ) : (
                    topIssues.map((issue, index) => (
                      <div
                        key={issue.id}
                        onClick={() => handleIssueClick(issue.nodeId)}
                        className="p-3 border rounded-lg hover:bg-gray-50 cursor-pointer transition-colors"
                      >
                        <div className="flex items-start justify-between gap-2">
                          <div className="flex-1">
                            <div className="flex items-center gap-2 mb-1">
                              <Badge
                                variant={
                                  issue.severity === "high"
                                    ? "destructive"
                                    : issue.severity === "medium"
                                    ? "default"
                                    : "secondary"
                                }
                                className="text-xs"
                              >
                                {issue.severity}
                              </Badge>
                              <span className="text-xs text-gray-500">
                                Issue #{index + 1}
                              </span>
                            </div>
                            <p className="text-sm font-medium">{issue.description}</p>
                          </div>
                          <ChevronRight className="h-4 w-4 text-gray-400 flex-shrink-0" />
                        </div>
                      </div>
                    ))
                  )}
                </CardContent>
              </Card>

              {/* Next Actions */}
              <Card>
                <CardHeader>
                  <CardTitle className="text-sm">Start Here</CardTitle>
                  <CardDescription>
                    Recommended next steps in order
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-3">
                  {nextActions.map((action) => (
                    <div key={action.step} className="flex items-start gap-3">
                      <div className="flex-shrink-0 w-6 h-6 rounded-full bg-indigo-100 text-indigo-600 flex items-center justify-center text-xs font-bold">
                        {action.step}
                      </div>
                      <div className="flex-1">
                        <p className="text-sm">{action.action}</p>
                        <Button
                          variant="link"
                          size="sm"
                          className="h-auto p-0 text-xs"
                          onClick={() => handleIssueClick(action.nodeId)}
                        >
                          Fix now →
                        </Button>
                      </div>
                    </div>
                  ))}

                  {nextActions.length === 0 && (
                    <p className="text-sm text-gray-500 text-center py-2">
                      Great work! Ready to export.
                    </p>
                  )}
                </CardContent>
              </Card>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}