"""Walkers for generating and scoring argument graphs."""

import from graph.argument_graph_nodes { ArgumentGraph }
import from src.graph_generator { Document, generate_argument_graph }

walker:pub GenerateArgumentGraph {
    has notes: str,
        userId: str;

    can run with Root entry {
        print("=== GenerateArgumentGraph ENTERED ===");
        print(f"=== userId={self.userId}, notes length={len(self.notes)} ===");
        try {
        import time;
        graph_id = f"graph_{int(time.time())}";

        docs: list[Document] = [];
        # Retry up to 2 times if LLM returns empty
        result = generate_argument_graph(self.notes, docs);
        result_nodes = result["nodes"] if "nodes" in result else [];
        print(f"  [First attempt] Got {len(result_nodes)} nodes");
        if not result_nodes or len(result_nodes) == 0 {
            print("  [RETRY] LLM returned empty, retrying...");
            result = generate_argument_graph(self.notes, docs);
            result_nodes = result["nodes"] if "nodes" in result else [];
            print(f"  [Retry] Got {len(result_nodes)} nodes");
        }
        raw_nodes = result["nodes"] if "nodes" in result else [];
        raw_edges = result["edges"] if "edges" in result else [];

        type_map: dict[str, str] = {
            "thesis": "THESIS",
            "claim": "CLAIM",
            "evidence": "EVIDENCE",
            "assumption": "ASSUMPTION",
            "counterarg": "COUNTERARGUMENT"
        };
        edge_type_map: dict[str, str] = {
            "supports": "SUPPORTS",
            "contradicts": "CONTRADICTS",
            "depends_on": "DEPENDS_ON",
            "addresses": "ADDRESSES"
        };

        parent_map: dict[str, str] = {};
        children_map: dict[str, list[str]] = {};
        for e in raw_edges {
            etype = e.get("type", "").lower();
            if etype in ["supports", "depends_on"] {
                fid = e.get("from_id", "");
                tid = e.get("to_id", "");
                parent_map[fid] = tid;
                if tid not in children_map {
                    children_map[tid] = [];
                }
                children_map[tid].append(fid);
            }
        }

        all_ids = [n.get("id", "") for n in raw_nodes];
        has_parent_set = set(parent_map.keys());
        root_ids = [nid for nid in all_ids if nid not in has_parent_set];
        if not root_ids and all_ids {
            root_ids = [all_ids[0]];
        }

        level_map: dict[str, int] = {};
        bfs_q: list[str] = [];
        for rid in root_ids {
            bfs_q.append(rid);
            level_map[rid] = 0;
        }
        while bfs_q {
            cur = bfs_q.pop(0);
            for ch in children_map.get(cur, []) {
                if ch not in level_map {
                    level_map[ch] = level_map[cur] + 1;
                    bfs_q.append(ch);
                }
            }
        }
        for nid in all_ids {
            if nid not in level_map {
                level_map[nid] = 0;
            }
        }

        levels: dict[int, list[str]] = {};
        for nid in all_ids {
            lvl = level_map[nid];
            if lvl not in levels {
                levels[lvl] = [];
            }
            levels[lvl].append(nid);
        }

        fe_nodes: list[dict] = [];
        for n in raw_nodes {
            nid = n.get("id", "");
            lvl = level_map.get(nid, 0);
            ns_at_level = levels.get(lvl, [nid]);
            idx_in_level = ns_at_level.index(nid) if nid in ns_at_level else 0;
            spacing = 280;
            x_pos = 250 + (idx_in_level - (len(ns_at_level) - 1) / 2.0) * spacing;
            y_pos = 50 + lvl * 200;

            raw_type = n.get("type", "claim").lower();
            fe_type = type_map.get(raw_type, "CLAIM");

            issues_str = n.get("issues", "");
            issues_list: list[dict] = [];
            if issues_str {
                for iss in issues_str.split(",") {
                    stripped = iss.strip();
                    if stripped {
                        issues_list.append({"id": f"iss_{nid}_{stripped}"});
                    }
                }
            }

            conf = 0.5;
            try {
                conf = float(n.get("confidence", "0.5"));
            } except Exception {
                conf = 0.5;
            }

            fe_nodes.append({
                "id": nid,
                "type": fe_type,
                "content": n.get("text", ""),
                "confidence": conf,
                "isWeak": conf < 0.5,
                "issues": issues_list,
                "position": {"x": x_pos, "y": y_pos}
            });
        }

        fe_edges: list[dict] = [];
        for (i, e) in enumerate(raw_edges) {
            raw_etype = e.get("type", "supports").lower();
            fe_etype = edge_type_map.get(raw_etype, "SUPPORTS");
            fe_edges.append({
                "id": f"edge_{i+1}",
                "source": e.get("from_id", ""),
                "target": e.get("to_id", ""),
                "type": fe_etype
            });
        }

        new_graph = (root ++> ArgumentGraph(
            id=graph_id,
            nodes=fe_nodes,
            edges=fe_edges,
            createdAt=str(int(time.time())),
            updatedAt=str(int(time.time()))
        ))[0];

        sc = result.get("reasoning_score", {});
        fe_score = {
            "overall": int(sc.get("overall", "0")),
            "support": int(sc.get("support_coverage", "0")),
            "premise": int(sc.get("premise_coverage", "0")),
            "consistency": int(sc.get("consistency", "0")),
            "unsupportedClaims": 0,
            "unresolvedContradictions": 0
        };

        summary = result.get("summary", {});
        top_issues = summary.get("top_issues", []);
        improve_nodes = summary.get("improvement_nodes", []);
        fe_issues: list[dict] = [];
        for (i, issue_text) in enumerate(top_issues) {
            target_nid = improve_nodes[i] if i < len(improve_nodes) else (fe_nodes[0].get("id", "") if fe_nodes else "");
            severity = "high" if i == 0 else ("medium" if i == 1 else "low");
            fe_issues.append({
                "id": f"issue_{i+1}",
                "nodeId": target_nid,
                "severity": severity,
                "type": "unsupported_claim",
                "description": str(issue_text),
                "suggestedAction": f"Address: {issue_text}"
            });
        }

        report {
            "graph": {
                "id": graph_id,
                "nodes": fe_nodes,
                "edges": fe_edges,
                "createdAt": new_graph.createdAt,
                "updatedAt": new_graph.updatedAt
            },
            "score": fe_score,
            "issues": fe_issues
        };
        } except Exception as e {
            print(f"=== GenerateArgumentGraph ERROR: {e} ===");
            report {"error": str(e)};
        }
    }
}

walker:pub GetGraphWithScoring {
    has graphId: str;

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

        report {
            "graph": graph_node,
            "score": self.calculate_score(graph_node.nodes, graph_node.edges),
            "issues": self.identify_issues(graph_node.nodes, graph_node.edges)
        };
    }

    def calculate_score(nodes: list, edges: list) -> dict {
        claims = [n for n in nodes if n["type"] in ["CLAIM", "THESIS"]];
        total_claims = len(claims);
        if total_claims == 0 {
            return {"overall": 0, "support": 0, "premise": 0, "consistency": 0,
                    "unsupportedClaims": 0, "unresolvedContradictions": 0};
        }

        # Support coverage
        supported_ids: list[str] = [];
        for e in edges {
            if e.get("type") == "SUPPORTS" {
                supported_ids.append(e.get("target", ""));
            }
        }
        supported_count = len([c for c in claims if c["id"] in supported_ids]);
        support_score = int(supported_count / total_claims * 100);

        # Premise coverage
        claims_with_issues = len([c for c in claims if c.get("issues", [])]);
        premise_score = int((1 - claims_with_issues / total_claims) * 100);

        # Consistency
        counterargs = [n for n in nodes if n["type"] == "COUNTERARGUMENT"];
        addressed_ids: list[str] = [];
        for e in edges {
            if e.get("type") == "ADDRESSES" {
                addressed_ids.append(e.get("target", ""));
            }
        }
        if counterargs {
            unresolved = len([ca for ca in counterargs if ca["id"] not in addressed_ids]);
            consistency_score = int((1 - unresolved / len(counterargs)) * 100);
        } else {
            consistency_score = 100;
        }

        overall = int(0.4 * support_score + 0.4 * premise_score + 0.2 * consistency_score);
        unsupported = total_claims - supported_count;

        return {
            "overall": overall,
            "support": support_score,
            "premise": premise_score,
            "consistency": consistency_score,
            "unsupportedClaims": unsupported,
            "unresolvedContradictions": len(counterargs) - len([ca for ca in counterargs if ca["id"] in addressed_ids])
        };
    }

    def identify_issues(nodes: list, edges: list) -> list {
        issues: list[dict] = [];
        claims = [n for n in nodes if n["type"] in ["CLAIM", "THESIS"]];

        for claim in claims {
            supporting = [e for e in edges if e.get("target") == claim["id"] and e.get("type") == "SUPPORTS"];
            if len(supporting) == 0 {
                issues.append({
                    "id": f"issue_{claim['id']}",
                    "nodeId": claim["id"],
                    "severity": "high",
                    "type": "unsupported_claim",
                    "description": f"'{claim.get('content', '')[:50]}...' lacks supporting evidence",
                    "suggestedAction": "Add evidence, statistics, or citations to support this claim"
                });
            }
        }

        # Check for unaddressed counterarguments
        counterargs = [n for n in nodes if n["type"] == "COUNTERARGUMENT"];
        addressed_ids: list[str] = [];
        for e in edges {
            if e.get("type") == "ADDRESSES" {
                addressed_ids.append(e.get("target", ""));
            }
        }
        for ca in counterargs {
            if ca["id"] not in addressed_ids {
                issues.append({
                    "id": f"issue_{ca['id']}",
                    "nodeId": ca["id"],
                    "severity": "high",
                    "type": "contradiction",
                    "description": f"Counterargument not addressed: '{ca.get('content', '')[:50]}...'",
                    "suggestedAction": "Address this counterargument with evidence or acknowledgment"
                });
            }
        }

        return issues[:3];
    }
}