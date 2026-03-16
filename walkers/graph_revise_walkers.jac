"""Walkers for revising argument graph nodes."""

import from graph.argument_graph_nodes { ArgumentGraph }
import from src.graph_generator { evaluate_single_evidence, generate_counterargument, clarify_node_content, extract_llm_text, categorize_evidence_fast, expand_branch, extract_search_keywords, pick_best_wiki_result }
import from walkers.graph_generate_walkers { GetGraphWithScoring }
import time;
import json;
import urllib.request;
import urllib.parse;

walker:pub AddEvidenceToNode {
    has graphId: str,
        nodeId: str,
        evidenceContent: str,
        sourceUrl: str = "";

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

        # Capitalize first letter of evidence content
        ev_content = self.evidenceContent.strip();
        if len(ev_content) > 1 {
            ev_content = ev_content[0].upper() + ev_content[1:];
        } elif len(ev_content) == 1 {
            ev_content = ev_content[0].upper();
        }

        # Fast keyword-based categorization (no LLM call = instant)
        cat_result = categorize_evidence_fast(ev_content);
        ev_category = cat_result.get("evidence_category", "logical_reasoning");
        ev_assumptions: list = cat_result.get("assumptions", []);
        ev_confidence = cat_result.get("confidence", 0.6);
        ev_node_score = cat_result.get("nodeScore", 50);
        print(f"=== Evidence categorized (fast): category={ev_category}, confidence={ev_confidence}, nodeScore={ev_node_score} ===");

        # Compute position below target node, offset to avoid overlap
        target_pos_x = 0.0;
        target_pos_y = 0.0;
        sibling_count = 0;
        for tn in graph_node.nodes {
            if tn["id"] == self.nodeId {
                tp = tn.get("position", {"x": 0, "y": 0});
                target_pos_x = float(tp.get("x", 0));
                target_pos_y = float(tp.get("y", 0));
            }
        }
        # Count existing children of this node for horizontal offset
        for te in graph_node.edges {
            if te.get("target") == self.nodeId and te.get("type") == "SUPPORTS" {
                sibling_count = sibling_count + 1;
            }
        }
        new_x = target_pos_x + (sibling_count - 1) * 250.0;
        new_y = target_pos_y + 130.0;

        # Prepare source URL
        ev_source = self.sourceUrl.strip() if self.sourceUrl else "";

        new_evidence = {
            "id": evidence_id,
            "type": "EVIDENCE",
            "content": ev_content,
            "confidence": ev_confidence,
            "isWeak": ev_confidence < 0.5,
            "issues": [],
            "llmIssueTypes": [],
            "position": {"x": new_x, "y": new_y},
            "evidence_category": ev_category,
            "assumptions": ev_assumptions,
            "nodeScore": ev_node_score,
            "sourceUrl": ev_source
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

        # Return full scored result so client needs only 1 await
        scored = root spawn GetGraphWithScoring(graphId=self.graphId);
        scored_data = scored.reports[0] if scored.reports else {};
        report {
            "success": True,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
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
                    "evidence_category": node.get("evidence_category", ""),
                    "confidence": node.get("confidence", 0.5),
                    "isWeak": node.get("isWeak", False),
                    "issues": node.get("issues", []),
                    "llmIssueTypes": node.get("llmIssueTypes", []),
                    "nodeScore": node.get("nodeScore", 50),
                    "sourceUrl": node.get("sourceUrl", ""),
                    "moreInfo": node.get("moreInfo", ""),
                    "acknowledged": node.get("acknowledged", False)
                };
                idx = graph_node.nodes.index(node);
                graph_node.nodes[idx] = updated_node;
                break;
            }
        }

        graph_node.updatedAt = str(int(time.time()));

        # Return full scored result so client needs only 1 await
        scored = root spawn GetGraphWithScoring(graphId=self.graphId);
        scored_data = scored.reports[0] if scored.reports else {};
        report {
            "success": True,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
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

        # Capitalize first letter of new content
        new_text = self.newContent.strip();
        if len(new_text) > 1 {
            new_text = new_text[0].upper() + new_text[1:];
        } elif len(new_text) == 1 {
            new_text = new_text[0].upper();
        }

        for node in graph_node.nodes {
            if node["id"] == self.nodeId {
                # Preserve all existing fields, only update content
                updated_node = {
                    "id": node["id"],
                    "type": node["type"],
                    "content": new_text,
                    "position": node.get("position", {"x": 0, "y": 0}),
                    "confidence": node.get("confidence", 0.5),
                    "isWeak": node.get("isWeak", False),
                    "issues": node.get("issues", []),
                    "llmIssueTypes": node.get("llmIssueTypes", []),
                    "evidence_category": node.get("evidence_category", ""),
                    "assumptions": node.get("assumptions", []),
                    "nodeScore": node.get("nodeScore", 50),
                    "sourceUrl": node.get("sourceUrl", ""),
                    "moreInfo": node.get("moreInfo", ""),
                    "acknowledged": node.get("acknowledged", False)
                };
                idx = graph_node.nodes.index(node);
                graph_node.nodes[idx] = updated_node;
                break;
            }
        }

        graph_node.updatedAt = str(int(time.time()));

        # Return full scored result so client needs only 1 await
        scored = root spawn GetGraphWithScoring(graphId=self.graphId);
        scored_data = scored.reports[0] if scored.reports else {};
        report {
            "success": True,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
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

        # Return full scored result so client needs only 1 await
        scored = root spawn GetGraphWithScoring(graphId=self.graphId);
        scored_data = scored.reports[0] if scored.reports else {};
        report {
            "success": True,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
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

        # Capitalize first letter of counterargument content
        ca_content = self.counterargContent.strip();
        if len(ca_content) > 1 {
            ca_content = ca_content[0].upper() + ca_content[1:];
        } elif len(ca_content) == 1 {
            ca_content = ca_content[0].upper();
        }

        # Compute position to the right of target node
        target_pos_x = 0.0;
        target_pos_y = 0.0;
        contra_count = 0;
        for tn in graph_node.nodes {
            if tn["id"] == self.targetNodeId {
                tp = tn.get("position", {"x": 0, "y": 0});
                target_pos_x = float(tp.get("x", 0));
                target_pos_y = float(tp.get("y", 0));
            }
        }
        # Count existing contradicts edges to this node for offset
        for te in graph_node.edges {
            if te.get("target") == self.targetNodeId and te.get("type") == "CONTRADICTS" {
                contra_count = contra_count + 1;
            }
        }
        new_x = target_pos_x + 280.0 + (contra_count - 1) * 250.0;
        new_y = target_pos_y + 60.0;

        new_counter = {
            "id": counter_id,
            "type": "COUNTERARGUMENT",
            "content": ca_content,
            "confidence": 0.5,
            "isWeak": False,
            "issues": [],
            "llmIssueTypes": [],
            "position": {"x": new_x, "y": new_y},
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

        # Return full scored result so client needs only 1 await
        scored = root spawn GetGraphWithScoring(graphId=self.graphId);
        scored_data = scored.reports[0] if scored.reports else {};
        report {
            "success": True,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
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

        # Compute position between the defended node and counterarg
        defend_x = 0.0;
        defend_y = 0.0;
        counter_x = 0.0;
        counter_y = 0.0;
        for tn in graph_node.nodes {
            if tn["id"] == self.defendNodeId {
                tp = tn.get("position", {"x": 0, "y": 0});
                defend_x = float(tp.get("x", 0));
                defend_y = float(tp.get("y", 0));
            }
            if tn["id"] == self.counterargNodeId {
                tp = tn.get("position", {"x": 0, "y": 0});
                counter_x = float(tp.get("x", 0));
                counter_y = float(tp.get("y", 0));
            }
        }
        new_x = (defend_x + counter_x) / 2.0;
        new_y = max(defend_y, counter_y) + 130.0;

        new_evidence = {
            "id": evidence_id,
            "type": "EVIDENCE",
            "content": self.addressContent,
            "confidence": 0.5,
            "isWeak": False,
            "issues": [],
            "llmIssueTypes": [],
            "position": {"x": new_x, "y": new_y},
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

        # Return full scored result so client needs only 1 await
        scored = root spawn GetGraphWithScoring(graphId=self.graphId);
        scored_data = scored.reports[0] if scored.reports else {};
        report {
            "success": True,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
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
                raw_str = extract_llm_text(raw_result).strip();
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
                "llmIssueTypes": target_node.get("llmIssueTypes", []),
                "evidence_category": ev_category,
                "assumptions": capped_assumptions,
                "nodeScore": node_score,
                "sourceUrl": target_node.get("sourceUrl", ""),
                "moreInfo": target_node.get("moreInfo", ""),
                "acknowledged": target_node.get("acknowledged", False)
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


walker:pub GenerateCounter {
    has graphId: str,
        targetNodeId: str;

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

        # Find target node and thesis
        target_content = "";
        thesis_text = "";
        for n in graph_node.nodes {
            if n["id"] == self.targetNodeId {
                target_content = n.get("content", "");
            }
            if n["type"] == "THESIS" {
                thesis_text = n.get("content", "");
            }
        }

        if not target_content {
            report {"error": "Target node not found"};
            return;
        }

        # Call LLM to generate counterargument
        raw_result = generate_counterargument(
            claim_text=target_content,
            thesis_text=thesis_text
        );
        raw_str = extract_llm_text(raw_result).strip();
        if raw_str.startswith("```") {
            fence_lines = raw_str.split("\n");
            fence_lines = fence_lines[1:];
            if fence_lines and fence_lines[-1].strip().startswith("```") {
                fence_lines = fence_lines[:-1];
            }
            raw_str = "\n".join(fence_lines).strip();
        }
        parsed = json.loads(raw_str);
        ca_text = parsed.get("counterargument", "");

        if not ca_text {
            report {"error": "LLM returned empty counterargument"};
            return;
        }

        # Capitalize
        if len(ca_text) > 1 {
            ca_text = ca_text[0].upper() + ca_text[1:];
        } elif len(ca_text) == 1 {
            ca_text = ca_text[0].upper();
        }

        counter_id = f"node_counter_{int(time.time())}";

        # Position to the right of target
        target_pos_x = 0.0;
        target_pos_y = 0.0;
        contra_count = 0;
        for tn in graph_node.nodes {
            if tn["id"] == self.targetNodeId {
                tp = tn.get("position", {"x": 0, "y": 0});
                target_pos_x = float(tp.get("x", 0));
                target_pos_y = float(tp.get("y", 0));
            }
        }
        for te in graph_node.edges {
            if te.get("target") == self.targetNodeId and te.get("type") == "CONTRADICTS" {
                contra_count = contra_count + 1;
            }
        }
        new_x = target_pos_x + 280.0 + contra_count * 250.0;
        new_y = target_pos_y + 60.0;

        new_counter = {
            "id": counter_id,
            "type": "COUNTERARGUMENT",
            "content": ca_text,
            "confidence": 0.5,
            "isWeak": False,
            "issues": [],
            "llmIssueTypes": [],
            "position": {"x": new_x, "y": new_y},
            "evidence_category": "",
            "assumptions": [],
            "nodeScore": 50
        };

        graph_node.nodes.append(new_counter);
        graph_node.edges.append({
            "id": f"edge_{counter_id}",
            "source": counter_id,
            "target": self.targetNodeId,
            "type": "CONTRADICTS"
        });
        graph_node.updatedAt = str(int(time.time()));

        # Return full scored result so client needs only 1 await
        scored = root spawn GetGraphWithScoring(graphId=self.graphId);
        scored_data = scored.reports[0] if scored.reports else {};
        report {
            "success": True,
            "generatedText": ca_text,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"GenerateCounter ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub ClarifyNode {
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

        # Find target node and thesis
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
        node_type = target_node.get("type", "CLAIM");

        # Call LLM to generate more info
        raw_result = clarify_node_content(
            node_text=node_content,
            node_type=node_type,
            thesis_text=thesis_text
        );
        raw_str = extract_llm_text(raw_result).strip();
        if raw_str.startswith("```") {
            fence_lines = raw_str.split("\n");
            fence_lines = fence_lines[1:];
            if fence_lines and fence_lines[-1].strip().startswith("```") {
                fence_lines = fence_lines[:-1];
            }
            raw_str = "\n".join(fence_lines).strip();
        }
        parsed = json.loads(raw_str);
        more_info = parsed.get("moreInfo", "");
        source_hint = parsed.get("sourceHint", "");

        if not more_info {
            report {"error": "LLM returned empty info"};
            return;
        }

        # Capitalize
        if len(more_info) > 1 {
            more_info = more_info[0].upper() + more_info[1:];
        } elif len(more_info) == 1 {
            more_info = more_info[0].upper();
        }

        # Append source hint to moreInfo if present
        if source_hint {
            more_info = more_info + "\n\n📚 Source: " + source_hint;
        }

        # Store moreInfo on the node without replacing content
        updated_node = {
            "id": target_node["id"],
            "type": target_node["type"],
            "content": target_node.get("content", ""),
            "position": target_node.get("position", {"x": 0, "y": 0}),
            "confidence": target_node.get("confidence", 0.5),
            "isWeak": target_node.get("isWeak", False),
            "issues": target_node.get("issues", []),
            "llmIssueTypes": target_node.get("llmIssueTypes", []),
            "evidence_category": target_node.get("evidence_category", ""),
            "assumptions": target_node.get("assumptions", []),
            "nodeScore": target_node.get("nodeScore", 50),
            "moreInfo": more_info,
            "sourceUrl": target_node.get("sourceUrl", ""),
            "acknowledged": target_node.get("acknowledged", False)
        };

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

        # Return full scored result so client needs only 1 await
        scored = root spawn GetGraphWithScoring(graphId=self.graphId);
        scored_data = scored.reports[0] if scored.reports else {};
        report {
            "success": True,
            "moreInfo": more_info,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"ClarifyNode ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub InvestigateNode {
    has graphId: str,
        nodeId: str,
        addAsEvidence: bool = False;

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

        # Find target node
        target_node = None;
        for n in graph_node.nodes {
            if n["id"] == self.nodeId {
                target_node = n;
                break;
            }
        }

        if not target_node {
            report {"error": "Node not found"};
            return;
        }

        node_content = target_node.get("content", "");
        node_type = target_node.get("type", "CLAIM");
        existing_source = target_node.get("sourceUrl", "");

        # Get thesis for context
        thesis_text = "";
        for n in graph_node.nodes {
            if n["type"] == "THESIS" {
                thesis_text = n.get("content", "");
                break;
            }
        }

        # Use LLM to extract smart search keywords
        raw_keywords = extract_search_keywords(
            node_text=node_content,
            node_type=node_type,
            thesis_text=thesis_text
        );
        search_query = extract_llm_text(raw_keywords).strip().strip('"').strip("'");
        # Fallback if LLM returns empty
        if not search_query or len(search_query) < 3 {
            search_query = node_content[:80];
        }
        print(f"InvestigateNode search query: {search_query}");
        encoded_query = urllib.parse.quote(search_query);

        # Step 1: Search Wikipedia (fetch 5 results for better selection)
        search_url = f"https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch={encoded_query}&format=json&utf8=1&srlimit=5";
        search_req = urllib.request.Request(search_url, headers={"User-Agent": "MaizeMind/1.0"});
        search_resp = urllib.request.urlopen(search_req, timeout=10);
        search_data = json.loads(search_resp.read().decode("utf-8"));

        search_results = search_data.get("query", {}).get("search", []);
        if not search_results {
            report {"error": "No Wikipedia articles found for this topic"};
            return;
        }

        # Filter out the existing source article if node was already investigated
        if existing_source {
            filtered_results: list = [];
            for sr in search_results {
                sr_title_slug = sr.get("title", "").replace(" ", "_");
                if sr_title_slug not in existing_source {
                    filtered_results.append(sr);
                }
            }
            if not filtered_results {
                report {
                    "success": True,
                    "already_sourced": True,
                    "moreInfo": target_node.get("moreInfo", ""),
                    "sourceUrl": existing_source,
                    "message": "This node is already well-sourced. No additional Wikipedia articles found."
                };
                return;
            }
            search_results = filtered_results;
            print(f"  Filtered out existing source, {len(search_results)} candidates remain");
        }

        # Step 2: Ask LLM to pick the best result
        results_text = "";
        _ri = 0;
        while _ri < len(search_results) {
            sr = search_results[_ri];
            sr_title = sr.get("title", "");
            sr_snippet = sr.get("snippet", "").replace("<span class=\"searchmatch\">", "").replace("</span>", "");
            results_text = results_text + f"{_ri}. {sr_title}: {sr_snippet}\n";
            _ri = _ri + 1;
        }
        print(f"  Wikipedia candidates:\n{results_text}");

        raw_pick = pick_best_wiki_result(
            node_text=node_content,
            search_results_text=results_text
        );
        pick_str = extract_llm_text(raw_pick).strip();
        # Parse the digit from LLM response
        pick_idx = 0;
        for ch in pick_str {
            if ch.isdigit() {
                pick_idx = int(ch);
                break;
            }
        }
        if pick_idx < 0 or pick_idx >= len(search_results) {
            pick_idx = 0;
        }

        article_title = search_results[pick_idx]["title"];
        print(f"  LLM picked: '{article_title}' (index {pick_idx})");

        # Step 3: Get extract for best result
        encoded_title = urllib.parse.quote(article_title);
        extract_url = f"https://en.wikipedia.org/w/api.php?action=query&titles={encoded_title}&prop=extracts&exintro=1&explaintext=1&format=json";
        extract_req = urllib.request.Request(extract_url, headers={"User-Agent": "MaizeMind/1.0"});
        extract_resp = urllib.request.urlopen(extract_req, timeout=10);
        extract_data = json.loads(extract_resp.read().decode("utf-8"));

        pages = extract_data.get("query", {}).get("pages", {});
        summary = "";
        for page_id in pages {
            summary = pages[page_id].get("extract", "");
            break;
        }

        # Truncate summary to ~500 chars at sentence boundary
        if len(summary) > 500 {
            cut = summary[:500];
            last_period = cut.rfind(".");
            if last_period > 200 {
                summary = cut[:last_period + 1];
            } else {
                summary = cut + "...";
            }
        }

        # Build Wikipedia URL
        wiki_title = article_title.replace(" ", "_");
        source_url = f"https://en.wikipedia.org/wiki/{urllib.parse.quote(wiki_title)}";

        # Update node with investigation results
        updated_node = {
            "id": target_node["id"],
            "type": target_node["type"],
            "content": target_node.get("content", ""),
            "position": target_node.get("position", {"x": 0, "y": 0}),
            "confidence": target_node.get("confidence", 0.5),
            "isWeak": target_node.get("isWeak", False),
            "issues": target_node.get("issues", []),
            "llmIssueTypes": target_node.get("llmIssueTypes", []),
            "evidence_category": target_node.get("evidence_category", ""),
            "assumptions": target_node.get("assumptions", []),
            "nodeScore": target_node.get("nodeScore", 50),
            "moreInfo": summary,
            "sourceUrl": source_url,
            "acknowledged": target_node.get("acknowledged", False)
        };

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

        # If addAsEvidence, also create an evidence node with the Wikipedia content
        if self.addAsEvidence and summary {
            ev_id = f"node_evidence_{int(time.time())}";
            cat_result = categorize_evidence_fast(summary);
            ev_category = cat_result.get("evidence_category", "logical_reasoning");
            ev_assumptions: list = cat_result.get("assumptions", []);
            ev_confidence = cat_result.get("confidence", 0.6);
            ev_node_score = cat_result.get("nodeScore", 50);

            # Position below target node
            t_pos = target_node.get("position", {"x": 0, "y": 0});
            ev_x = float(t_pos.get("x", 0));
            ev_y = float(t_pos.get("y", 0)) + 130.0;

            # Truncate to first sentence for the node title
            ev_content = summary;
            first_dot = summary.find(".");
            if first_dot > 10 and first_dot < 200 {
                ev_content = summary[:first_dot + 1];
            } elif len(summary) > 120 {
                ev_content = summary[:120] + "...";
            }

            ev_node = {
                "id": ev_id,
                "type": "EVIDENCE",
                "content": ev_content,
                "confidence": ev_confidence,
                "isWeak": ev_confidence < 0.5,
                "issues": [],
                "llmIssueTypes": [],
                "position": {"x": ev_x, "y": ev_y},
                "evidence_category": ev_category,
                "assumptions": ev_assumptions,
                "nodeScore": ev_node_score,
                "sourceUrl": source_url,
                "moreInfo": summary
            };
            graph_node.nodes.append(ev_node);
            graph_node.edges.append({
                "id": f"edge_{ev_id}",
                "source": ev_id,
                "target": self.nodeId,
                "type": "SUPPORTS"
            });
            graph_node.updatedAt = str(int(time.time()));
            print(f"  AutoFix: added evidence node {ev_id}");
        }

        # Return full scored result
        scored = root spawn GetGraphWithScoring(graphId=self.graphId);
        scored_data = scored.reports[0] if scored.reports else {};
        report {
            "success": True,
            "moreInfo": summary,
            "sourceUrl": source_url,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"InvestigateNode ERROR: {e}");
            report {"error": str(e)};
        }
    }
}


walker:pub ExpandBranch {
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

        # Find target node and thesis
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
        node_type = target_node.get("type", "CLAIM");

        # Call LLM to generate branches
        raw_result = expand_branch(
            node_text=node_content,
            node_type=node_type,
            thesis_text=thesis_text
        );
        raw_str = extract_llm_text(raw_result).strip();
        if raw_str.startswith("```") {
            fence_lines = raw_str.split("\n");
            fence_lines = fence_lines[1:];
            if fence_lines and fence_lines[-1].strip().startswith("```") {
                fence_lines = fence_lines[:-1];
            }
            raw_str = "\n".join(fence_lines).strip();
        }
        parsed = json.loads(raw_str);
        branches = parsed.get("branches", []);

        if not branches {
            report {"error": "LLM returned empty branches"};
            return;
        }

        # Get target position for layout
        target_pos_x = 0.0;
        target_pos_y = 0.0;
        for tn in graph_node.nodes {
            if tn["id"] == self.nodeId {
                tp = tn.get("position", {"x": 0, "y": 0});
                target_pos_x = float(tp.get("x", 0));
                target_pos_y = float(tp.get("y", 0));
            }
        }

        # Count existing children for offset
        existing_children = 0;
        for te in graph_node.edges {
            if te.get("target") == self.nodeId and te.get("type") == "SUPPORTS" {
                existing_children = existing_children + 1;
            }
        }

        now_ts = int(time.time());
        branch_idx = 0;
        for b in branches {
            if branch_idx >= 3 { break; }  # Max 3 branches
            b_content = b.get("content", "");
            b_type_raw = b.get("type", "claim").upper();
            if b_type_raw == "EVIDENCE" {
                b_type = "EVIDENCE";
            } else {
                b_type = "CLAIM";
            }

            if not b_content { branch_idx = branch_idx + 1; continue; }

            # Capitalize
            if len(b_content) > 1 {
                b_content = b_content[0].upper() + b_content[1:];
            } elif len(b_content) == 1 {
                b_content = b_content[0].upper();
            }

            branch_id = f"node_branch_{now_ts}_{branch_idx}";
            offset = existing_children + branch_idx;
            new_x = target_pos_x + (offset - 1) * 250.0;
            new_y = target_pos_y + 130.0;

            # Use LLM-provided confidence if available, else fast categorizer
            b_raw_conf = b.get("confidence", 0.5);
            try {
                b_confidence = float(b_raw_conf);
            } except Exception {
                b_confidence = 0.5;
            }
            if b_confidence > 1.0 { b_confidence = 1.0; }
            if b_confidence < 0.1 { b_confidence = 0.1; }

            b_category = "";
            b_node_score = int(b_confidence * 100);
            if b_type == "EVIDENCE" {
                cat_res = categorize_evidence_fast(b_content);
                b_category = cat_res.get("evidence_category", "logical_reasoning");
                # Use LLM confidence but cap by category quality
                cat_weights: dict[str, float] = {
                    "empirical_data": 0.9, "expert_testimony": 0.8,
                    "logical_reasoning": 0.6, "analogy": 0.5, "anecdotal": 0.3
                };
                cat_quality = cat_weights.get(b_category, 0.6);
                combined = cat_quality * 0.4 + b_confidence * 0.6;
                b_node_score = int(combined * 100);
            }

            new_node = {
                "id": branch_id,
                "type": b_type,
                "content": b_content,
                "confidence": b_confidence,
                "isWeak": b_confidence < 0.5,
                "issues": [],
                "llmIssueTypes": [],
                "position": {"x": new_x, "y": new_y},
                "evidence_category": b_category,
                "assumptions": [],
                "nodeScore": b_node_score,
                "sourceUrl": ""
            };
            graph_node.nodes.append(new_node);

            new_edge = {
                "id": f"edge_{branch_id}",
                "source": branch_id,
                "target": self.nodeId,
                "type": "SUPPORTS"
            };
            graph_node.edges.append(new_edge);
            branch_idx = branch_idx + 1;
        }

        graph_node.updatedAt = str(int(time.time()));

        # Return full scored result
        scored = root spawn GetGraphWithScoring(graphId=self.graphId);
        scored_data = scored.reports[0] if scored.reports else {};
        report {
            "success": True,
            "branchCount": branch_idx,
            "graph": scored_data.get("graph", {"id": graph_node.id, "nodes": graph_node.nodes, "edges": graph_node.edges, "createdAt": graph_node.createdAt, "updatedAt": graph_node.updatedAt}),
            "score": scored_data.get("score", {}),
            "issues": scored_data.get("issues", []),
            "nextActions": scored_data.get("nextActions", [])
        };
        } except Exception as e {
            print(f"ExpandBranch ERROR: {e}");
            report {"error": str(e)};
        }
    }
}
