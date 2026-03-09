"""Juncture - Revise Screen for editing and improving argument nodes."""

# Import UI components
import from .components.ui.button { Button }
import from .components.ui.card { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from .components.ui.textarea { Textarea }
import from .components.ui.label { Label }
import from .components.ui.badge { Badge }
import from .components.ui.alert { Alert, AlertDescription }

# Import icons
import from .components.icons { ArrowLeft, Plus, Check, X, Info }

# Import node types
import from .WelcomeScreen { ArgumentGraph }

# Walker to add evidence to a node
walker AddEvidenceToNode {
    has graphId: str,
        nodeId: str,
        evidenceContent: str;
    
    can add_evidence with `root entry {
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
        
        # Create new evidence node
        evidence_id = f"node_evidence_{str(time.time()).replace('.', '')}";
        new_evidence = {
            "id": evidence_id,
            "type": "EVIDENCE",
            "content": self.evidenceContent,
            "position": {"x": 0, "y": 0}  # Position will be calculated by layout
        };
        
        # Add to graph nodes
        graph_node.nodes.append(new_evidence);
        
        # Create edge from evidence to target node
        new_edge = {
            "id": f"edge_{evidence_id}",
            "source": evidence_id,
            "target": self.nodeId,
            "type": "SUPPORTS"
        };
        
        graph_node.edges.append(new_edge);
        graph_node.updatedAt = str(datetime.now());
        
        report {"success": True, "graph": graph_node};
    }
}

# Walker to add assumption to a node
walker AddAssumptionToNode {
    has graphId: str,
        nodeId: str,
        assumptionContent: str;
    
    can add_assumption with `root entry {
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
        
        # Create new assumption node
        assumption_id = f"node_assumption_{str(time.time()).replace('.', '')}";
        new_assumption = {
            "id": assumption_id,
            "type": "ASSUMPTION",
            "content": self.assumptionContent,
            "position": {"x": 0, "y": 0}
        };
        
        graph_node.nodes.append(new_assumption);
        
        # Create edge
        new_edge = {
            "id": f"edge_{assumption_id}",
            "source": assumption_id,
            "target": self.nodeId,
            "type": "DEPENDS_ON"
        };
        
        graph_node.edges.append(new_edge);
        graph_node.updatedAt = str(datetime.now());
        
        report {"success": True, "graph": graph_node};
    }
}

# Walker to update node content
walker UpdateNodeContent {
    has graphId: str,
        nodeId: str,
        newContent: str;
    
    can update_content with `root entry {
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
        
        # Update node content
        for node in graph_node.nodes {
            if node["id"] == self.nodeId {
                node["content"] = self.newContent;
                break;
            }
        }
        
        graph_node.updatedAt = str(datetime.now());
        
        report {"success": True, "graph": graph_node};
    }
}

# Walker to delete a node
walker DeleteNode {
    has graphId: str,
        nodeId: str;
    
    can delete_node with `root entry {
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
        
        # Remove node
        graph_node.nodes = [n for n in graph_node.nodes if n["id"] != self.nodeId];
        
        # Remove associated edges
        graph_node.edges = [
            e for e in graph_node.edges 
            if e["source"] != self.nodeId and e["target"] != self.nodeId
        ];
        
        graph_node.updatedAt = str(datetime.now());
        
        report {"success": True, "graph": graph_node};
    }
}

# Client-side component
def:pub ReviseScreen -> JsxElement {
    has nodeId: str = "",  # From route params
        graphId: str = "",  # From context
        currentNode: dict = None,
        nodeIssues: list = [],
        actionType: str = None,  # "evidence" | "assumption" | "clarify" | None
        inputValue: str = "",
        showConfirmDelete: bool = False;
    
    # TODO: Get nodeId from route params and graphId from context
    can with entry {
        # nodeId = getRouteParam("nodeId");
        # graphId = getCurrentGraphId();
        
        # Mock data for now
        nodeId = "node_claim_1";
        graphId = "graph_123";
        
        currentNode = {
            "id": "node_claim_1",
            "type": "CLAIM",
            "content": "Remote work increases productivity"
        };
        
        nodeIssues = [
            {
                "id": "issue_1",
                "nodeId": "node_claim_1",
                "description": "This claim lacks supporting evidence",
                "suggestedAction": "Add specific examples or data to support this claim"
            }
        ];
    }
    
    def handleSave() -> None {
        if not inputValue.trim() {
            # TODO: Show error toast
            print("Please enter some content");
            return;
        }
        
        # TODO: Replace with actual walker calls when backend is integrated
        if actionType == "evidence" {
            # walker_result = root spawn AddEvidenceToNode(
            #     graphId=graphId,
            #     nodeId=nodeId,
            #     evidenceContent=inputValue
            # );
            print(f"Adding evidence: {inputValue}");
        } elif actionType == "assumption" {
            # walker_result = root spawn AddAssumptionToNode(
            #     graphId=graphId,
            #     nodeId=nodeId,
            #     assumptionContent=inputValue
            # );
            print(f"Adding assumption: {inputValue}");
        } elif actionType == "clarify" {
            # walker_result = root spawn UpdateNodeContent(
            #     graphId=graphId,
            #     nodeId=nodeId,
            #     newContent=inputValue
            # );
            print(f"Updating content: {inputValue}");
        }
        
        # Reset form
        actionType = None;
        inputValue = "";
        
        # TODO: Show success toast and recalculate score
        # After save, recalculate score using RecalculateScore walker
    }
    
    def handleDelete() -> None {
        # TODO: Replace with actual walker call
        # walker_result = root spawn DeleteNode(
        #     graphId=graphId,
        #     nodeId=nodeId
        # );
        
        print(f"Deleting node: {nodeId}");
        
        # TODO: Navigate back to review screen
        # navigate("/review");
    }
    
    def navigateBack() -> None {
        # TODO: Navigate back to review screen
        # navigate("/review");
        print("Navigate back to review");
    }
    
    nodeColors = {
        "THESIS": "border-purple-400 bg-purple-50",
        "CLAIM": "border-blue-400 bg-blue-50",
        "EVIDENCE": "border-green-400 bg-green-50",
        "ASSUMPTION": "border-yellow-400 bg-yellow-50",
        "COUNTERARGUMENT": "border-red-400 bg-red-50"
    };
    
    nodeIcons = {
        "THESIS": "🎯",
        "CLAIM": "💭",
        "EVIDENCE": "📊",
        "ASSUMPTION": "🔗",
        "COUNTERARGUMENT": "⚠️"
    };
    
    if not currentNode {
        return <div className="flex items-center justify-center h-screen">
            <p>Loading...</p>
        </div>;
    }
    
    return (
        <div className="min-h-screen bg-gray-50">
            <header className="bg-white border-b px-4 py-3">
                <div className="max-w-4xl mx-auto flex items-center gap-4">
                    <Button variant="ghost" size="sm" onClick={navigateBack}>
                        <ArrowLeft className="h-4 w-4 mr-2" />
                        Back to Map
                    </Button>
                    <h1 className="text-xl font-bold">Revise Node</h1>
                </div>
            </header>

            <div className="max-w-4xl mx-auto p-6 space-y-6">
                <Card className={"border-2 " + {nodeColors[currentNode["type"]]}}>
                    <CardHeader>
                        <div className="flex items-center justify-between">
                            <CardTitle className="flex items-center gap-2">
                                <span>{nodeIcons[currentNode["type"]]}</span>
                                {currentNode["type"]}
                            </CardTitle>
                            <Badge variant="outline">{currentNode["id"]}</Badge>
                        </div>
                    </CardHeader>
                    <CardContent>
                        <p className="text-lg">{currentNode["content"]}</p>
                    </CardContent>
                </Card>

                {(
                    <Card>
                        <CardHeader>
                            <CardTitle className="text-sm">Issues Detected</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-2">
                            {nodeIssues.map(lambda issue -> any {
                                return <Alert key={issue["id"]}>
                                    <Info className="h-4 w-4" />
                                    <AlertDescription>
                                        <p className="font-medium">{issue["description"]}</p>
                                        <p className="text-sm text-gray-600 mt-1">
                                            💡 {issue["suggestedAction"]}
                                        </p>
                                    </AlertDescription>
                                </Alert>;
                            })}
                        </CardContent>
                    </Card>
                ) if nodeIssues.length > 0 else None}

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
                                variant={"default" if actionType == "evidence" else "outline"}
                                onClick={lambda -> None { 
                                    actionType = "evidence"; 
                                    inputValue = ""; 
                                }}
                                className="h-auto py-4 flex flex-col items-start"
                            >
                                <span className="font-semibold">📊 Add Evidence</span>
                                <span className="text-xs opacity-80">
                                    Example, stat, or source
                                </span>
                            </Button>

                            <Button
                                variant={"default" if actionType == "assumption" else "outline"}
                                onClick={lambda -> None { 
                                    actionType = "assumption"; 
                                    inputValue = ""; 
                                }}
                                className="h-auto py-4 flex flex-col items-start"
                            >
                                <span className="font-semibold">🔗 Add Assumption</span>
                                <span className="text-xs opacity-80">
                                    Missing logical link
                                </span>
                            </Button>

                            <Button
                                variant={"default" if actionType == "clarify" else "outline"}
                                onClick={lambda -> None { 
                                    actionType = "clarify"; 
                                    inputValue = currentNode["content"]; 
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
                                onClick={lambda -> None { showConfirmDelete = True; }}
                                className="h-auto py-4 flex flex-col items-start border-red-200 text-red-600 hover:bg-red-50"
                            >
                                <span className="font-semibold">🗑️ Delete Node</span>
                                <span className="text-xs opacity-80">
                                    Remove from graph
                                </span>
                            </Button>
                        </div>

                        {(
                            <div className="space-y-4 pt-4 border-t">
                                <div className="space-y-2">
                                    <Label htmlFor="revision-input">
                                        {"Enter your evidence" if actionType == "evidence" else
                                         "State the assumption" if actionType == "assumption" else
                                         "Clarify the wording"}
                                    </Label>
                                    <Textarea
                                        id="revision-input"
                                        value={inputValue}
                                        onChange={lambda e: any -> None { inputValue = e.target.value; }}
                                        placeholder={
                                            "e.g., A 2024 Stanford study found that 87% of remote workers reported higher productivity..."
                                            if actionType == "evidence" else
                                            "e.g., Assumes that reduced commute time is used productively..."
                                            if actionType == "assumption" else
                                            "Enter clearer wording..."
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
                                        onClick={lambda -> None {
                                            actionType = "";
                                            inputValue = "";
                                        }}
                                    >
                                        Cancel
                                    </Button>
                                </div>
                            </div>
                        ) if actionType and actionType != "delete" else None}

                        {(
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
                                            onClick={lambda -> None { showConfirmDelete = False; }}
                                        >
                                            Cancel
                                        </Button>
                                    </div>
                                </AlertDescription>
                            </Alert>
                        ) if showConfirmDelete else None}
                    </CardContent>
                </Card>

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
