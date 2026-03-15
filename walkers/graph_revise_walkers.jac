"""Walkers for revising argument graph nodes."""

import from graph.argument_graph_nodes { ArgumentGraph }
import from src.graph_generator { evaluate_single_evidence }
import time;
import json;

walker:pub AddEvidenceToNode {
    has graphId: str,
        nodeId: str,
        evidenceContent: str;

    can run with Root entry {
        try {
        graph_node = None;
        for graph in [-->](?:ArgumentGraph) {
            if graph.id == self.graphId {
                graph_node = graph;
                break;
            }
        }

        if not graph_node {
            report {"error": "Graph not found"};
            return;
        }

        evidence_id = f"node_evidence_{int(time.time())}";

        # Find thesis text for evaluation context
        thesis_text = "";
        for tn in graph_node.nodes {
            if tn["type"] == "THESIS" {
                thesis_text = tn.get("content", "");
                break;
            }
        }

        # Evaluate evidence with LLM before creating node
        ev_category = "logical_reasoning";
        ev_assumptions: list = [];
        ev_confidence = 0.5;
        ev_node_score = 50;
        try {
            raw_result = evaluate_single_evidence(
                evidence_text=self.evidenceContent,
                thesis_text=thesis_text,
                context_description=f"This evidence is used to support the thesis: '{thesis_text}'"
            );
            raw_str = str(raw_result).strip();
            if raw_str.startswith("```") {
                fence_lines = raw_str.split("\n");
                fence_lines = fence_lines[1:];
                if fence_lines and fence_lines[-1].strip().startswith("```") {
                    fence_lines = fence_lines[:-1];
                }
                raw_str = "\n".join(fence_lines).strip();
            }
            parsed = json.loads(raw_str);
            ev_category = parsed.get("evidence_category", "logical_reasoning");
            if not ev_category { ev_category = "logical_reasoning"; }
            raw_assumptions = parsed.get("assumptions", []);
            if not isinstance(raw_assumptions, list) { raw_assumptions = []; }
            for a in raw_assumptions {
                a_str = str(a).strip();
                if len(a_str) > 1 {
                    ev_assumptions.append(a_str[0].upper() + a_str[1:]);
                } elif len(a_str) == 1 {
                    ev_assumptions.append(a_str[0].upper());
                }
            }
            try {
                ev_confidence = float(parsed.get("confidence", 0.5));
            } except Exception {
                ev_confidence = 0.5;
            }
            # Compute node score from category weights
            cat_weights: dict[str, float] = {
                "empirical_data": 0.9, "expert_testimony": 0.8,
                "logical_reasoning": 0.6, "analogy": 0.5, "anecdotal": 0.3
            };
            base_quality = cat_weights.get(ev_category, 0.6);
            quality = base_quality - len(ev_assumptions) * 0.15;
            if quality < 0.1 { quality = 0.1; }
            combined = quality * 0.6 + ev_confidence * 0.4;
            ev_node_score = int(combined * 100);
            print(f"=== Evidence evaluated: category={ev_category}, confidence={ev_confidence}, assumptions={len(ev_assumptions)}, nodeScore={ev_node_score} ===");
        } except Exception as eval_err {
            print(f"=== Evidence evaluation failed (using defaults): {eval_err} ===");
        }

        new_evidence = {
            "id": evidence_id,
            "type": "EVIDENCE",
            "content": self.evidenceContent,
            "confidence": ev_confidence,
            "isWeak": ev_confidence < 0.5,
            "issues": [],
            "position": {"x": 0, "y": 0},
            "evidence_category": ev_category,
            "assumptions": ev_assumptions,
            "nodeScore": ev_node_score
        };

        graph_node.nodes.append(new_evidence);

        new_edge = {
            "id": f"edge_{evidence_id}",
            "source": evidence_id,
            "target": self.nodeId,
            "type": "SUPPORTS"
        };

        graph_node.edges.append(new_edge);
        graph_node.updatedAt = str(int(time.time()));

        report {
            "success": True,
            "graph": {
                "id": graph_node.id,
                "nodes": graph_node.nodes,
                "edges": graph_node.edges,
                "createdAt": graph_node.createdAt,
                "updatedAt": graph_node.updatedAt
            }
        };
        } except Exception as e {
            print(f"AddEvidenceToNode ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub AddAssumptionToEvidence {
    has graphId: str,
        nodeId: str,
        assumptionText: str;

    can run with Root entry {
        try {
        graph_node = None;
        for graph in [-->](?:ArgumentGraph) {
            if graph.id == self.graphId {
                graph_node = graph;
                break;
            }
        }

        if not graph_node {
            report {"error": "Graph not found"};
            return;
        }

        for node in graph_node.nodes {
            if node["id"] == self.nodeId {
                existing_assumptions = node.get("assumptions", []);
                if not isinstance(existing_assumptions, list) {
                    existing_assumptions = [];
                }
                existing_assumptions.append(self.assumptionText);
                updated_node = {
                    "id": node["id"],
                    "type": node["type"],
                    "content": node["content"],
                    "position": node["position"],
                    "assumptions": existing_assumptions,
                    "evidence_category": node.get("evidence_category", "")
                };
                idx = graph_node.nodes.index(node);
                graph_node.nodes[idx] = updated_node;
                break;
            }
        }

        graph_node.updatedAt = str(int(time.time()));

        report {
            "success": True,
            "graph": {
                "id": graph_node.id,
                "nodes": graph_node.nodes,
                "edges": graph_node.edges,
                "createdAt": graph_node.createdAt,
                "updatedAt": graph_node.updatedAt
            }
        };
        } except Exception as e {
            print(f"AddAssumptionToEvidence ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub UpdateNodeContent {
    has graphId: str,
        nodeId: str,
        newContent: str;

    can run with Root entry {
        try {
        graph_node = None;
        for graph in [-->](?:ArgumentGraph) {
            if graph.id == self.graphId {
                graph_node = graph;
                break;
            }
        }

        if not graph_node {
            report {"error": "Graph not found"};
            return;
        }

        for node in graph_node.nodes {
            if node["id"] == self.nodeId {
                # Preserve all existing fields, only update content
                updated_node = {
                    "id": node["id"],
                    "type": node["type"],
                    "content": self.newContent,
                    "position": node.get("position", {"x": 0, "y": 0}),
                    "confidence": node.get("confidence", 0.5),
                    "isWeak": node.get("isWeak", False),
                    "issues": node.get("issues", []),
                    "evidence_category": node.get("evidence_category", ""),
                    "assumptions": node.get("assumptions", []),
                    "nodeScore": node.get("nodeScore", 50)
                };
                idx = graph_node.nodes.index(node);
                graph_node.nodes[idx] = updated_node;
                break;
            }
        }

        graph_node.updatedAt = str(int(time.time()));

        report {
            "success": True,
            "graph": {
                "id": graph_node.id,
                "nodes": graph_node.nodes,
                "edges": graph_node.edges,
                "createdAt": graph_node.createdAt,
                "updatedAt": graph_node.updatedAt
            }
        };
        } except Exception as e {
            print(f"UpdateNodeContent ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub DeleteNode {
    has graphId: str,
        nodeId: str;

    can run with Root entry {
        try {
        graph_node = None;
        for graph in [-->](?:ArgumentGraph) {
            if graph.id == self.graphId {
                graph_node = graph;
                break;
            }
        }

        if not graph_node {
            report {"error": "Graph not found"};
            return;
        }

        graph_node.nodes = [n for n in graph_node.nodes if n["id"] != self.nodeId];
        graph_node.edges = [
            e for e in graph_node.edges
            if e["source"] != self.nodeId and e["target"] != self.nodeId
        ];
        graph_node.updatedAt = str(int(time.time()));

        report {
            "success": True,
            "graph": {
                "id": graph_node.id,
                "nodes": graph_node.nodes,
                "edges": graph_node.edges,
                "createdAt": graph_node.createdAt,
                "updatedAt": graph_node.updatedAt
            }
        };
        } except Exception as e {
            print(f"DeleteNode ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub AddCounterargumentNode {
    has graphId: str,
        targetNodeId: str,
        counterargContent: str;

    can run with Root entry {
        try {
        graph_node = None;
        for graph in [-->](?:ArgumentGraph) {
            if graph.id == self.graphId {
                graph_node = graph;
                break;
            }
        }

        if not graph_node {
            report {"error": "Graph not found"};
            return;
        }

        counter_id = f"node_counter_{int(time.time())}";
        new_counter = {
            "id": counter_id,
            "type": "COUNTERARGUMENT",
            "content": self.counterargContent,
            "confidence": 0.5,
            "isWeak": False,
            "issues": [],
            "position": {"x": 0, "y": 0},
            "evidence_category": "",
            "assumptions": [],
            "nodeScore": 50
        };

        graph_node.nodes.append(new_counter);

        new_edge = {
            "id": f"edge_{counter_id}",
            "source": counter_id,
            "target": self.targetNodeId,
            "type": "CONTRADICTS"
        };

        graph_node.edges.append(new_edge);
        graph_node.updatedAt = str(int(time.time()));

        report {
            "success": True,
            "graph": {
                "id": graph_node.id,
                "nodes": graph_node.nodes,
                "edges": graph_node.edges,
                "createdAt": graph_node.createdAt,
                "updatedAt": graph_node.updatedAt
            }
        };
        } except Exception as e {
            print(f"AddCounterargumentNode ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub AddAddressEdge {
    has graphId: str,
        defendNodeId: str,
        counterargNodeId: str,
        addressContent: str;

    can run with Root entry {
        try {
        graph_node = None;
        for graph in [-->](?:ArgumentGraph) {
            if graph.id == self.graphId {
                graph_node = graph;
                break;
            }
        }

        if not graph_node {
            report {"error": "Graph not found"};
            return;
        }

        evidence_id = f"node_address_{int(time.time())}";
        new_evidence = {
            "id": evidence_id,
            "type": "EVIDENCE",
            "content": self.addressContent,
            "confidence": 0.5,
            "isWeak": False,
            "issues": [],
            "position": {"x": 0, "y": 0},
            "evidence_category": "logical_reasoning",
            "assumptions": [],
            "nodeScore": 50
        };

        graph_node.nodes.append(new_evidence);

        support_edge = {
            "id": f"edge_sup_{evidence_id}",
            "source": evidence_id,
            "target": self.defendNodeId,
            "type": "SUPPORTS"
        };

        address_edge = {
            "id": f"edge_adr_{evidence_id}",
            "source": evidence_id,
            "target": self.counterargNodeId,
            "type": "ADDRESSES"
        };

        graph_node.edges.append(support_edge);
        graph_node.edges.append(address_edge);
        graph_node.updatedAt = str(int(time.time()));

        report {
            "success": True,
            "graph": {
                "id": graph_node.id,
                "nodes": graph_node.nodes,
                "edges": graph_node.edges,
                "createdAt": graph_node.createdAt,
                "updatedAt": graph_node.updatedAt
            }
        };
        } except Exception as e {
            print(f"AddAddressEdge ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub EvaluateNewNode {
    has graphId: str,
        nodeId: str;

    can run with Root entry {
        try {
        print(f"=== EvaluateNewNode: graphId={self.graphId}, nodeId={self.nodeId} ===");
        graph_node = None;
        for graph in [-->](?:ArgumentGraph) {
            if graph.id == self.graphId {
                graph_node = graph;
                break;
            }
        }

        if not graph_node {
            report {"error": "Graph not found"};
            return;
        }

        # Find the target node and the thesis
        target_node = None;
        thesis_text = "";
        for n in graph_node.nodes {
            if n["id"] == self.nodeId {
                target_node = n;
            }
            if n["type"] == "THESIS" {
                thesis_text = n.get("content", "");
            }
        }

        if not target_node {
            report {"error": "Node not found"};
            return;
        }

        node_content = target_node.get("content", "");
        node_type = target_node.get("type", "EVIDENCE");

        # Only evaluate EVIDENCE nodes with LLM
        if node_type == "EVIDENCE" {
            # Build context
            context = f"This evidence is used to support the thesis: '{thesis_text}'";

            # Call LLM to evaluate
            raw_result = evaluate_single_evidence(
                evidence_text=node_content,
                thesis_text=thesis_text,
                context_description=context
            );

            # Parse LLM response
            parsed = {};
            try {
                raw_str = str(raw_result).strip();
                # Handle markdown fences
                if raw_str.startswith("```") {
                    fence_lines = raw_str.split("\n");
                    fence_lines = fence_lines[1:];
                    if fence_lines and fence_lines[-1].strip().startswith("```") {
                        fence_lines = fence_lines[:-1];
                    }
                    raw_str = "\n".join(fence_lines).strip();
                }
                parsed = json.loads(raw_str);
            } except Exception {
                parsed = {};
            }

            print(f"=== LLM evaluation result: {parsed} ===");

            # Extract evaluation results
            ev_category = parsed.get("evidence_category", "logical_reasoning");
            ev_assumptions = parsed.get("assumptions", []);
            ev_confidence = 0.5;
            try {
                ev_confidence = float(parsed.get("confidence", 0.5));
            } except Exception {
                ev_confidence = 0.5;
            }

            if not isinstance(ev_assumptions, list) {
                ev_assumptions = [];
            }

            # Capitalize assumptions
            capped_assumptions: list = [];
            for a in ev_assumptions {
                a_str = str(a).strip();
                if len(a_str) > 1 {
                    capped_assumptions.append(a_str[0].upper() + a_str[1:]);
                } elif len(a_str) == 1 {
                    capped_assumptions.append(a_str[0].upper());
                } else {
                    capped_assumptions.append(a_str);
                }
            }

            # Category quality weights
            cat_weights: dict[str, float] = {
                "empirical_data": 0.9, "expert_testimony": 0.8,
                "logical_reasoning": 0.6, "analogy": 0.5, "anecdotal": 0.3
            };
            base_quality = cat_weights.get(ev_category, 0.6);
            quality = base_quality - len(capped_assumptions) * 0.15;
            if quality < 0.1 { quality = 0.1; }
            node_score = int(quality * 100);

            # Update the node in the graph
            updated_node = {
                "id": target_node["id"],
                "type": target_node["type"],
                "content": target_node.get("content", ""),
                "position": target_node.get("position", {"x": 0, "y": 0}),
                "confidence": ev_confidence,
                "isWeak": ev_confidence < 0.5,
                "issues": target_node.get("issues", []),
                "evidence_category": ev_category,
                "assumptions": capped_assumptions,
                "nodeScore": node_score
            };

            # Replace node in graph
            new_nodes: list = [];
            for n in graph_node.nodes {
                if n["id"] == self.nodeId {
                    new_nodes.append(updated_node);
                } else {
                    new_nodes.append(n);
                }
            }
            graph_node.nodes = new_nodes;
            graph_node.updatedAt = str(int(time.time()));

            report {
                "success": True,
                "evaluatedNode": updated_node,
                "graph": {
                    "id": graph_node.id,
                    "nodes": graph_node.nodes,
                    "edges": graph_node.edges,
                    "createdAt": graph_node.createdAt,
                    "updatedAt": graph_node.updatedAt
                }
            };
        } else {
            # For non-evidence nodes, just report back without changes
            report {"success": True, "evaluatedNode": target_node};
        }
        } except Exception as e {
            print(f"EvaluateNewNode ERROR: {e}");
            report {"error": str(e)};
        }
    }
}
