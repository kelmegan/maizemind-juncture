"""Juncture - Generate Screen for creating argument maps from notes."""

# Import UI components
import from .components.ui.button { Button }
import from .components.ui.textarea { Textarea }
import from .components.ui.card { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from .components.ui.label { Label }

# Import icons
import from .components.icons { Upload, Sparkles, ArrowRight, User }

# Import node types and walkers
import from .WelcomeScreen { User, Session, ArgumentGraph }

# Walker to generate argument graph from notes
# TODO: Replace mock implementation with actual AI-powered graph generation
walker GenerateArgumentGraph {
    has notes: str,
        userId: str;
    
    can generate_graph with `root entry {
        # MOCK IMPLEMENTATION - Replace with AI integration later
        # This should call an AI service to analyze notes and create:
        # - Thesis identification
        # - Claim extraction
        # - Evidence mapping
        # - Logical relationship detection
        
        graph_id = f"graph_{str(time.time()).replace('.', '')}";
        
        # Mock graph structure - simplified version
        mock_nodes = [
            {
                "id": "node_thesis",
                "type": "THESIS",
                "content": "Main thesis extracted from notes",
                "position": {"x": 250, "y": 50}
            },
            {
                "id": "node_claim_1",
                "type": "CLAIM",
                "content": "First major claim",
                "position": {"x": 100, "y": 200}
            },
            {
                "id": "node_claim_2",
                "type": "CLAIM",
                "content": "Second major claim",
                "position": {"x": 400, "y": 200}
            },
            {
                "id": "node_evidence_1",
                "type": "EVIDENCE",
                "content": "Supporting evidence for claim 1",
                "position": {"x": 100, "y": 350}
            }
        ];
        
        mock_edges = [
            {
                "id": "edge_1",
                "source": "node_claim_1",
                "target": "node_thesis",
                "type": "SUPPORTS"
            },
            {
                "id": "edge_2",
                "source": "node_claim_2",
                "target": "node_thesis",
                "type": "SUPPORTS"
            },
            {
                "id": "edge_3",
                "source": "node_evidence_1",
                "target": "node_claim_1",
                "type": "SUPPORTS"
            }
        ];
        
        # Create graph node
        new_graph = ArgumentGraph(
            id=graph_id,
            nodes=mock_nodes,
            edges=mock_edges,
            createdAt=str(datetime.now()),
            updatedAt=str(datetime.now())
        );
        
        # Connect to root
        `root ++> new_graph;
        
        report {
            "graph": new_graph,
            "score": self.calculate_mock_score(mock_nodes, mock_edges),
            "issues": self.identify_mock_issues(mock_nodes, mock_edges)
        };
    }
    
    can calculate_mock_score(nodes: list, edges: list) -> dict {
        # MOCK SCORING - Replace with actual reasoning analysis
        # Real implementation should analyze:
        # - Claim support coverage
        # - Premise identification
        # - Logical consistency
        # - Evidence quality
        
        return {
            "overall": 65,
            "support": 60,
            "premise": 70,
            "consistency": 65,
            "unsupportedClaims": 1,
            "unresolvedContradictions": 0
        };
    }
    
    can identify_mock_issues(nodes: list, edges: list) -> list {
        # MOCK ISSUE DETECTION - Replace with actual analysis
        # Real implementation should detect:
        # - Unsupported claims
        # - Missing assumptions
        # - Contradictions
        # - Weak evidence
        
        return [
            {
                "id": "issue_1",
                "nodeId": "node_claim_2",
                "severity": "high",
                "type": "unsupported_claim",
                "description": "This claim lacks supporting evidence",
                "suggestedAction": "Add evidence or data to support this claim"
            }
        ];
    }
}

# Walker to create a new session
walker CreateSession {
    has userId: str,
        notes: str,
        graphId: str,
        score: dict;
    
    can create_session with `root entry {
        # Find user node
        user_node = None;
        for user in -->`root[?User] {
            if user.id == self.userId {
                user_node = user;
                break;
            }
        }
        
        if not user_node {
            report {"error": "User not found"};
            return;
        }
        
        # Find graph node
        graph_node = None;
        for graph in -->`root[?ArgumentGraph] {
            if graph.id == self.graphId {
                graph_node = graph;
                break;
            }
        }
        
        # Create session
        new_session = Session(
            id=f"session_{str(time.time()).replace('.', '')}",
            date=str(datetime.now()),
            title=self.notes[:50] + "..." if len(self.notes) > 50 else self.notes,
            initialScore=self.score["overall"],
            finalScore=self.score["overall"],
            notes=self.notes
        );
        
        # Connect session to user and graph
        user_node ++> new_session;
        if graph_node {
            new_session ++> graph_node;
        }
        
        report new_session;
    }
}

# Client-side component
def:pub GenerateScreen -> JsxElement {
    has notes: str = "",
        isGenerating: bool = False,
        currentUserId: str = "",  # Set from parent/context
        isGuest: bool = False;  # Set from parent/context
    
    # TODO: Get user info from global state/context when implemented
    can with entry {
        # currentUserId = getCurrentUser().id;
        # isGuest = getCurrentUser().isGuest;
    }
    
    async def handleGenerate() -> None {
        if not notes.trim() {
            return;
        }
        
        isGenerating = True;
        
        # Simulate AI processing delay
        # TODO: Replace with actual walker call when backend is integrated
        # walker_result = root spawn GenerateArgumentGraph(
        #     notes=notes,
        #     userId=currentUserId
        # );
        # 
        # graph_data = walker_result.reports[0];
        # 
        # # Create session
        # session_result = root spawn CreateSession(
        #     userId=currentUserId,
        #     notes=notes,
        #     graphId=graph_data["graph"].id,
        #     score=graph_data["score"]
        # );
        
        # Mock delay for demo
        await new Promise(lambda resolve -> None {
            setTimeout(resolve, 2000);
        });
        
        isGenerating = False;
        
        # TODO: Navigate to review screen with generated graph
        # navigate("/review");
        
        print("Graph generated successfully");
    }
    
    def loadExampleNotes() -> None {
        notes = "Remote work increases productivity and employee satisfaction. Employees save time without commuting - the average commute is 54 minutes daily. Flexible schedules improve work-life balance. Remote work reduces office distractions. However, remote workers report feeling isolated which could impact morale. Companies also save money on office space costs.";
    }
    
    def handleFileUpload(e: any) -> None {
        # TODO: Implement file upload processing
        # Should handle PDF, DOCX, TXT files
        # Extract text and populate notes field
        print("File upload not yet implemented");
    }
    
    def navigateToProfile() -> None {
        # TODO: Add navigation when routing is implemented
        # navigate("/profile");
        print("Navigate to profile");
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
                        variant="ghost"
                        size="sm"
                        onClick={navigateToProfile}
                    >
                        <User className="h-4 w-4 mr-2" />
                        {"Guest" if isGuest else "Profile"}
                    </Button>
                </div>
            </header>

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
                                onChange={lambda e: any -> None { notes = e.target.value; }}
                                className="min-h-[300px] resize-none"
                            />
                        </div>

                        <div 
                            className="border-2 border-dashed rounded-lg p-8 text-center space-y-2 bg-gray-50 hover:bg-gray-100 transition-colors cursor-pointer"
                            onClick={handleFileUpload}
                        >
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
                            disabled={not notes.trim() or isGenerating}
                            className="w-full"
                            size="lg"
                        >
                            {(
                                <>
                                    <Sparkles className="h-4 w-4 mr-2 animate-spin" />
                                    Generating Argument Map...
                                </>
                            ) if isGenerating else (
                                <>
                                    Generate Argument Map
                                    <ArrowRight className="h-4 w-4 ml-2" />
                                </>
                            )}
                        </Button>
                    </CardContent>
                </Card>

                <Card className="bg-indigo-50 border-indigo-200">
                    <CardHeader>
                        <CardTitle className="text-sm">💡 Quick Start Example</CardTitle>
                    </CardHeader>
                    <CardContent>
                        <Button
                            variant="ghost"
                            size="sm"
                            onClick={loadExampleNotes}
                        >
                            Load example notes
                        </Button>
                    </CardContent>
                </Card>
            </div>
        </div>
    );
}
