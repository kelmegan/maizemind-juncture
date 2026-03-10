"""Walkers for generating and scoring argument graphs."""

import from graph.argument_graph_nodes { ArgumentGraph }

walker:pub GenerateArgumentGraph {
    has notes: str,
        userId: str;

    can run with `root entry {
        graph_id = f"graph_{now()}";

        mock_nodes = [
            {"id": "node_thesis", "type": "THESIS", "content": "Main thesis extracted from notes", "position": {"x": 250, "y": 50}},
            {"id": "node_claim_1", "type": "CLAIM", "content": "First major claim", "position": {"x": 100, "y": 200}},
            {"id": "node_claim_2", "type": "CLAIM", "content": "Second major claim", "position": {"x": 400, "y": 200}},
            {"id": "node_evidence_1", "type": "EVIDENCE", "content": "Supporting evidence for claim 1", "position": {"x": 100, "y": 350}}
        ];

        mock_edges = [
            {"id": "edge_1", "source": "node_claim_1", "target": "node_thesis", "type": "SUPPORTS"},
            {"id": "edge_2", "source": "node_claim_2", "target": "node_thesis", "type": "SUPPORTS"},
            {"id": "edge_3", "source": "node_evidence_1", "target": "node_claim_1", "type": "SUPPORTS"}
        ];

        new_graph = (root ++> ArgumentGraph(
            id=graph_id,
            nodes=mock_nodes,
            edges=mock_edges,
            createdAt=str(now()),
            updatedAt=str(now())
        ))[0];

        report {
            "graph": new_graph,
            "score": self.calculate_mock_score(mock_nodes, mock_edges),
            "issues": self.identify_mock_issues(mock_nodes, mock_edges)
        };
    }

    def calculate_mock_score(nodes: list, edges: list) -> dict {
        return {
            "overall": 65,
            "support": 60,
            "premise": 70,
            "consistency": 65,
            "unsupportedClaims": 1,
            "unresolvedContradictions": 0
        };
    }

    def identify_mock_issues(nodes: list, edges: list) -> list {
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


walker:pub GetGraphWithScoring {
    has graphId: str;

    can run with `root entry {
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

        report {
            "graph": graph_node,
            "score": self.calculate_score(graph_node.nodes, graph_node.edges),
            "issues": self.identify_issues(graph_node.nodes, graph_node.edges)
        };
    }

    def calculate_score(nodes: list, edges: list) -> dict {
        claims = [n for n in nodes if n["type"] == "CLAIM"];
        evidence = [n for n in nodes if n["type"] == "EVIDENCE"];

        support_score = min(100, len(evidence) * 30);
        premise_score = min(100, len(claims) * 25);
        consistency_score = 80;
        overall = int(support_score * 0.4 + premise_score * 0.4 + consistency_score * 0.2);

        return {
            "overall": overall,
            "support": support_score,
            "premise": premise_score,
            "consistency": consistency_score,
            "unsupportedClaims": max(0, len(claims) - len(evidence)),
            "unresolvedContradictions": 0
        };
    }

    def identify_issues(nodes: list, edges: list) -> list {
        issues = [];
        claims = [n for n in nodes if n["type"] == "CLAIM"];

        for claim in claims {
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

        return issues[:3];
    }
}