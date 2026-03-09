"""Juncture - Review Screen for visualizing and analyzing argument maps."""

# Import ReactFlow for graph visualization
import from "reactflow" { 
    ReactFlow, 
    Background, 
    Controls, 
    MiniMap, 
    useNodesState, 
    useEdgesState 
}
import "reactflow/dist/style.css"

# Import UI components
import from .components.ui.button { Button }
import from .components.ui.card { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from .components.ui.badge { Badge }
import from .components.ui.progress { Progress }

# Import custom components
import from .components.ArgumentNode { ArgumentNodeComponent }

# Import icons
import from .components.icons { ArrowLeft, FileText, AlertTriangle, TrendingUp, ChevronRight }

# Import node types
import from .WelcomeScreen { ArgumentGraph }

# Walker to get current graph with scoring
walker GetGraphWithScoring {
    has graphId: str;
    
    can fetch_graph with `root entry {
        # Find graph node
        graph_node = None;
        for graph in -->`root[?ArgumentGraph] {
            if graph.id == self.graphId {
                graph_node = graph;
                break;
            }
        }
        
        if not graph_node {
            report {"error": "Graph not found"};
            return;
        }
        
        # Calculate current score
        # TODO: Replace with actual AI-powered scoring when integrated
        score = self.calculate_score(graph_node);
        issues = self.identify_issues(graph_node);
        
        report {
            "graph": graph_node,
            "score": score,
            "issues": issues
        };
    }
    
    can calculate_score(graph: ArgumentGraph) -> dict {
        # MOCK SCORING - Replace with actual reasoning analysis
        # Real implementation should analyze argument strength
        nodes = graph.nodes;
        edges = graph.edges;
        
        claims = [n for n in nodes if n["type"] == "CLAIM"];
        evidence = [n for n in nodes if n["type"] == "EVIDENCE"];
        
        # Simple mock calculation
        support_score = min(100, len(evidence) * 30);
        premise_score = min(100, len(claims) * 25);
        consistency_score = 80;  # Mock value
        
        overall = (support_score * 0.4 + premise_score * 0.4 + consistency_score * 0.2);
        
        return {
            "overall": int(overall),
            "support": support_score,
            "premise": premise_score,
            "consistency": consistency_score,
            "unsupportedClaims": max(0, len(claims) - len(evidence)),
            "unresolvedContradictions": 0
        };
    }
    
    can identify_issues(graph: ArgumentGraph) -> list {
        # MOCK ISSUE DETECTION - Replace with actual analysis
        issues = [];
        
        nodes = graph.nodes;
        edges = graph.edges;
        
        claims = [n for n in nodes if n["type"] == "CLAIM"];
        
        for claim in claims {
            # Check if claim has supporting evidence
            supporting_edges = [e for e in edges if e["target"] == claim["id"] and e["type"] == "SUPPORTS"];
            
            if len(supporting_edges) == 0 {
                issues.append({
                    "id": f"issue_{claim['id']}",
                    "nodeId": claim["id"],
                    "severity": "high",
                    "type": "unsupported_claim",
                    "description": "This claim lacks supporting evidence",
                    "suggestedAction": "Add evidence or examples to support this claim"
                });
            }
        }
        
        return issues[:3];  # Return top 3 issues
    }
}

# Walker to update graph score after revisions
walker RecalculateScore {
    has graphId: str;
    
    can recalculate with `root entry {
        # Find graph and recalculate
        walker_result = visit --> GetGraphWithScoring(graphId=self.graphId);
        report walker_result.reports[0] if walker_result.reports else None;
    }
}

# Client-side component
def:pub ReviewScreen -> JsxElement {
    has currentGraph: dict = None,  # Graph data from walker
        currentScore: dict = None,   # Score data
        currentIssues: list = [],    # Issues list
        selectedNodeId: str = None;
    
    # TODO: Fetch graph data on mount when routing/context is implemented
    can with entry {
        # graphId = getGraphIdFromRoute();
        # walker_result = root spawn GetGraphWithScoring(graphId=graphId);
        # data = walker_result.reports[0];
        # currentGraph = data["graph"];
        # currentScore = data["score"];
        # currentIssues = data["issues"];
        
        # For now, use mock data
        currentGraph = {
            "nodes": [
                {
                    "id": "node_thesis",
                    "type": "THESIS",
                    "content": "Remote work increases overall productivity",
                    "position": {"x": 250, "y": 50}
                },
                {
                    "id": "node_claim_1",
                    "type": "CLAIM",
                    "content": "Eliminates commute time waste",
                    "position": {"x": 100, "y": 200}
                },
                {
                    "id": "node_claim_2",
                    "type": "CLAIM",
                    "content": "Reduces office distractions",
                    "position": {"x": 400, "y": 200}
                }
            ],
            "edges": [
                {
                    "id": "edge_1",
                    "source": "node_claim_1",
                    "target": "node_thesis",
                    "type": "SUPPORTS"
                }
            ]
        };
        
        currentScore = {
            "overall": 65,
            "support": 60,
            "premise": 70,
            "consistency": 65,
            "unsupportedClaims": 1,
            "unresolvedContradictions": 0
        };
        
        currentIssues = [
            {
                "id": "issue_1",
                "nodeId": "node_claim_2",
                "severity": "high",
                "description": "This claim lacks supporting evidence",
                "suggestedAction": "Add evidence or data to support this claim"
            }
        ];
    }
    
    def getScoreColor(score: int) -> str {
        if score >= 75 {
            return "text-green-600";
        }
        if score >= 50 {
            return "text-yellow-600";
        }
        return "text-red-600";
    }
    
    def handleNodeClick(event: any, node: any) -> None {
        # TODO: Navigate to revise screen with node ID
        # navigate(f"/revise/{node.id}");
        print(f"Navigate to revise node: {node.id}");
    }
    
    def handleIssueClick(nodeId: str) -> None {
        # TODO: Navigate to revise screen
        # navigate(f"/revise/{nodeId}");
        print(f"Navigate to fix issue for node: {nodeId}");
    }
    
    def navigateBack() -> None {
        # TODO: Navigate back to generate screen
        # navigate("/generate");
        print("Navigate back to generate");
    }
    
    def navigateToExport() -> None {
        # TODO: Navigate to export screen
        # navigate("/export");
        print("Navigate to export");
    }
    
    # Prepare nodes for ReactFlow
    def prepareFlowNodes() -> list {
        if not currentGraph {
            return [];
        }
        
        return [
            {
                "id": node["id"],
                "type": "argumentNode",
                "position": node["position"],
                "data": {"node": node}
            }
            for node in currentGraph["nodes"]
        ];
    }
    
    # Prepare edges for ReactFlow
    def prepareFlowEdges() -> list {
        if not currentGraph {
            return [];
        }
        
        def getEdgeStyle(edgeType: str) -> dict {
            if edgeType == "SUPPORTS" {
                return {"stroke": "#10b981", "strokeWidth": 2};
            } elif edgeType == "CONTRADICTS" {
                return {"stroke": "#ef4444", "strokeWidth": 2, "strokeDasharray": "5,5"};
            } elif edgeType == "DEPENDS_ON" {
                return {"stroke": "#f59e0b", "strokeWidth": 2, "strokeDasharray": "3,3"};
            } elif edgeType == "ADDRESSES" {
                return {"stroke": "#8b5cf6", "strokeWidth": 2};
            } else {
                return {"stroke": "#6b7280", "strokeWidth": 2};
            }
        }
        
        return [
            {
                "id": edge["id"],
                "source": edge["source"],
                "target": edge["target"],
                "label": edge["type"],
                "style": getEdgeStyle(edge["type"]),
                "animated": edge["type"] == "CONTRADICTS",
                "labelBgStyle": {"fill": "#fff", "fillOpacity": 0.9},
                "labelStyle": {"fontSize": 10, "fontWeight": 600}
            }
            for edge in currentGraph["edges"]
        ];
    }
    
    nodes = prepareFlowNodes();
    edges = prepareFlowEdges();
    
    nodeTypes = {"argumentNode": ArgumentNodeComponent};
    
    topIssues = currentIssues[:3] if currentIssues else [];
    
    if not currentGraph or not currentScore {
        return <div className="flex items-center justify-center h-screen">
            <p>Loading...</p>
        </div>;
    }
    
    return (
        <div className="h-screen flex flex-col bg-gray-50">
            <header className="bg-white border-b px-4 py-3 flex items-center justify-between">
                <div className="flex items-center gap-4">
                    <Button variant="ghost" size="sm" onClick={navigateBack}>
                        <ArrowLeft className="h-4 w-4 mr-2" />
                        Back
                    </Button>
                    <h1 className="text-xl font-bold">Argument Map</h1>
                </div>
                <div className="flex items-center gap-2">
                    <Button variant="outline" size="sm" onClick={navigateToExport}>
                        <FileText className="h-4 w-4 mr-2" />
                        Export
                    </Button>
                </div>
            </header>

            <div className="flex-1 flex overflow-hidden">
                <div className="flex-1 relative">
                    <ReactFlow
                        nodes={nodes}
                        edges={edges}
                        nodeTypes={nodeTypes}
                        fitView={True}
                        minZoom={0.5}
                        maxZoom={1.5}
                        onNodeClick={handleNodeClick}
                    >
                        <Background />
                        <Controls />
                        <MiniMap
                            nodeColor={lambda node: any -> str {
                                nodeData = node.data.node;
                                colors = {
                                    "THESIS": "#c084fc",
                                    "CLAIM": "#60a5fa",
                                    "EVIDENCE": "#34d399",
                                    "ASSUMPTION": "#fbbf24",
                                    "COUNTERARGUMENT": "#f87171"
                                };
                                return colors.get(nodeData["type"], "#9ca3af");
                            }}
                        />
                    </ReactFlow>
                </div>

                <div className="w-96 bg-white border-l flex flex-col overflow-hidden">
                    <div className="p-4 border-b flex-shrink-0">
                        <h2 className="font-semibold flex items-center gap-2">
                            <TrendingUp className="h-5 w-5 text-indigo-600" />
                            Reasoning Score
                        </h2>
                    </div>

                    <div className="flex-1 overflow-y-auto">
                        <div className="p-4 space-y-6">
                            <Card>
                                <CardContent className="pt-6">
                                    <div className="text-center space-y-2">
                                        <div className={"text-5xl font-bold " + {getScoreColor(currentScore["overall"])}}>
                                            {currentScore["overall"]}
                                        </div>
                                        <p className="text-sm text-gray-600">out of 100</p>
                                        <Progress value={currentScore["overall"]} className="h-2" />
                                    </div>
                                </CardContent>
                            </Card>

                            <Card>
                                <CardHeader>
                                    <CardTitle className="text-sm">Score Breakdown</CardTitle>
                                </CardHeader>
                                <CardContent className="space-y-3">
                                    <div className="flex items-center justify-between">
                                        <span className="text-sm">Support Coverage (40%)</span>
                                        <Badge variant="outline">{currentScore["support"]}%</Badge>
                                    </div>
                                    <Progress value={currentScore["support"]} className="h-1.5" />

                                    <div className="flex items-center justify-between">
                                        <span className="text-sm">Premise Coverage (40%)</span>
                                        <Badge variant="outline">{currentScore["premise"]}%</Badge>
                                    </div>
                                    <Progress value={currentScore["premise"]} className="h-1.5" />

                                    <div className="flex items-center justify-between">
                                        <span className="text-sm">Consistency (20%)</span>
                                        <Badge variant="outline">{currentScore["consistency"]}%</Badge>
                                    </div>
                                    <Progress value={currentScore["consistency"]} className="h-1.5" />
                                </CardContent>
                            </Card>

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
                                    {(
                                        <p className="text-sm text-gray-500 text-center py-4">
                                            No major issues found! 🎉
                                        </p>
                                    ) if topIssues.length == 0 else (
                                        topIssues.map(lambda issue, index -> any {
                                            return <div
                                                key={issue["id"]}
                                                onClick={lambda -> None { handleIssueClick(issue["nodeId"]); }}
                                                className="p-3 border rounded-lg hover:bg-gray-50 cursor-pointer transition-colors"
                                            >
                                                <div className="flex items-start justify-between gap-2">
                                                    <div className="flex-1">
                                                        <div className="flex items-center gap-2 mb-1">
                                                            <Badge
                                                                variant={
                                                                    "destructive" if issue["severity"] == "high"
                                                                    else "default" if issue["severity"] == "medium"
                                                                    else "secondary"
                                                                }
                                                                className="text-xs"
                                                            >
                                                                {issue["severity"]}
                                                            </Badge>
                                                            <span className="text-xs text-gray-500">
                                                                Issue #{index + 1}
                                                            </span>
                                                        </div>
                                                        <p className="text-sm font-medium">{issue["description"]}</p>
                                                    </div>
                                                    <ChevronRight className="h-4 w-4 text-gray-400 flex-shrink-0" />
                                                </div>
                                            </div>;
                                        })
                                    )}
                                </CardContent>
                            </Card>

                            <Card>
                                <CardHeader>
                                    <CardTitle className="text-sm">Start Here</CardTitle>
                                    <CardDescription>
                                        Recommended next steps in order
                                    </CardDescription>
                                </CardHeader>
                                <CardContent className="space-y-3">
                                    {(
                                        <p className="text-sm text-gray-500 text-center py-2">
                                            Great work! Ready to export.
                                        </p>
                                    ) if topIssues.length == 0 else (
                                        topIssues.map(lambda issue, index -> any {
                                            return <div key={issue["id"]} className="flex items-start gap-3">
                                                <div className="flex-shrink-0 w-6 h-6 rounded-full bg-indigo-100 text-indigo-600 flex items-center justify-center text-xs font-bold">
                                                    {index + 1}
                                                </div>
                                                <div className="flex-1">
                                                    <p className="text-sm">{issue["suggestedAction"]}</p>
                                                    <Button
                                                        variant="link"
                                                        size="sm"
                                                        className="h-auto p-0 text-xs"
                                                        onClick={lambda -> None { handleIssueClick(issue["nodeId"]); }}
                                                    >
                                                        Fix now →
                                                    </Button>
                                                </div>
                                            </div>;
                                        })
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
