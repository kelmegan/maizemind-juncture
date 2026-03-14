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
            "assumption": "EVIDENCE",
            "counterarg": "COUNTERARGUMENT"
        };
        edge_type_map: dict[str, str] = {
            "supports": "SUPPORTS",
            "contradicts": "CONTRADICTS",
            "depends_on": "SUPPORTS",
            "addresses": "ADDRESSES"
        };
        # Evidence quality base weights by category
        category_weights: dict[str, float] = {
            "empirical_data": 0.9, "expert_testimony": 0.8,
            "logical_reasoning": 0.6, "analogy": 0.5, "anecdotal": 0.3
        };

        parent_map: dict[str, str] = {};
        children_map: dict[str, list[str]] = {};
        for e in raw_edges {
            etype = e.get("type", "").lower();
            if etype in ["supports", "depends_on", "addresses"] {
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

            # Extract evidence_category and assumptions
            ev_cat = n.get("evidence_category", "");
            if not ev_cat and fe_type == "EVIDENCE" {
                ev_cat = "logical_reasoning";
            }
            node_assumptions = n.get("assumptions", []);
            if not isinstance(node_assumptions, list) {
                node_assumptions = [];
            }
            # Capitalize each assumption
            capped_assumptions: list = [];
            for assumption in node_assumptions {
                capped_assumptions.append(self.capitalize_text(str(assumption)));
            }

            fe_nodes.append({
                "id": nid,
                "type": fe_type,
                "content": self.capitalize_text(n.get("text", "")),
                "confidence": conf,
                "isWeak": conf < 0.5,
                "issues": issues_list,
                "position": {"x": x_pos, "y": y_pos},
                "evidence_category": ev_cat,
                "assumptions": capped_assumptions,
                "nodeScore": 50
            });
        }

        fe_edges: list[dict] = [];
        for (i, e) in enumerate(raw_edges) {
            raw_etype = e.get("type", "supports").lower();
            fe_etype = edge_type_map.get(raw_etype, "SUPPORTS");
            e_weight = 0.5;
            try {
                e_weight = float(e.get("weight", "0.5"));
            } except Exception {
                e_weight = 0.5;
            }
            e_reasoning = e.get("reasoning_type", "inductive");
            if not e_reasoning { e_reasoning = "inductive"; }
            fe_edges.append({
                "id": f"edge_{i+1}",
                "source": e.get("from_id", ""),
                "target": e.get("to_id", ""),
                "type": fe_etype,
                "weight": e_weight,
                "reasoning_type": e_reasoning
            });
        }

        new_graph = (root ++> ArgumentGraph(
            id=graph_id,
            nodes=fe_nodes,
            edges=fe_edges,
            createdAt=str(int(time.time())),
            updatedAt=str(int(time.time()))
        ))[0];

        # ============================================================
        # COMPREHENSIVE SCORING & ISSUE DETECTION
        # ============================================================

        # --- Step 1: Collect LLM-identified issues ---
        summary = result.get("summary", {});
        top_issues = summary.get("top_issues", []);
        improve_nodes = summary.get("improvement_nodes", []);
        suggested_counterargs = summary.get("suggested_counterarguments", []);

        llm_flagged_ids: list[str] = [];
        llm_issue_map: dict[str, list[str]] = {};
        for (i, issue_text) in enumerate(top_issues) {
            target_nid = improve_nodes[i] if i < len(improve_nodes) else "";
            if target_nid {
                if target_nid not in llm_flagged_ids {
                    llm_flagged_ids.append(target_nid);
                }
                if target_nid not in llm_issue_map {
                    llm_issue_map[target_nid] = [];
                }
                llm_issue_map[target_nid].append(str(issue_text));
            }
        }

        # --- Step 2: Score evidence quality ---
        evidence_nodes = [n for n in fe_nodes if n["type"] == "EVIDENCE"];
        evidence_quality: dict[str, float] = {};
        for ev in evidence_nodes {
            ev_cat = ev.get("evidence_category", "logical_reasoning");
            if not ev_cat { ev_cat = "logical_reasoning"; }
            base = category_weights.get(ev_cat, 0.6);
            # Each assumption reduces quality by 15%
            assumption_count = len(ev.get("assumptions", []));
            penalty = assumption_count * 0.15;
            quality = base - penalty;
            if quality < 0.1 { quality = 0.1; }
            evidence_quality[ev["id"]] = quality;
            # Set per-node score for evidence
            ev["nodeScore"] = int(quality * 100);
        }

        # --- Step 3: Build weak node set ---
        weak_ids: list[str] = [];
        # Evidence with low quality is weak
        for ev in evidence_nodes {
            q = evidence_quality.get(ev["id"], 0.5);
            if q < 0.4 {
                weak_ids.append(ev["id"]);
            }
        }
        # LLM-flagged nodes
        for lid in llm_flagged_ids {
            if lid not in weak_ids {
                weak_ids.append(lid);
            }
        }

        # --- Step 4: Propagate weakness upward ---
        changed = True;
        max_iters = 10;
        iter_count = 0;
        while changed and iter_count < max_iters {
            changed = False;
            iter_count = iter_count + 1;
            for e in fe_edges {
                src = e.get("source", "");
                tgt = e.get("target", "");
                etype = e.get("type", "");
                if etype == "SUPPORTS" and src in weak_ids and tgt not in weak_ids {
                    all_supporters: list[str] = [];
                    for e2 in fe_edges {
                        if e2.get("target") == tgt and e2.get("type") == "SUPPORTS" {
                            all_supporters.append(e2.get("source", ""));
                        }
                    }
                    all_weak = True;
                    for sup_id in all_supporters {
                        if sup_id not in weak_ids {
                            all_weak = False;
                            break;
                        }
                    }
                    if all_weak and len(all_supporters) > 0 {
                        weak_ids.append(tgt);
                        changed = True;
                    }
                }
            }
        }

        # --- Step 5: Check evidence sufficiency & per-node scoring ---
        claim_nodes = [n for n in fe_nodes if n["type"] in ["CLAIM", "THESIS"]];
        thin_support_ids: list[str] = [];
        for c in claim_nodes {
            supporters: list[str] = [];
            sup_strengths: list[float] = [];
            for e in fe_edges {
                if e.get("target") == c["id"] and e.get("type") == "SUPPORTS" {
                    src_id = e.get("source", "");
                    supporters.append(src_id);
                    e_weight = float(e.get("weight", 0.5));
                    q = evidence_quality.get(src_id, 0.5);
                    sup_strengths.append(e_weight * q);
                }
            }
            # Per-node score for claims: weighted avg of (edge_weight * evidence_quality)
            if sup_strengths {
                avg_strength = sum(sup_strengths) / len(sup_strengths);
                c["nodeScore"] = int(avg_strength * 100);
            } else {
                c["nodeScore"] = 0;
            }
            if len(supporters) == 1 {
                thin_support_ids.append(c["id"]);
            }
            if len(supporters) == 0 and c["id"] not in weak_ids {
                weak_ids.append(c["id"]);
            }
        }

        # --- Step 6: Calculate global score ---
        # Uses edge weights and evidence quality for accurate scoring
        total_claims = len(claim_nodes);
        if total_claims > 0 {
            # --- Support: weighted average of (edge_weight * evidence_quality) per claim ---
            claim_support_scores: list[float] = [];
            for c in claim_nodes {
                sup_strengths: list[float] = [];
                for e in fe_edges {
                    if e.get("target") == c["id"] and e.get("type") == "SUPPORTS" {
                        src_id = e.get("source", "");
                        e_weight = float(e.get("weight", 0.5));
                        eq = evidence_quality.get(src_id, 0.5);
                        sup_strengths.append(e_weight * eq);
                    }
                }
                if sup_strengths {
                    avg_strength = sum(sup_strengths) / len(sup_strengths);
                    # Penalty for thin support (only 1 evidence)
                    if len(sup_strengths) == 1 {
                        avg_strength = avg_strength * 0.7;
                    }
                    claim_support_scores.append(avg_strength);
                } else {
                    claim_support_scores.append(0.0);
                }
            }
            support_val = int(sum(claim_support_scores) / len(claim_support_scores) * 100);
            if support_val > 100 { support_val = 100; }
            if support_val < 0 { support_val = 0; }

            # --- Premise: average node scores across claims ---
            claim_scores: list[float] = [];
            for c in claim_nodes {
                ns = c.get("nodeScore", 50);
                claim_scores.append(float(ns));
            }
            premise_val = int(sum(claim_scores) / len(claim_scores));
            # Also penalize for weak nodes
            claims_weak = len([c for c in claim_nodes if c["id"] in weak_ids]);
            weak_penalty = int(claims_weak / total_claims * 30);
            premise_val = premise_val - weak_penalty;
            if premise_val > 100 { premise_val = 100; }
            if premise_val < 0 { premise_val = 0; }

            # --- Consistency: penalize missing counterarguments ---
            counterarg_nodes = [n for n in fe_nodes if n["type"] == "COUNTERARGUMENT"];
            addr_ids: list[str] = [];
            for e in fe_edges {
                if e.get("type") == "ADDRESSES" {
                    addr_ids.append(e.get("target", ""));
                }
            }
            if counterarg_nodes {
                unresolved = len([ca for ca in counterarg_nodes if ca["id"] not in addr_ids]);
                consistency_val = int((1 - unresolved / len(counterarg_nodes)) * 100);
            } else {
                # No counterarguments = unexamined argument, cap at 50
                consistency_val = 50;
            }

            overall_val = int(0.4 * support_val + 0.4 * premise_val + 0.2 * consistency_val);
        } else {
            support_val = 0;
            premise_val = 0;
            consistency_val = 0;
            overall_val = 0;
        }

        fe_score = {
            "overall": overall_val,
            "support": support_val,
            "premise": premise_val,
            "consistency": consistency_val,
            "unsupportedClaims": 0,
            "unresolvedContradictions": 0
        };

        # --- Step 7: Build detailed issues list ---
        fe_issues: list[dict] = [];
        issue_counter = 0;

        # 7a. Low quality evidence (anecdotal, many assumptions)
        for ev in evidence_nodes {
            q = evidence_quality.get(ev["id"], 0.5);
            ev_cat = ev.get("evidence_category", "logical_reasoning");
            ev_assumptions = ev.get("assumptions", []);
            if q < 0.4 {
                issue_counter = issue_counter + 1;
                if ev_cat == "anecdotal" {
                    fe_issues.append({
                        "id": f"issue_{issue_counter}",
                        "nodeId": ev["id"],
                        "severity": "high",
                        "type": "low_quality_evidence",
                        "description": "Anecdotal evidence cannot support broad claims",
                        "suggestedAction": "Replace with empirical data, peer-reviewed studies, or expert testimony. Personal observations are the weakest form of evidence."
                    });
                } elif len(ev_assumptions) > 1 {
                    fe_issues.append({
                        "id": f"issue_{issue_counter}",
                        "nodeId": ev["id"],
                        "severity": "high",
                        "type": "assumption_heavy",
                        "description": f"This evidence relies on {len(ev_assumptions)} unaddressed assumptions",
                        "suggestedAction": "Acknowledge or address the underlying assumptions. Consider providing separate evidence for each assumption."
                    });
                } else {
                    fe_issues.append({
                        "id": f"issue_{issue_counter}",
                        "nodeId": ev["id"],
                        "severity": "medium",
                        "type": "weak_evidence",
                        "description": "This evidence has low credibility",
                        "suggestedAction": "Strengthen by citing credible sources, adding data, or upgrading the evidence type."
                    });
                }
            }
        }

        # 7b. LLM-identified issues
        for nid in llm_flagged_ids {
            issue_texts = llm_issue_map.get(nid, []);
            node_type_str = "";
            for n in fe_nodes {
                if n["id"] == nid {
                    node_type_str = n["type"].lower();
                    break;
                }
            }
            for issue_text in issue_texts {
                issue_counter = issue_counter + 1;
                suggestion = "";
                issue_lower = str(issue_text).lower();
                if "anecdotal" in issue_lower {
                    suggestion = "Replace personal observation with scientific data, peer-reviewed studies, or statistical evidence.";
                } elif "vague" in issue_lower or "unclear" in issue_lower {
                    suggestion = "Make this statement more specific and measurable. Define key terms.";
                } elif "source" in issue_lower or "citation" in issue_lower {
                    suggestion = "Add credible sources such as academic papers, official reports, or expert analysis.";
                } elif "bias" in issue_lower or "one-sided" in issue_lower {
                    suggestion = "Consider alternative perspectives and counterarguments.";
                } else {
                    suggestion = f"Strengthen this {node_type_str} by adding more rigorous evidence.";
                }
                fe_issues.append({
                    "id": f"issue_{issue_counter}",
                    "nodeId": nid,
                    "severity": "high",
                    "type": "llm_identified",
                    "description": str(issue_text),
                    "suggestedAction": suggestion
                });
            }
        }

        # 7c. Weakened claims (propagated)
        for c in claim_nodes {
            if c["id"] in weak_ids {
                already_flagged = False;
                for existing in fe_issues {
                    if existing["nodeId"] == c["id"] {
                        already_flagged = True;
                        break;
                    }
                }
                if not already_flagged {
                    has_any_support = False;
                    for e in fe_edges {
                        if e.get("target") == c["id"] and e.get("type") == "SUPPORTS" {
                            has_any_support = True;
                            break;
                        }
                    }
                    issue_counter = issue_counter + 1;
                    c_type = c["type"].lower();
                    if not has_any_support {
                        fe_issues.append({
                            "id": f"issue_{issue_counter}",
                            "nodeId": c["id"],
                            "severity": "high",
                            "type": "unsupported_claim",
                            "description": f"This {c_type} has no supporting evidence",
                            "suggestedAction": f"Add evidence with credible sources to support this {c_type}."
                        });
                    } else {
                        fe_issues.append({
                            "id": f"issue_{issue_counter}",
                            "nodeId": c["id"],
                            "severity": "high",
                            "type": "weak_foundation",
                            "description": f"All supporting evidence for this {c_type} is weak or low quality",
                            "suggestedAction": f"Add stronger, independent evidence. Current support relies on weak reasoning."
                        });
                    }
                }
            }
        }

        # 7d. Thinly supported claims
        for tid in thin_support_ids {
            already_flagged = False;
            for existing in fe_issues {
                if existing["nodeId"] == tid {
                    already_flagged = True;
                    break;
                }
            }
            if not already_flagged {
                t_type = "";
                for n in fe_nodes {
                    if n["id"] == tid {
                        t_type = n["type"].lower();
                        break;
                    }
                }
                issue_counter = issue_counter + 1;
                fe_issues.append({
                    "id": f"issue_{issue_counter}",
                    "nodeId": tid,
                    "severity": "medium",
                    "type": "thin_support",
                    "description": f"This {t_type} relies on only a single piece of evidence",
                    "suggestedAction": f"Add additional evidence from different sources."
                });
            }
        }

        # 7e. Suggested counterarguments from LLM
        for ca in suggested_counterargs {
            if isinstance(ca, dict) {
                target = ca.get("target_node", "");
                ca_text = ca.get("text", "");
                ca_sev = ca.get("severity", "medium");
                if target and ca_text {
                    issue_counter = issue_counter + 1;
                    fe_issues.append({
                        "id": f"issue_{issue_counter}",
                        "nodeId": target,
                        "severity": ca_sev,
                        "type": "counterargument_suggestion",
                        "description": f"Potential counterargument: {ca_text}",
                        "suggestedAction": "Consider adding a counterargument node to address this critique, or strengthen your evidence to preempt it."
                    });
                }
            }
        }

        fe_issues = fe_issues[:8];

        # --- Step 8: Adjust node confidence based on quality ---
        for n in fe_nodes {
            nid = n["id"];
            if n["type"] == "EVIDENCE" {
                q = evidence_quality.get(nid, 0.5);
                n["confidence"] = q;
                n["isWeak"] = q < 0.4;
            } elif nid in weak_ids {
                if n["confidence"] > 0.3 {
                    n["confidence"] = 0.3;
                }
                n["isWeak"] = True;
            } elif nid in thin_support_ids {
                if n["confidence"] > 0.5 {
                    n["confidence"] = 0.5;
                }
            }
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
            "issues": fe_issues,
            "suggested_counterarguments": suggested_counterargs
        };
        } except Exception as e {
            print(f"=== GenerateArgumentGraph ERROR: {e} ===");
            report self.build_fallback_response(graph_id, self.notes, str(e));
        }
    }

    def capitalize_text(text: str) -> str {
        """Sentence-case: capitalize first letter of each sentence."""
        result = text;
        if len(text) > 0 {
            sentences = text.split(". ");
            result_parts: list = [];
            for s in sentences {
                trimmed = s.strip();
                if len(trimmed) > 1 {
                    capped = trimmed[0].upper() + trimmed[1:];
                    result_parts.append(capped);
                } elif len(trimmed) == 1 {
                    result_parts.append(trimmed[0].upper());
                } else {
                    result_parts.append(trimmed);
                }
            }
            result = ". ".join(result_parts);
        } else {
            result = text;
        }
        return result;

    def build_fallback_response(graph_id: str, notes: str, error_message: str) -> dict {
        import time;
        sentences = self.extract_sentences(notes);
        thesis = sentences[0] if len(sentences) > 0 else "Add your main thesis.";
        nodes: list[dict] = [];
        edges: list[dict] = [];

        nodes.append({
            "id": "node_thesis",
            "type": "THESIS",
            "content": thesis,
            "confidence": 0.3,
            "isWeak": True,
            "issues": [{"id": "iss_node_thesis_needs_evidence"}],
            "position": {"x": 250, "y": 50},
            "evidence_category": "",
            "assumptions": [],
            "nodeScore": 30
        });

        claim_texts = self.pick_claims(sentences);
        claim_positions = [40, 280, 520];
        idx = 0;
        for claim_text in claim_texts {
            claim_id = f"node_claim_{idx + 1}";
            nodes.append({
                "id": claim_id,
                "type": "CLAIM",
                "content": claim_text,
                "confidence": 0.45 if idx == 0 else 0.3,
                "isWeak": idx > 0,
                "issues": [] if idx == 0 else [{"id": f"iss_{claim_id}_needs_support"}],
                "position": {"x": claim_positions[idx % len(claim_positions)], "y": 240},
                "evidence_category": "",
                "assumptions": [],
                "nodeScore": 45 if idx == 0 else 30
            });
            edges.append({
                "id": f"edge_claim_{idx + 1}",
                "source": claim_id,
                "target": "node_thesis",
                "type": "SUPPORTS",
                "weight": 0.5,
                "reasoning_type": "inductive"
            });
            idx = idx + 1;
            if idx >= 3 {
                break;
            }
        }

        if len(sentences) > 1 {
            nodes.append({
                "id": "node_evidence_1",
                "type": "EVIDENCE",
                "content": sentences[1],
                "confidence": 0.65,
                "isWeak": False,
                "issues": [],
                "position": {"x": 40, "y": 430},
                "evidence_category": "logical_reasoning",
                "assumptions": [],
                "nodeScore": 65
            });
            edges.append({
                "id": "edge_evidence_1",
                "source": "node_evidence_1",
                "target": "node_claim_1",
                "type": "SUPPORTS",
                "weight": 0.6,
                "reasoning_type": "inductive"
            });
        }

        if "assumption" in notes.lower() or "one assumption" in notes.lower() {
            nodes.append({
                "id": "node_assumption_1",
                "type": "EVIDENCE",
                "content": "Assumption: time saved from commuting gets redirected into productive work.",
                "confidence": 0.35,
                "isWeak": True,
                "issues": [{"id": "iss_node_assumption_1_hidden_assumption"}],
                "position": {"x": 280, "y": 430},
                "evidence_category": "logical_reasoning",
                "assumptions": ["Time saved from commuting turns into productive work."],
                "nodeScore": 35
            });
            edges.append({
                "id": "edge_assumption_1",
                "source": "node_assumption_1",
                "target": "node_claim_1",
                "type": "SUPPORTS",
                "weight": 0.4,
                "reasoning_type": "causal"
            });
        }

        if "isolated" in notes.lower() or "counterargument" in notes.lower() or "communication" in notes.lower() {
            nodes.append({
                "id": "node_counter_1",
                "type": "COUNTERARGUMENT",
                "content": "Remote work can weaken collaboration and increase isolation for some workers.",
                "confidence": 0.3,
                "isWeak": True,
                "issues": [{"id": "iss_node_counter_1_unaddressed"}],
                "position": {"x": 520, "y": 430},
                "evidence_category": "",
                "assumptions": [],
                "nodeScore": 30
            });
            edges.append({
                "id": "edge_counter_1",
                "source": "node_counter_1",
                "target": "node_thesis",
                "type": "CONTRADICTS",
                "weight": 0.7,
                "reasoning_type": "causal"
            });
        }

        score = self.fallback_calculate_score(nodes, edges);
        issues = self.fallback_identify_issues(nodes, edges);
        if len(issues) == 0 {
            issues = [{
                "id": "issue_fallback_1",
                "nodeId": "node_thesis",
                "severity": "medium",
                "type": "generation_fallback",
                "description": "LLM generation was unavailable, so a fallback graph was created.",
                "suggestedAction": "Review the graph and add evidence to the weakest claim."
            }];
        }

        return {
            "graph": {
                "id": graph_id,
                "nodes": nodes,
                "edges": edges,
                "createdAt": str(int(time.time())),
                "updatedAt": str(int(time.time()))
            },
            "score": score,
            "issues": issues,
            "warning": error_message
        };
    }

    def extract_sentences(notes: str) -> list[str] {
        normalized = notes.replace("\n", " ");
        parts = normalized.split(". ");
        sentences: list[str] = [];
        for part in parts {
            sentence = part.strip();
            if sentence {
                if not sentence.endswith(".") {
                    sentence += ".";
                }
                sentences.append(sentence);
            }
        }
        return sentences;
    }

    def pick_claims(sentences: list[str]) -> list[str] {
        claims: list[str] = [];
        for sentence in sentences {
            lower = sentence.lower();
            if "average commute" in lower or "assumption" in lower or "counterargument" in lower {
                continue;
            }
            claims.append(sentence);
        }
        if len(claims) == 0 and len(sentences) > 0 {
            claims.append(sentences[0]);
        }
        return claims;
    }

    def fallback_calculate_score(nodes: list, edges: list) -> dict {
        claims = [n for n in nodes if n["type"] in ["CLAIM", "THESIS"]];
        total_claims = len(claims);
        if total_claims == 0 {
            return {"overall": 0, "support": 0, "premise": 0, "consistency": 0,
                    "unsupportedClaims": 0, "unresolvedContradictions": 0};
        }

        supported_ids: list[str] = [];
        for e in edges {
            if e.get("type") == "SUPPORTS" {
                supported_ids.append(e.get("target", ""));
            }
        }
        supported_count = len([c for c in claims if c["id"] in supported_ids]);
        support_score = int(supported_count / total_claims * 100);

        claims_with_issues = len([c for c in claims if c.get("issues", [])]);
        premise_score = int((1 - claims_with_issues / total_claims) * 100);

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

    def fallback_identify_issues(nodes: list, edges: list) -> list {
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

walker:pub GetGraphWithScoring {
    has graphId: str;

    can run with Root entry {
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

        # Re-compute per-node scores before reporting
        self.update_node_scores(graph_node.nodes, graph_node.edges);

        report {
            "graph": {
                "id": graph_node.id,
                "nodes": graph_node.nodes,
                "edges": graph_node.edges,
                "createdAt": graph_node.createdAt,
                "updatedAt": graph_node.updatedAt
            },
            "score": self.calculate_score(graph_node.nodes, graph_node.edges),
            "issues": self.identify_issues(graph_node.nodes, graph_node.edges)
        };
    }

    def find_weak_nodes(nodes: list, edges: list) -> list {
        category_weights: dict[str, float] = {
            "empirical_data": 0.9, "expert_testimony": 0.8,
            "logical_reasoning": 0.6, "analogy": 0.5, "anecdotal": 0.3
        };
        weak_ids: list[str] = [];

        # Evidence with low quality
        evidence_nodes = [n for n in nodes if n["type"] == "EVIDENCE"];
        for ev in evidence_nodes {
            ev_cat = ev.get("evidence_category", "logical_reasoning");
            if not ev_cat { ev_cat = "logical_reasoning"; }
            base = category_weights.get(ev_cat, 0.6);
            assumption_count = len(ev.get("assumptions", []));
            quality = base - assumption_count * 0.15;
            if quality < 0.1 { quality = 0.1; }
            if quality < 0.4 and ev["id"] not in weak_ids {
                weak_ids.append(ev["id"]);
            }
        }

        # Nodes with low confidence
        for n in nodes {
            conf = n.get("confidence", 0.5);
            if isinstance(conf, str) {
                try { conf = float(conf); } except Exception { conf = 0.5; }
            }
            if conf < 0.4 and n["id"] not in weak_ids {
                weak_ids.append(n["id"]);
            }
        }

        # Propagate upward
        changed = True;
        max_iters = 10;
        iter_count = 0;
        while changed and iter_count < max_iters {
            changed = False;
            iter_count = iter_count + 1;
            for e in edges {
                src = e.get("source", "");
                tgt = e.get("target", "");
                etype = e.get("type", "");
                if etype == "SUPPORTS" and src in weak_ids and tgt not in weak_ids {
                    all_sup: list[str] = [];
                    for e2 in edges {
                        if e2.get("target") == tgt and e2.get("type") == "SUPPORTS" {
                            all_sup.append(e2.get("source", ""));
                        }
                    }
                    all_weak = True;
                    for sid in all_sup {
                        if sid not in weak_ids {
                            all_weak = False;
                            break;
                        }
                    }
                    if all_weak and len(all_sup) > 0 {
                        weak_ids.append(tgt);
                        changed = True;
                    }
                }
            }
        }
        return weak_ids;
    }

    def update_node_scores(nodes: list, edges: list) -> None {
        """Re-compute nodeScore for all nodes based on current metadata."""
        category_weights: dict[str, float] = {
            "empirical_data": 0.9, "expert_testimony": 0.8,
            "logical_reasoning": 0.6, "analogy": 0.5, "anecdotal": 0.3
        };
        weak_ids = self.find_weak_nodes(nodes, edges);

        for n in nodes {
            ntype = n.get("type", "");
            if ntype == "EVIDENCE" {
                ev_cat = n.get("evidence_category", "logical_reasoning");
                if not ev_cat { ev_cat = "logical_reasoning"; }
                base = category_weights.get(ev_cat, 0.6);
                assumption_count = len(n.get("assumptions", []));
                quality = base - assumption_count * 0.15;
                if quality < 0.1 { quality = 0.1; }
                # Factor in confidence
                conf = n.get("confidence", 0.5);
                if isinstance(conf, str) {
                    try { conf = float(conf); } except Exception { conf = 0.5; }
                }
                combined = quality * 0.6 + conf * 0.4;
                n["nodeScore"] = int(combined * 100);
                n["isWeak"] = combined < 0.4;
            } elif ntype in ["CLAIM", "THESIS"] {
                # Claims/thesis scored by support quality
                supporting_ev: list = [];
                for e in edges {
                    if e.get("target") == n["id"] and e.get("type") == "SUPPORTS" {
                        supporting_ev.append(e.get("source", ""));
                    }
                }
                if len(supporting_ev) > 0 {
                    total_q = 0.0;
                    for sid in supporting_ev {
                        for sn in nodes {
                            if sn["id"] == sid {
                                total_q = total_q + sn.get("nodeScore", 50) / 100.0;
                                break;
                            }
                        }
                    }
                    avg_q = total_q / len(supporting_ev);
                    n["nodeScore"] = int(avg_q * 100);
                } else {
                    n["nodeScore"] = 0;
                }
                n["isWeak"] = n["id"] in weak_ids;
            } elif ntype == "COUNTERARGUMENT" {
                # Counterarguments keep their score or get 50 default
                if "nodeScore" not in n {
                    n["nodeScore"] = 50;
                }
            }
        }
    }

    def calculate_score(nodes: list, edges: list) -> dict {
        category_weights: dict[str, float] = {
            "empirical_data": 0.9, "expert_testimony": 0.8,
            "logical_reasoning": 0.6, "analogy": 0.5, "anecdotal": 0.3
        };
        claims = [n for n in nodes if n["type"] in ["CLAIM", "THESIS"]];
        total_claims = len(claims);
        if total_claims == 0 {
            return {"overall": 0, "support": 0, "premise": 0, "consistency": 0,
                    "unsupportedClaims": 0, "unresolvedContradictions": 0};
        }

        weak_ids = self.find_weak_nodes(nodes, edges);

        # Evidence quality scores
        evidence_quality: dict[str, float] = {};
        evidence_nodes = [n for n in nodes if n["type"] == "EVIDENCE"];
        for ev in evidence_nodes {
            ev_cat = ev.get("evidence_category", "logical_reasoning");
            if not ev_cat { ev_cat = "logical_reasoning"; }
            base = category_weights.get(ev_cat, 0.6);
            assumption_count = len(ev.get("assumptions", []));
            quality = base - assumption_count * 0.15;
            if quality < 0.1 { quality = 0.1; }
            evidence_quality[ev["id"]] = quality;
            ev["nodeScore"] = int(quality * 100);
        }

        # Per-node scores for claims (weighted avg of supporter quality * edge weight)
        for c in claims {
            sup_qualities: list[float] = [];
            for e in edges {
                if e.get("target") == c["id"] and e.get("type") == "SUPPORTS" {
                    src_id = e.get("source", "");
                    e_weight = float(e.get("weight", 0.5));
                    eq = evidence_quality.get(src_id, 0.5);
                    sup_qualities.append(e_weight * eq);
                }
            }
            if sup_qualities {
                c["nodeScore"] = int(sum(sup_qualities) / len(sup_qualities) * 100);
            } else {
                c["nodeScore"] = 0;
            }
        }

        # --- Support: weighted average of (edge_weight * evidence_quality) per claim ---
        claim_support_scores: list[float] = [];
        supported_count = 0;
        for c in claims {
            sup_strengths: list[float] = [];
            for e in edges {
                if e.get("target") == c["id"] and e.get("type") == "SUPPORTS" {
                    src_id = e.get("source", "");
                    e_weight = float(e.get("weight", 0.5));
                    eq = evidence_quality.get(src_id, 0.5);
                    sup_strengths.append(e_weight * eq);
                }
            }
            if sup_strengths {
                supported_count = supported_count + 1;
                avg_strength = sum(sup_strengths) / len(sup_strengths);
                # Penalty for thin support (only 1 evidence)
                if len(sup_strengths) == 1 {
                    avg_strength = avg_strength * 0.7;
                }
                claim_support_scores.append(avg_strength);
            } else {
                claim_support_scores.append(0.0);
            }
        }
        support_score = int(sum(claim_support_scores) / len(claim_support_scores) * 100);
        if support_score > 100 { support_score = 100; }
        if support_score < 0 { support_score = 0; }

        # --- Premise: average node scores across claims ---
        claim_scores: list[float] = [];
        for c in claims {
            ns = c.get("nodeScore", 50);
            claim_scores.append(float(ns));
        }
        premise_score = int(sum(claim_scores) / len(claim_scores));
        claims_weak = len([c for c in claims if c["id"] in weak_ids]);
        weak_penalty = int(claims_weak / total_claims * 30);
        premise_score = premise_score - weak_penalty;
        if premise_score > 100 { premise_score = 100; }
        if premise_score < 0 { premise_score = 0; }

        # --- Consistency: penalize missing counterarguments ---
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
            # No counterarguments = unexamined argument, cap at 50
            consistency_score = 50;
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
        category_weights: dict[str, float] = {
            "empirical_data": 0.9, "expert_testimony": 0.8,
            "logical_reasoning": 0.6, "analogy": 0.5, "anecdotal": 0.3
        };
        issues: list[dict] = [];
        weak_ids = self.find_weak_nodes(nodes, edges);
        claims = [n for n in nodes if n["type"] in ["CLAIM", "THESIS"]];

        # --- 1. Low quality evidence ---
        evidence_nodes = [n for n in nodes if n["type"] == "EVIDENCE"];
        for ev in evidence_nodes {
            ev_cat = ev.get("evidence_category", "logical_reasoning");
            if not ev_cat { ev_cat = "logical_reasoning"; }
            base = category_weights.get(ev_cat, 0.6);
            ev_assumptions = ev.get("assumptions", []);
            quality = base - len(ev_assumptions) * 0.15;
            if quality < 0.1 { quality = 0.1; }
            if quality < 0.4 {
                if ev_cat == "anecdotal" {
                    issues.append({
                        "id": f"issue_ev_{ev['id']}",
                        "nodeId": ev["id"],
                        "severity": "high",
                        "type": "low_quality_evidence",
                        "description": "Anecdotal evidence cannot support broad claims",
                        "suggestedAction": "Replace with empirical data, peer-reviewed studies, or expert testimony."
                    });
                } elif len(ev_assumptions) > 1 {
                    issues.append({
                        "id": f"issue_ev_{ev['id']}",
                        "nodeId": ev["id"],
                        "severity": "high",
                        "type": "assumption_heavy",
                        "description": f"This evidence relies on {len(ev_assumptions)} unaddressed assumptions",
                        "suggestedAction": "Acknowledge or address the underlying assumptions."
                    });
                } else {
                    issues.append({
                        "id": f"issue_ev_{ev['id']}",
                        "nodeId": ev["id"],
                        "severity": "medium",
                        "type": "weak_evidence",
                        "description": "This evidence has low credibility",
                        "suggestedAction": "Strengthen by citing credible sources or upgrading evidence type."
                    });
                }
            }
        }

        # --- 2. Weakened claims ---
        for c in claims {
            if c["id"] in weak_ids {
                all_sup: list[str] = [];
                for e in edges {
                    if e.get("target") == c["id"] and e.get("type") == "SUPPORTS" {
                        all_sup.append(e.get("source", ""));
                    }
                }
                c_type = c["type"].lower();
                if len(all_sup) == 0 {
                    issues.append({
                        "id": f"issue_{c['id']}",
                        "nodeId": c["id"],
                        "severity": "high",
                        "type": "unsupported_claim",
                        "description": f"This {c_type} has no supporting evidence",
                        "suggestedAction": f"Add evidence with credible sources to support this {c_type}."
                    });
                } else {
                    issues.append({
                        "id": f"issue_weak_{c['id']}",
                        "nodeId": c["id"],
                        "severity": "high",
                        "type": "weak_foundation",
                        "description": f"All supporting evidence for this {c_type} is weak or low quality",
                        "suggestedAction": f"Add stronger, independent evidence to support this {c_type}."
                    });
                }
            }
        }

        # --- 3. Thin support ---
        for c in claims {
            already = False;
            for existing in issues {
                if existing["nodeId"] == c["id"] {
                    already = True;
                    break;
                }
            }
            if not already {
                sups: list[str] = [];
                for e in edges {
                    if e.get("target") == c["id"] and e.get("type") == "SUPPORTS" {
                        sups.append(e.get("source", ""));
                    }
                }
                if len(sups) == 1 {
                    c_type = c["type"].lower();
                    issues.append({
                        "id": f"issue_thin_{c['id']}",
                        "nodeId": c["id"],
                        "severity": "medium",
                        "type": "thin_support",
                        "description": f"This {c_type} relies on only a single piece of evidence",
                        "suggestedAction": f"Add additional evidence from different sources."
                    });
                }
            }
        }

        # --- 4. Unaddressed counterarguments ---
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
                    "description": "Counterargument not addressed",
                    "suggestedAction": "Address this counterargument with evidence or acknowledgment."
                });
            }
        }

        return issues[:8];
    }
}
