"""Walkers for revising argument graph nodes."""

import from graph.argument_graph_nodes { ArgumentGraph }

walker:pub AddEvidenceToNode {
    has graphId: str,
        nodeId: str,
        evidenceContent: str;

    can run with Root entry {
        graph_node = None;
        for graph in [ArgumentGraph] {
            if graph.id == self.graphId {
                graph_node = graph;
                break;
            }
        }

        if not graph_node {
            report {"error": "Graph not found"};
            return;
        }

        evidence_id = f"node_evidence_{now()}";
        new_evidence = {
            "id": evidence_id,
            "type": "EVIDENCE",
            "content": self.evidenceContent,
            "position": {"x": 0, "y": 0}
        };

        graph_node.nodes.append(new_evidence);

        new_edge = {
            "id": f"edge_{evidence_id}",
            "source": evidence_id,
            "target": self.nodeId,
            "type": "SUPPORTS"
        };

        graph_node.edges.append(new_edge);
        graph_node.updatedAt = str(now());

        report {"success": True, "graph": graph_node};
    }
}


walker:pub AddAssumptionToEvidence {
    has graphId: str,
        nodeId: str,
        assumptionText: str;

    can run with Root entry {
        graph_node = None;
        for graph in [ArgumentGraph] {
            if graph.id == self.graphId {
                graph_node = graph;
                break;
            }
        }

        if not graph_node {
            report {"error": "Graph not found"};
            return;
        }

        # Find the evidence node and add assumption to its assumptions list
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

        graph_node.updatedAt = str(now());

        report {"success": True, "graph": graph_node};
    }
}


walker:pub UpdateNodeContent {
    has graphId: str,
        nodeId: str,
        newContent: str;

    can run with Root entry {
        graph_node = None;
        for graph in [ArgumentGraph] {
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
                updated_node = {
                    "id": node["id"],
                    "type": node["type"],
                    "content": self.newContent,
                    "position": node["position"]
                };
                idx = graph_node.nodes.index(node);
                graph_node.nodes[idx] = updated_node;
                break;
            }
        }

        graph_node.updatedAt = str(now());

        report {"success": True, "graph": graph_node};
    }
}


walker:pub DeleteNode {
    has graphId: str,
        nodeId: str;

    can run with Root entry {
        graph_node = None;
        for graph in [ArgumentGraph] {
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
        graph_node.updatedAt = str(now());

        report {"success": True, "graph": graph_node};
    }
}