"""MaizeMind - Graph Generator Pipeline.
Takes raw user notes/uploads, processes through LLM,
outputs structured argument map with scoring.
"""

import json;
import time;

# Model is configured in jac.toml under [plugins.byllm.model]

# ============================================================
# 1. DATA TYPES
# ============================================================

obj Source {
    has title: str = "",
        quote: str = "",
        page: int = 0;
}

obj GraphNode {
    has id: str,
        label: str = "claim",
        text: str = "",
        parent_id: str = "",
        confidence: float = 0.5,
        status: str = "needs_work",
        issues: list[str] = [],
        suggestions: list[str] = [],
        evidence_category: str = "",
        assumptions: list[str] = [],
        role: str = "",
        semantic_role: str = "",
        source_span_ids: list[str] = [],
        speaker_ids: list[str] = [],
        origin: str = "",
        question: str = "",
        decision_status: str = "",
        resolution_text: str = "",
        scope: str = "",
        time_horizon: str = "",
        option_status: str = "",
        evidence_kind: str = "",
        criterion_tags: list[str] = [],
        risk_kind: str = "",
        severity: str = "",
        is_blocker: bool = False,
        assumption_status: str = "",
        question_status: str = "",
        owner: str = "",
        owners: list[str] = [],
        due_date: str = "",
        priority: str = "",
        task_status: str = "",
        action_status: str = "";
}

obj GraphEdge {
    has from_id: str,
        to_id: str,
        label: str = "supports",
        role: str = "",
        weight: float = 0.5,
        confidence: float = 0.5,
        reasoning_type: str = "inductive";
}

obj Document {
    has title: str,
        content: str;
}

obj ReasoningScore {
    has overall: int = 0,
        support_coverage: int = 0,
        premise_coverage: int = 0,
        consistency: int = 0,
        passing: bool = False;
}

obj GraphSummary {
    has top_issues: list[str] = [],
        strength_nodes: list[str] = [],
        improvement_nodes: list[str] = [],
        suggested_counterarguments: list[dict] = [];
}


# ============================================================
# 2. LLM FUNCTIONS
# Optimized: 2 lean LLM calls with minimal output
# ============================================================

"""Extract a compact argument graph from the user's notes. Return ONLY valid JSON, with no explanation.
Format: {"nodes":[{"id":"n1","kind":"thesis|claim|evidence|counterarg","text":"...","evidence_category":"empirical_data|expert_testimony|anecdotal|logical_reasoning|analogy","assumptions":["Short question only if clearly necessary"]},...],
"edges":[{"from_id":"n2","to_id":"n1","kind":"supports|contradicts|addresses"},...]}
STRICT RULES:
1. EXACTLY 1 thesis node.
2. Prefer 4-6 total nodes. Keep only the strongest claims, evidence, and counterarguments.
3. SUPPORTS direction must go from supporting node -> supported node.
   - evidence -> claim
   - claim -> thesis or broader claim
4. CONTRADICTS direction must go from counterargument -> claim or thesis.
5. ADDRESSES direction must go from response/rebuttal -> counterargument.
6. The thesis should almost never be the source of a SUPPORTS edge.
7. Every evidence node must support a claim. Every major claim should connect to the thesis or another claim.
8. Discard meta-commentary. Keep node text under 22 words when possible.
9. Include evidence_category ONLY for evidence nodes.
10. Include assumptions ONLY when a hidden assumption is obvious. Max 1 short question per node.
11. Omit optional fields when empty. Do not include extra fields.
12. If unsure about an edge, omit it rather than reversing it.
Return valid JSON only. No markdown fences."""
def parse_notes_and_edges(
    notes: str,
    documents: list[Document]
) -> str
by llm(temperature=0.2);

"""Rewrite compact graph diagnostics into brief critique JSON.
Input 1 is nodes_json: [{"id":"n1","kind":"claim","text":"..."}, ...]
Input 2 is issue_hints_json: [{"node_id":"n2","type":"unsupported_claim|orphan_node","severity":"high|medium","explanation":"..."}, ...]
Input 3 is graph_meta_json: {"claim_ids":["n1","n2"],"counterarg_ids":["n7"],"strength_nodes":["n3"]}
Return:
{"top_issues":["[n2] Unsupported claim: no direct support yet", "..."],
"strength_nodes":["n3"],
"improvement_nodes":["n2","n4"],
"counterarguments":[{"target_node":"n2","text":"A short specific counterargument","severity":"high|medium|low"}]}
Rules:
- Prefer the provided issue_hints over inventing new issues.
- top_issues should describe weaknesses, not just repeat node text.
- Keep top_issues to 3 items max.
- improvement_nodes should be node ids that most need revision.
- counterarguments should target weak claims or the thesis only, max 2.
- Return valid JSON only."""
def analyze_and_summarize_llm(
    all_nodes_json: str,
    all_edges_json: str,
    sources_json: str
) -> str
by llm(temperature=0.2);

"""Extract a compact business meeting decision board from meeting notes.
Return ONLY valid JSON with this shape:
{"graph_mode":"business_meeting_decision","schema_version":"1.0","board_id":"board_001","primary_decision_id":"d1",
"meeting":{"title":"...","date":"YYYY-MM-DD","participants":["..."],"source_type":"notes|transcript|mixed"},
"summary":"...",
"nodes":[{"id":"d1","role":"DECISION|OPTION|EVIDENCE|RISK|ASSUMPTION|OPEN_QUESTION|ACTION","text":"...",
"question":"...","status":"open|tentative|final|deferred","resolution_text":"...","scope":"...","time_horizon":"...",
"option_status":"proposed|leading|selected|rejected|status_quo",
"evidence_kind":"metric|fact|precedent|stakeholder_observation|quote|unknown",
"risk_kind":"risk|objection|constraint","severity":"low|medium|high","is_blocker":true,
"assumption_status":"implicit|explicit|validated|unverified|invalidated",
"question_status":"open|answered|parked",
"owners":["..."],"due_date":"YYYY-MM-DD","priority":"low|medium|high","action_status":"open|in_progress|blocked|done",
"criterion_tags":["cost|speed|customer_impact|compliance|feasibility|risk|other"],
"source_span_ids":["s1"],"speaker_ids":["spk1"],"origin":"extracted|manual|revised","confidence":0.8,
"evidence_category":"empirical_data|expert_testimony|anecdotal|logical_reasoning|analogy","assumptions":["Short question only if clearly necessary"]}],
"edges":[{"id":"x1","role":"HAS_OPTION|SUPPORTS|OPPOSES|DEPENDS_ON|BLOCKS|RESOLVES|IMPLEMENTS","source_id":"d1","target_id":"o1","confidence":0.8}]}
Rules:
1. Extract exactly 1 primary decision. If no final decision exists, use a provisional decision and set DECISION.status="open".
2. Prefer 6-12 nodes total. Keep only the most decision-relevant items.
3. If the meeting contains multiple major decisions, choose one and center the board on that one decision only.
4. Use OPTION for distinct alternatives under consideration, ideally 2-5 when present.
5. Use EVIDENCE only for factual support, concrete progress, metrics, precedent, or stakeholder observations.
6. Use RISK for blockers, objections, constraints, or downside scenarios. Set risk_kind and severity when clear.
7. Use OPEN_QUESTION for unresolved questions that block commitment or comparison. Set is_blocker=true when clearly blocking.
8. Use ASSUMPTION only for hidden assumptions the decision depends on. Treat criteria as criterion_tags metadata, never as nodes.
9. Use ACTION for concrete follow-up tasks. Include owners and due_date only when explicit or very clear.
10. Do NOT create PERSON, DATE, or CRITERION nodes. Keep owner, due date, priority, and tags as metadata only.
11. Do NOT use Toulmin warrant/backing nodes.
12. Every OPTION should be connected with HAS_OPTION from DECISION -> OPTION.
13. EVIDENCE should SUPPORT an OPTION or the DECISION.
14. RISK should OPPOSE an OPTION or the DECISION.
15. ASSUMPTION should DEPEND_ON an OPTION or the DECISION.
16. OPEN_QUESTION should BLOCK an OPTION or the DECISION.
17. ACTION should RESOLVE an OPEN_QUESTION when it closes uncertainty, or IMPLEMENT a DECISION when it operationalizes the chosen path.
18. Keep node text concise, business-readable, and under 18 words when possible.
19. ACTION text should be the task itself, not the full sentence with owner/date repeated.
20. Omit empty optional fields. No markdown fences. Valid JSON only."""
def parse_business_meeting_decision(
    notes: str,
    documents: list[Document]
) -> str
by llm(temperature=0.2);

"""Generate a counterargument against this claim.
Return JSON: {"counterargument":"<max 20 words>"}
Rules: MUST be under 20 words. One short sentence only. Name a specific study or expert if relevant. Example length: 'Eratosthenes measured Earth's curvature in 240 BC using shadow angles.'"""
def:pub generate_counterargument(
    claim_text: str,
    thesis_text: str
) -> str
by llm(temperature=0.4);

"""Provide additional context, explanation, or detail about this node's content. Do NOT rewrite the original — instead expand on it.
Return JSON: {"moreInfo":"1-3 sentences of additional context, background, or explanation.", "sourceHint":"A specific source, study, book, or expert to look up for more info (e.g. 'Eratosthenes experiment, 240 BC' or 'NASA Earth Observatory satellite data'). If none relevant, empty string."}
Rules:
- Be informative and specific. Name real studies, researchers, dates, or data.
- If it's evidence, explain methodology or context.
- If it's a claim, explain the reasoning behind it.
- If it's a COUNTERARGUMENT, explain what factual basis it draws from and cite the specific source, experiment, or expert.
- sourceHint should point the user to a real, verifiable source they can look up."""
def:pub clarify_node_content(
    node_text: str,
    node_type: str,
    thesis_text: str
) -> str
by llm(temperature=0.3);

"""Return one short Wikipedia search phrase (2-6 words) for the concept or factual claim in this node.
Use the thesis only as background context, not as the search topic.
Rules:
1. Focus on the specific concept, experiment, effect, theory, or controversy in node_text.
2. Prefer the core topic over broad thesis words.
3. Use a person's name only when the person is the best article target.
4. Keep it specific enough that different nodes would usually produce different searches.
Return only the search phrase. No JSON, no explanation."""
def:pub extract_search_keywords(
    node_text: str,
    node_type: str,
    thesis_text: str
) -> str
by llm(temperature=0.1);

"""You are given a node from an argument graph and a list of Wikipedia search results.
Pick the ONE result that is most relevant and useful for understanding or fact-checking this specific node.
Return ONLY the number (0, 1, 2, 3, or 4) of the best result. Nothing else — just the digit.
If none are relevant at all, return 0."""
def:pub pick_best_wiki_result(
    node_text: str,
    search_results_text: str
) -> str
by llm(temperature=0.0);

"""Break this node into 2-3 plausible supporting branches.
Return JSON: {"branches":[{"content":"<sub-claim or evidence text, max 25 words>","type":"claim|evidence","confidence":0.3}]}
Rules:
1. Max 3 branches.
2. Each branch should be a distinct talking point someone might actually use.
3. Use "evidence" only for concrete observations, studies, experiments, or direct source-backed facts.
4. Use "claim" for assertions, interpretations, accusations, allegations, or theories.
5. When unsure, use "claim".
6. confidence should reflect factual defensibility: low for speculation, higher for well-supported facts.
Return valid JSON only."""
def:pub expand_branch(
    node_text: str,
    node_type: str,
    thesis_text: str
) -> str
by llm(temperature=0.3);

"""Evaluate a single piece of evidence in the context of an argument.
Return JSON: {"evidence_category":"empirical_data|expert_testimony|anecdotal|logical_reasoning|analogy","assumptions":["assumption1","assumption2"],"confidence":0.3,"reasoning":"brief explanation of quality assessment"}
evidence_category: empirical_data (scientific studies, statistics), expert_testimony (expert opinions, authoritative sources), anecdotal (personal stories, individual observations), logical_reasoning (logical deductions, philosophical arguments), analogy (comparisons to similar situations).
confidence: 0.0-1.0, be critical. Religious texts=0.1-0.2. Personal observation=0.1-0.3. Published studies=0.7-0.9. empirical_data=published studies ONLY, never personal observations.
assumptions: list as questions highlighting what must be true (e.g. 'Does this source apply to this context?' or 'Is this sample size large enough?')."""
def:pub evaluate_single_evidence(
    evidence_text: str,
    thesis_text: str,
    context_description: str
) -> str
by llm(temperature=0.2);


# ============================================================
# 3. JSON PARSING HELPERS
# ============================================================

"Fast keyword-based evidence categorizer with quality detection — no LLM call needed."
def:pub categorize_evidence_fast(text: str) -> dict {
    lower = text.lower();
    word_count = len(text.split());

    # Keyword lists for each category
    empirical_kw = ["study", "studies", "research", "data", "statistic", "percent", "survey",
                     "experiment", "trial", "sample", "measured", "published", "journal",
                     "findings", "analysis", "meta-analysis", "dataset", "observed rate"];
    expert_kw = ["expert", "professor", "dr.", "according to", "authority", "specialist",
                  "scholar", "researcher", "nobel", "institute", "university"];
    anecdotal_kw = ["personally", "i saw", "my experience", "i believe", "i think",
                     "my friend", "someone told", "i heard", "story", "anecdote"];
    analogy_kw = ["similar to", "like", "analogous", "compared to", "just as",
                   "resembles", "parallel", "equivalent"];

    # Low-quality indicators — opinions, questions, vague claims
    opinion_kw = ["what if", "maybe", "probably", "i think", "i believe", "i feel",
                   "could be", "might be", "seems like", "obviously", "everyone knows",
                   "clearly", "just", "simply"];
    question_markers = ["?", "what if", "how come", "why do", "isn't it"];

    # Count matches
    emp_count = 0;
    for kw in empirical_kw {
        if kw in lower { emp_count = emp_count + 1; }
    }
    exp_count = 0;
    for kw in expert_kw {
        if kw in lower { exp_count = exp_count + 1; }
    }
    anec_count = 0;
    for kw in anecdotal_kw {
        if kw in lower { anec_count = anec_count + 1; }
    }
    anal_count = 0;
    for kw in analogy_kw {
        if kw in lower { anal_count = anal_count + 1; }
    }
    opinion_count = 0;
    for kw in opinion_kw {
        if kw in lower { opinion_count = opinion_count + 1; }
    }
    is_question = False;
    for qm in question_markers {
        if qm in lower { is_question = True; break; }
    }

    # Pick the best match
    category = "logical_reasoning";
    confidence = 0.4;
    if emp_count >= exp_count and emp_count >= anec_count and emp_count >= anal_count and emp_count > 0 {
        category = "empirical_data";
        confidence = 0.75;
    } elif exp_count >= anec_count and exp_count >= anal_count and exp_count > 0 {
        category = "expert_testimony";
        confidence = 0.7;
    } elif anec_count > 0 {
        category = "anecdotal";
        confidence = 0.2;
    } elif anal_count > 0 {
        category = "analogy";
        confidence = 0.4;
    }

    # Apply quality penalties
    assumptions: list = [];

    # Penalty: questions are not evidence
    if is_question {
        confidence = confidence - 0.2;
        assumptions.append("This is phrased as a question, not a verifiable claim");
    }

    # Penalty: opinion markers
    if opinion_count > 0 {
        confidence = confidence - opinion_count * 0.1;
        assumptions.append("Contains opinion language — needs factual backing");
    }

    # Penalty: very short claims without specific data
    if word_count < 8 and emp_count == 0 and exp_count == 0 {
        confidence = confidence - 0.15;
        assumptions.append("Brief claim without specific evidence or citation");
    }

    # Penalty: no verifiable content (no numbers, no names, no citations)
    has_number = False;
    for ch in text {
        if ch.isdigit() { has_number = True; break; }
    }
    has_specific = emp_count > 0 or exp_count > 0 or has_number;
    if not has_specific and category == "logical_reasoning" {
        confidence = confidence - 0.1;
        assumptions.append("No specific data, study, or expert cited");
    }

    # Floor confidence at 0.1
    if confidence < 0.1 { confidence = 0.1; }
    if confidence > 1.0 { confidence = 1.0; }

    # Compute node score from category weights + confidence
    cat_weights: dict[str, float] = {
        "empirical_data": 0.9, "expert_testimony": 0.8,
        "logical_reasoning": 0.6, "analogy": 0.5, "anecdotal": 0.3
    };
    base_quality = cat_weights.get(category, 0.6);
    # Factor in confidence — low confidence drags down the score
    quality = base_quality * 0.5 + confidence * 0.5;
    assumption_penalty = len(assumptions) * 0.1;
    quality = quality - assumption_penalty;
    if quality < 0.1 { quality = 0.1; }
    node_score = int(quality * 100);

    return {
        "evidence_category": category,
        "confidence": confidence,
        "assumptions": assumptions,
        "nodeScore": node_score
    };
}

"Extract text content from an LLM response (handles ChatCompletion objects)."
def:pub extract_llm_text(raw: object) -> str {
    if isinstance(raw, str) {
        return raw;
    }
    # Handle ChatCompletion object from OpenAI-compatible APIs
    if hasattr(raw, 'choices') {
        return str(raw.choices[0].message.content);
    }
    return str(raw);
}

"Parse JSON string from LLM, handling markdown fences."
def extract_json_candidate(raw: object) -> str {
    cleaned = extract_llm_text(raw).strip();
    if cleaned.startswith("```") {
        lines = cleaned.split("\n");
        if lines[0].startswith("```") {
            lines = lines[1:];
        }
        if lines and lines[-1].strip().startswith("```") {
            lines = lines[:-1];
        }
        cleaned = "\n".join(lines).strip();
    }
    first_brace = cleaned.find("{");
    first_bracket = cleaned.find("[");
    start_idx = -1;
    if first_brace >= 0 and first_bracket >= 0 {
        start_idx = first_brace if first_brace < first_bracket else first_bracket;
    } elif first_brace >= 0 {
        start_idx = first_brace;
    } elif first_bracket >= 0 {
        start_idx = first_bracket;
    }

    last_brace = cleaned.rfind("}");
    last_bracket = cleaned.rfind("]");
    end_idx = -1;
    if last_brace >= 0 and last_bracket >= 0 {
        end_idx = last_brace if last_brace > last_bracket else last_bracket;
    } elif last_brace >= 0 {
        end_idx = last_brace;
    } elif last_bracket >= 0 {
        end_idx = last_bracket;
    }

    if start_idx >= 0 and end_idx >= start_idx {
        cleaned = cleaned[start_idx:end_idx + 1].strip();
    }
    return cleaned;
}

"Parse JSON string from LLM, handling markdown fences."
def safe_parse_json(raw: object) -> list {
    cleaned = extract_json_candidate(raw);
    try {
        return json.loads(cleaned);
    } except Exception {
        return [];
    }
}

"Count incoming edges by label for a node."
def incoming_count(edges: list[GraphEdge], node_id: str, label: str) -> int {
    count = 0;
    for e in edges {
        if e.to_id == node_id and e.label == label {
            count = count + 1;
        }
    }
    return count;
}

"Check whether a node participates in any edge."
def has_any_connection(edges: list[GraphEdge], node_id: str) -> bool {
    for e in edges {
        if e.from_id == node_id or e.to_id == node_id {
            return True;
        }
    }
    return False;
}

"Minimal rule-based hints to guide critique generation."
def build_issue_hints(nodes: list[GraphNode], edges: list[GraphEdge]) -> list[dict[str, object]] {
    hints: list[dict[str, object]] = [];
    for n in nodes {
        if n.label in ["thesis", "claim"] and incoming_count(edges, n.id, "supports") == 0 {
            hints.append({
                "node_id": n.id,
                "type": "unsupported_claim",
                "severity": "high" if n.label == "thesis" else "medium",
                "explanation": "This point has no direct support yet."
            });
        }
        if n.label != "thesis" and not has_any_connection(edges, n.id) {
            hints.append({
                "node_id": n.id,
                "type": "orphan_node",
                "severity": "medium",
                "explanation": "This node is disconnected from the rest of the graph."
            });
        }
    }
    return hints;
}

def str_list_from_any(raw_value: object) -> list[str] {
    result: list[str] = [];
    if raw_value is None {
        return result;
    }
    if isinstance(raw_value, str) and raw_value {
        return [s.strip() for s in raw_value.split(",") if s.strip()];
    }
    if isinstance(raw_value, list) {
        for item in raw_value {
            text = str(item).strip();
            if text {
                result.append(text);
            }
        }
    }
    return result;
}

def bool_from_any(raw_value: object, default_val: bool = False) -> bool {
    if raw_value is None {
        return default_val;
    }
    if isinstance(raw_value, bool) {
        return raw_value;
    }
    text = str(raw_value).lower().strip();
    if text in ["true", "1", "yes"] { return True; }
    if text in ["false", "0", "no"] { return False; }
    return default_val;
}

def normalize_business_node_role(raw_role: str) -> str {
    role = raw_role.upper().strip();
    role_map: dict[str, str] = {
        "DECISION": "DECISION",
        "OPTION": "OPTION",
        "EVIDENCE": "EVIDENCE",
        "RISK": "RISK",
        "ASSUMPTION": "ASSUMPTION",
        "OPEN_QUESTION": "OPEN_QUESTION",
        "QUESTION": "OPEN_QUESTION",
        "ACTION": "ACTION",
        "NEXT_ACTION": "ACTION"
    };
    return role_map.get(role, "");
}

def normalize_business_edge_role(raw_role: str) -> str {
    role = raw_role.upper().strip();
    role_map: dict[str, str] = {
        "HAS_OPTION": "HAS_OPTION",
        "SUPPORTS": "SUPPORTS",
        "SUPPORT": "SUPPORTS",
        "OPPOSES": "OPPOSES",
        "CONTRADICTS": "OPPOSES",
        "CONTRADICT": "OPPOSES",
        "DEPENDS_ON": "DEPENDS_ON",
        "DEPENDS": "DEPENDS_ON",
        "BLOCKS": "BLOCKS",
        "RESOLVES": "RESOLVES",
        "ADDRESSES": "RESOLVES",
        "IMPLEMENTS": "IMPLEMENTS"
    };
    return role_map.get(role, "");
}

"Convert a raw dict from LLM into a GraphNode."
def dict_to_graphnode(d: dict[str, object]) -> GraphNode {
    nid = str(d.get("id", d.get("node_id", d.get("nodeId", "unknown"))));
    nkind = str(d.get("kind", d.get("type", d.get("node_type", d.get("label", "claim")))));
    ntext = str(d.get("text", d.get("content", d.get("description", ""))));
    nparent = d.get("parent_id", d.get("parentId", d.get("parent", "")));
    if nparent is None {
        nparent = "";
    }

    raw_conf = d.get("confidence", d.get("score", d.get("strength", 0.5)));
    try {
        nconf = float(raw_conf);
    } except Exception {
        nconf = 0.5;
    }

    nstatus = str(d.get("status", d.get("state", "needs_work")));

    raw_issues = d.get("issues", d.get("problems", []));
    issue_list: list[str] = [];
    if raw_issues is None {
        raw_issues = [];
    }
    if isinstance(raw_issues, str) and raw_issues {
        issue_list = [s.strip() for s in raw_issues.split(",")];
    } elif isinstance(raw_issues, list) {
        issue_list = [str(i) for i in raw_issues];
    }

    raw_sugg = d.get("suggestions", d.get("actions", d.get("suggested_actions", [])));
    sugg_list: list[str] = [];
    if raw_sugg is None {
        raw_sugg = [];
    }
    if isinstance(raw_sugg, str) and raw_sugg {
        sugg_list = [s.strip() for s in raw_sugg.split(",")];
    } elif isinstance(raw_sugg, list) {
        sugg_list = [str(s) for s in raw_sugg];
    }

    # Evidence category
    raw_cat = d.get("evidence_category", d.get("category", ""));
    ev_cat = str(raw_cat) if raw_cat else "";

    # Assumptions list
    raw_assumptions = d.get("assumptions", []);
    assumption_list: list[str] = [];
    if raw_assumptions is None {
        raw_assumptions = [];
    }
    if isinstance(raw_assumptions, str) and raw_assumptions {
        assumption_list = [s.strip() for s in raw_assumptions.split(",")];
    } elif isinstance(raw_assumptions, list) {
        assumption_list = [str(a) for a in raw_assumptions];
    }

    semantic_role = normalize_business_node_role(str(d.get("role", d.get("semanticRole", d.get("semantic_role", "")))));
    owner = str(d.get("owner", d.get("assignee", "")));
    due_date = str(d.get("dueDate", d.get("due_date", "")));
    priority = str(d.get("priority", ""));
    task_status = str(d.get("taskStatus", d.get("task_status", d.get("workflow_status", d.get("action_status", "")))));
    owner_list = str_list_from_any(d.get("owners", d.get("owner_list", [])));
    if len(owner_list) == 0 and owner {
        owner_list = [owner];
    }
    if not owner and len(owner_list) > 0 {
        owner = owner_list[0];
    }

    gn = GraphNode(id=nid);
    gn.label = nkind;
    gn.text = ntext;
    gn.parent_id = str(nparent);
    gn.confidence = nconf;
    gn.status = nstatus;
    gn.issues = issue_list;
    gn.suggestions = sugg_list;
    gn.evidence_category = ev_cat;
    gn.assumptions = assumption_list;
    gn.role = semantic_role;
    gn.semantic_role = semantic_role;
    gn.source_span_ids = str_list_from_any(d.get("source_span_ids", d.get("sourceSpanIds", [])));
    gn.speaker_ids = str_list_from_any(d.get("speaker_ids", d.get("speakerIds", [])));
    gn.origin = str(d.get("origin", ""));
    gn.question = str(d.get("question", ""));
    gn.decision_status = str(d.get("status", d.get("decision_status", "")));
    gn.resolution_text = str(d.get("resolution_text", d.get("resolutionText", "")));
    gn.scope = str(d.get("scope", ""));
    gn.time_horizon = str(d.get("time_horizon", d.get("timeHorizon", "")));
    gn.option_status = str(d.get("option_status", d.get("optionStatus", "")));
    gn.evidence_kind = str(d.get("evidence_kind", d.get("evidenceKind", "")));
    gn.criterion_tags = str_list_from_any(d.get("criterion_tags", d.get("criterionTags", [])));
    gn.risk_kind = str(d.get("risk_kind", d.get("riskKind", "")));
    gn.severity = str(d.get("severity", ""));
    gn.is_blocker = bool_from_any(d.get("is_blocker", d.get("isBlocker", False)));
    gn.assumption_status = str(d.get("assumption_status", d.get("assumptionStatus", "")));
    gn.question_status = str(d.get("question_status", d.get("questionStatus", "")));
    gn.owner = owner;
    gn.owners = owner_list;
    gn.due_date = due_date;
    gn.priority = priority;
    gn.task_status = task_status;
    gn.action_status = str(d.get("action_status", d.get("actionStatus", task_status)));
    return gn;
}

"Convert a raw dict from LLM into a GraphEdge."
def dict_to_graphedge(d: dict[str, object]) -> GraphEdge {
    efrom = str(d.get("from_id", d.get("fromId", d.get("from", d.get("source", d.get("source_id", ""))))));
    eto = str(d.get("to_id", d.get("toId", d.get("to", d.get("target", d.get("target_id", ""))))));
    ekind = str(d.get("kind", d.get("type", d.get("edge_type", d.get("label", d.get("relation", d.get("role", "supports")))))));
    edge_role = normalize_business_edge_role(str(d.get("role", ekind)));
    raw_w = d.get("weight", d.get("strength", d.get("score", 0.5)));
    try {
        ew = float(raw_w);
    } except Exception {
        ew = 0.5;
    }
    raw_conf = d.get("confidence", ew);
    try {
        edge_conf = float(raw_conf);
    } except Exception {
        edge_conf = ew;
    }
    raw_rt = d.get("reasoning_type", d.get("reasoningType", d.get("reason_type", "inductive")));
    ert = str(raw_rt) if raw_rt else "inductive";

    ge = GraphEdge(from_id=efrom, to_id=eto);
    ge.label = ekind;
    ge.role = edge_role;
    ge.weight = ew;
    ge.confidence = edge_conf;
    ge.reasoning_type = ert;
    return ge;
}


# ============================================================
# 4. NORMALIZERS
# ============================================================

"Normalize node labels and statuses to expected values."
def normalize_nodes(nodes: list[GraphNode]) -> list[GraphNode] {
    type_map: dict[str, str] = {
        "thesis": "thesis", "claim": "claim",
        "supportingclaim": "claim", "supporting_claim": "claim",
        "sub_claim": "claim", "subclaim": "claim",
        "evidence": "evidence", "document": "evidence",
        "source": "evidence", "fact": "evidence", "statistic": "evidence",
        "assumption": "evidence", "premise": "evidence",
        "counterarg": "counterarg", "counterargument": "counterarg",
        "counter_argument": "counterarg", "counter": "counterarg",
        "rebuttal": "counterarg"
    };
    category_map: dict[str, str] = {
        "empirical_data": "empirical_data", "empirical": "empirical_data",
        "expert_testimony": "expert_testimony", "expert": "expert_testimony",
        "anecdotal": "anecdotal", "personal": "anecdotal",
        "logical_reasoning": "logical_reasoning", "logical": "logical_reasoning",
        "analogy": "analogy"
    };
    reasoning_type_map: dict[str, str] = {
        "deductive": "deductive", "inductive": "inductive",
        "causal": "causal", "correlational": "correlational",
        "analogical": "analogical"
    };
    status_map: dict[str, str] = {
        "ok": "ok", "valid": "ok", "strong": "ok",
        "stable": "ok", "supported": "ok",
        "needs_work": "needs_work", "weak": "needs_work",
        "unsupported": "needs_work", "rebutted": "needs_work",
        "missing": "missing", "none": "missing"
    };
    issue_map: dict[str, str] = {
        "unsupported_claim": "unsupported_claim",
        "missing_premise": "missing_premise",
        "contradiction": "contradiction",
        "vague_language": "vague_language",
        "limited_support": "unsupported_claim",
        "weak_support": "unsupported_claim",
        "unclear_methodology": "vague_language",
        "missing_evidence": "unsupported_claim",
        "weak_inference": "missing_premise",
        "ambiguity": "vague_language"
    };

    for n in nodes {
        # If LLM returned "assumption" type, convert to evidence and note the assumption
        old_label = n.label.lower().strip();
        if old_label in ["assumption", "premise"] and not n.assumptions {
            n.assumptions = [n.text];
        }
        n.label = type_map.get(old_label, "claim");
        n.status = status_map.get(n.status.lower().strip(), "needs_work");
        if not n.parent_id {
            n.parent_id = "";
        }
        # Normalize evidence category
        if n.evidence_category {
            n.evidence_category = category_map.get(n.evidence_category.lower().strip(), "logical_reasoning");
        } elif n.label == "evidence" {
            n.evidence_category = "logical_reasoning";
        }
        if n.role {
            n.role = normalize_business_node_role(n.role);
        }
        if n.semantic_role {
            n.semantic_role = normalize_business_node_role(n.semantic_role);
        }
        if not n.role and n.semantic_role {
            n.role = n.semantic_role;
        }
        if not n.role {
            if n.label == "thesis" {
                n.role = "DECISION";
            } elif n.label == "claim" {
                n.role = "OPTION";
            } elif n.label == "evidence" {
                n.role = "EVIDENCE";
            } elif n.label == "counterarg" {
                n.role = "RISK";
            }
        }
        if not n.semantic_role {
            n.semantic_role = n.role;
        }
        if len(n.owners) == 0 and n.owner {
            n.owners = [n.owner];
        }
        if not n.owner and len(n.owners) > 0 {
            n.owner = n.owners[0];
        }
        if not n.action_status and n.task_status {
            n.action_status = n.task_status;
        }
        if not n.task_status and n.action_status {
            n.task_status = n.action_status;
        }
        fixed: list[str] = [];
        for iss in n.issues {
            fixed.append(issue_map.get(iss.lower().strip(), iss.lower().strip()));
        }
        n.issues = fixed;
    }
    return nodes;
}

"Normalize edge labels to expected values."
def normalize_edges(edges: list[GraphEdge]) -> list[GraphEdge] {
    edge_map: dict[str, str] = {
        "supports": "supports", "support": "supports",
        "contradicts": "contradicts", "contradict": "contradicts",
        "counterarguments": "contradicts", "counterargument": "contradicts",
        "depends_on": "supports", "depends": "supports",
        "addresses": "addresses", "address": "addresses",
        "rebuts": "addresses", "rebuttal": "addresses"
    };
    reasoning_map: dict[str, str] = {
        "deductive": "deductive", "inductive": "inductive",
        "causal": "causal", "correlational": "correlational",
        "analogical": "analogical"
    };
    for e in edges {
        e.label = edge_map.get(e.label.lower().strip(), "supports");
        if e.role {
            e.role = normalize_business_edge_role(e.role);
        } else {
            e.role = normalize_business_edge_role(e.label);
        }
        if e.confidence <= 0.0 {
            e.confidence = e.weight;
        }
        e.reasoning_type = reasoning_map.get(e.reasoning_type.lower().strip(), "inductive");
    }
    return edges;
}

def trim_punctuation(text: str) -> str {
    cleaned = text.strip();
    while cleaned.endswith(".") or cleaned.endswith(",") or cleaned.endswith(";") {
        cleaned = cleaned[:-1].strip();
    }
    return cleaned;
}

def looks_like_person_name(token: str) -> bool {
    if not token or len(token) < 2 {
        return False;
    }
    first = token[0];
    if not first.isalpha() {
        return False;
    }
    return first == first.upper();
}

def extract_iso_date(text: str) -> str {
    safe_text = text.replace(".", " ").replace(",", " ").replace(";", " ").replace(")", " ").replace("(", " ");
    for token in safe_text.split() {
        if len(token) == 10 and token[4] == "-" and token[7] == "-" {
            year_ok = token[0:4].isdigit();
            month_ok = token[5:7].isdigit();
            day_ok = token[8:10].isdigit();
            if year_ok and month_ok and day_ok {
                return token;
            }
        }
    }
    return "";
}

def strip_business_prefix(text: str) -> str {
    cleaned = text.strip();
    lower = cleaned.lower();
    prefixes: list[str] = [
        "decision:", "risk:", "objection:", "blocker:",
        "open question:", "question:", "assumption:",
        "next action:", "action item:", "follow-up:"
    ];
    for prefix in prefixes {
        if lower.startswith(prefix) {
            cleaned = cleaned[len(prefix):].strip();
            lower = cleaned.lower();
            break;
        }
    }

    option_prefixes: list[str] = [
        "option a:", "option b:", "option c:", "option d:",
        "option a is ", "option b is ", "option c is ", "option d is ",
        "option a ", "option b ", "option c ", "option d "
    ];
    for prefix in option_prefixes {
        if lower.startswith(prefix) {
            cleaned = cleaned[len(prefix):].strip();
            lower = cleaned.lower();
            break;
        }
    }

    if lower.startswith("we need to decide whether ") {
        cleaned = cleaned[25:].strip();
        lower = cleaned.lower();
    } elif lower.startswith("we need to decide if ") {
        cleaned = cleaned[21:].strip();
        lower = cleaned.lower();
    } elif lower.startswith("decision still under discussion:") {
        cleaned = "Decision still under discussion";
        lower = cleaned.lower();
    }

    if lower.startswith("to ") and len(cleaned) > 3 {
        cleaned = cleaned[3:].strip();
        if cleaned {
            cleaned = cleaned[0].upper() + cleaned[1:];
        }
    }

    return trim_punctuation(cleaned);
}

def infer_business_role(node_data: GraphNode) -> str {
    if node_data.role {
        normalized = normalize_business_node_role(node_data.role);
        if normalized {
            return normalized;
        }
    }
    if node_data.semantic_role {
        normalized = normalize_business_node_role(node_data.semantic_role);
        if normalized {
            return normalized;
        }
    }

    lower = node_data.text.lower().strip();
    if node_data.owner or node_data.due_date or len(node_data.owners) > 0 {
        return "ACTION";
    }
    if lower.startswith("open question:") or lower.startswith("question:") or lower.endswith("?") {
        return "OPEN_QUESTION";
    }
    if lower.startswith("risk:") or lower.startswith("objection:") or lower.startswith("blocker:") or node_data.label == "counterarg" {
        return "RISK";
    }
    if lower.startswith("assumption:") {
        return "ASSUMPTION";
    }
    if lower.startswith("next action:") or lower.startswith("action item:") or lower.startswith("follow-up:") {
        return "ACTION";
    }
    if lower.startswith("option ") {
        return "OPTION";
    }
    if node_data.label == "thesis" {
        return "DECISION";
    }
    if node_data.label == "evidence" {
        return "EVIDENCE";
    }
    if node_data.label == "counterarg" {
        return "RISK";
    }
    return "OPTION";
}

def hydrate_business_action_fields(node_data: GraphNode) -> None {
    action_text = strip_business_prefix(node_data.text);
    if not node_data.owner {
        words = action_text.split();
        if len(words) >= 3 and looks_like_person_name(words[0]) and words[1].lower() == "will" {
            node_data.owner = trim_punctuation(words[0]);
            action_text = " ".join(words[2:]).strip();
        }
    }
    if len(node_data.owners) == 0 and node_data.owner {
        node_data.owners = [node_data.owner];
    }
    if not node_data.owner and len(node_data.owners) > 0 {
        node_data.owner = node_data.owners[0];
    }

    if not node_data.due_date {
        node_data.due_date = extract_iso_date(action_text);
    }
    if node_data.due_date {
        for prefix in [" by ", " before ", " on "] {
            needle = prefix + node_data.due_date;
            lower_text = action_text.lower();
            needle_lower = needle.lower();
            idx = lower_text.find(needle_lower);
            if idx >= 0 {
                action_text = (action_text[:idx] + action_text[idx + len(needle):]).strip();
                break;
            }
        }
    }

    action_text = trim_punctuation(action_text);
    if action_text {
        action_text = action_text[0].upper() + action_text[1:];
    }
    node_data.text = action_text;
    if not node_data.action_status {
        node_data.action_status = node_data.task_status if node_data.task_status else "open";
    }
    if not node_data.task_status {
        node_data.task_status = node_data.action_status;
    }
}

def new_business_edge_id(edges: list[GraphEdge]) -> str {
    max_num = 0;
    for e in edges {
        digits = "";
        for ch in (e.from_id + e.to_id + e.role) {
            if ch.isdigit() {
                digits = digits + ch;
            }
        }
        if digits {
            try {
                num = int(digits);
                if num > max_num {
                    max_num = num;
                }
            } except Exception {
                max_num = max_num;
            }
        }
    }
    return f"x{max_num + 1}";
}

def new_business_node_id(nodes: list[GraphNode]) -> str {
    max_num = 0;
    for n in nodes {
        nid = n.id.strip();
        digits = "";
        for ch in nid {
            if ch.isdigit() {
                digits = digits + ch;
            }
        }
        if digits {
            try {
                num = int(digits);
                if num > max_num {
                    max_num = num;
                }
            } except Exception {
                max_num = max_num;
            }
        }
    }
    return f"n{max_num + 1}";
}

def business_role_nodes(nodes: list[GraphNode], role: str) -> list[GraphNode] {
    result: list[GraphNode] = [];
    target = role.upper().strip();
    for n in nodes {
        if n.role == target or n.semantic_role == target {
            result.append(n);
        }
    }
    return result;
}

def business_edge_role(edge_data: GraphEdge) -> str {
    if edge_data.role {
        normalized = normalize_business_edge_role(edge_data.role);
        if normalized {
            return normalized;
        }
    }
    return normalize_business_edge_role(edge_data.label);
}

def has_edge_role(edges: list[GraphEdge], source_id: str, target_id: str, role: str) -> bool {
    target_role = normalize_business_edge_role(role);
    for e in edges {
        if e.from_id == source_id and e.to_id == target_id and business_edge_role(e) == target_role {
            return True;
        }
    }
    return False;
}

def normalize_business_graph(nodes: list[GraphNode], edges: list[GraphEdge]) -> tuple[list[GraphNode], list[GraphEdge], str, str] {
    for n in nodes {
        n.role = infer_business_role(n);
        n.semantic_role = n.role;
        n.text = strip_business_prefix(n.text);

        if n.role == "DECISION" {
            n.label = "thesis";
        } elif n.role == "EVIDENCE" {
            n.label = "evidence";
        } elif n.role == "RISK" {
            n.label = "counterarg";
        } else {
            n.label = "claim";
        }

        if n.role == "EVIDENCE" and not n.evidence_category {
            n.evidence_category = "logical_reasoning";
        }

        if n.role == "ACTION" {
            hydrate_business_action_fields(n);
        }

        if n.role == "OPEN_QUESTION" and n.text and not n.text.endswith("?") {
            n.text = trim_punctuation(n.text) + "?";
        }

        if n.role == "DECISION" {
            if not n.question {
                base_text = trim_punctuation(n.text);
                n.question = base_text if base_text.endswith("?") else ("Should we " + base_text.lower() + "?" if base_text else "");
            }
            if not n.decision_status {
                lower_text = n.text.lower();
                if "still under discussion" in lower_text or "to be decided" in lower_text {
                    n.decision_status = "open";
                } else {
                    n.decision_status = "tentative";
                }
            }
        } elif n.role == "OPTION" {
            if not n.option_status {
                n.option_status = "proposed";
            }
        } elif n.role == "EVIDENCE" {
            if not n.evidence_kind {
                n.evidence_kind = "unknown";
            }
        } elif n.role == "RISK" {
            if not n.risk_kind {
                n.risk_kind = "risk";
            }
        } elif n.role == "ASSUMPTION" {
            if not n.assumption_status {
                n.assumption_status = "implicit";
            }
        } elif n.role == "OPEN_QUESTION" {
            if not n.question_status {
                n.question_status = "open";
            }
        } elif n.role == "ACTION" {
            if not n.action_status {
                n.action_status = "open";
            }
            if not n.task_status {
                n.task_status = n.action_status;
            }
        }
    }

    decisions = business_role_nodes(nodes, "DECISION");
    if len(decisions) == 0 {
        fallback = GraphNode(id=new_business_node_id(nodes));
        fallback.label = "thesis";
        fallback.text = "Decision still under discussion";
        fallback.role = "DECISION";
        fallback.semantic_role = "DECISION";
        fallback.question = "What decision should the team make?";
        fallback.decision_status = "open";
        nodes.append(fallback);
        decisions = [fallback];
    } elif len(decisions) > 1 {
        di = 1;
        while di < len(decisions) {
            decisions[di].role = "OPTION";
            decisions[di].semantic_role = "OPTION";
            decisions[di].label = "claim";
            if not decisions[di].option_status {
                decisions[di].option_status = "proposed";
            }
            di = di + 1;
        }
        decisions = [decisions[0]];
    }

    decision_id = decisions[0].id;
    options = business_role_nodes(nodes, "OPTION");
    risks = business_role_nodes(nodes, "RISK");
    questions = business_role_nodes(nodes, "OPEN_QUESTION");
    assumptions = business_role_nodes(nodes, "ASSUMPTION");
    actions = business_role_nodes(nodes, "ACTION");
    evidence_nodes = business_role_nodes(nodes, "EVIDENCE");

    retained_edges: list[GraphEdge] = [];
    for e in edges {
        erole = business_edge_role(e);
        if erole {
            e.role = erole;
            e.label = erole.lower();
            if e.confidence <= 0.0 {
                e.confidence = e.weight if e.weight > 0.0 else 0.5;
            }
            retained_edges.append(e);
            continue;
        }
        if e.label in ["supports", "contradicts", "addresses"] {
            retained_edges.append(e);
        }
    }
    edges = retained_edges;

    for opt in options {
        has_parent_link = has_edge_role(edges, decision_id, opt.id, "HAS_OPTION");
        if not has_parent_link and opt.id != decision_id {
            fallback_edge = GraphEdge(from_id=decision_id, to_id=opt.id);
            fallback_edge.label = "has_option";
            fallback_edge.role = "HAS_OPTION";
            fallback_edge.reasoning_type = "inductive";
            edges.append(fallback_edge);
        }
    }

    primary_option_id = options[0].id if len(options) > 0 else decision_id;

    for ev in evidence_nodes {
        has_support_edge = False;
        for e in edges {
            if e.from_id == ev.id and business_edge_role(e) == "SUPPORTS" {
                has_support_edge = True;
                break;
            }
        }
        if not has_support_edge {
            fallback_edge = GraphEdge(from_id=ev.id, to_id=primary_option_id);
            fallback_edge.label = "supports";
            fallback_edge.role = "SUPPORTS";
            fallback_edge.reasoning_type = "inductive";
            edges.append(fallback_edge);
        }
    }

    for risk in risks {
        has_risk_edge = False;
        for e in edges {
            if e.from_id == risk.id and business_edge_role(e) == "OPPOSES" {
                has_risk_edge = True;
                break;
            }
        }
        if not has_risk_edge {
            fallback_edge = GraphEdge(from_id=risk.id, to_id=primary_option_id);
            fallback_edge.label = "opposes";
            fallback_edge.role = "OPPOSES";
            fallback_edge.reasoning_type = "causal";
            edges.append(fallback_edge);
        }
    }

    for assumption_node in assumptions {
        has_dependency_edge = False;
        for e in edges {
            if e.from_id == assumption_node.id and business_edge_role(e) == "DEPENDS_ON" {
                has_dependency_edge = True;
                break;
            }
        }
        if not has_dependency_edge {
            fallback_edge = GraphEdge(from_id=assumption_node.id, to_id=primary_option_id);
            fallback_edge.label = "depends_on";
            fallback_edge.role = "DEPENDS_ON";
            fallback_edge.reasoning_type = "deductive";
            edges.append(fallback_edge);
        }
    }

    for question_node in questions {
        has_block_edge = False;
        for e in edges {
            if e.from_id == question_node.id and business_edge_role(e) == "BLOCKS" {
                has_block_edge = True;
                break;
            }
        }
        if not has_block_edge {
            fallback_edge = GraphEdge(from_id=question_node.id, to_id=primary_option_id);
            fallback_edge.label = "blocks";
            fallback_edge.role = "BLOCKS";
            fallback_edge.reasoning_type = "causal";
            edges.append(fallback_edge);
        }
    }

    if len(actions) > 0 {
        action_target_id = questions[0].id if len(questions) > 0 else decision_id;
        for action_node in actions {
            has_action_edge = False;
            for e in edges {
                if e.from_id == action_node.id and business_edge_role(e) in ["RESOLVES", "IMPLEMENTS"] {
                    has_action_edge = True;
                    break;
                }
            }
            if not has_action_edge {
                fallback_edge = GraphEdge(from_id=action_node.id, to_id=action_target_id);
                if len(questions) > 0 {
                    fallback_edge.label = "resolves";
                    fallback_edge.role = "RESOLVES";
                } else {
                    fallback_edge.label = "implements";
                    fallback_edge.role = "IMPLEMENTS";
                }
                fallback_edge.reasoning_type = "causal";
                edges.append(fallback_edge);
            }
        }
    }

    option_count = len(options);
    risk_count = len(risks);
    question_count = len(questions);
    action_count = len(actions);
    graph_title = decisions[0].text if decisions[0].text else "Business meeting decision board";
    graph_summary = f"{option_count} option(s), {risk_count} risk(s), {question_count} open question(s), and {action_count} next action(s).";
    return (nodes, edges, graph_title, graph_summary);
}


# ============================================================
# 5. SCORING - Rule-based, NOT LLM
# ============================================================

# Calculate reasoning score from graph structure with evidence quality weighting.
def calculate_score(
    nodes: list[GraphNode],
    edges: list[GraphEdge]
) -> ReasoningScore {
    claims: list[GraphNode] = [n for n in nodes if n.label in ["claim", "thesis"]];
    total_claims = len(claims);

    if total_claims == 0 {
        return ReasoningScore();
    }

    # Evidence quality base weights by category
    category_weights: dict[str, float] = {
        "empirical_data": 0.9, "expert_testimony": 0.8,
        "logical_reasoning": 0.6, "analogy": 0.5, "anecdotal": 0.3
    };

    # Score each evidence node by category and assumptions
    evidence_nodes = [n for n in nodes if n.label == "evidence"];
    evidence_scores: dict[str, float] = {};
    for ev in evidence_nodes {
        base = category_weights.get(ev.evidence_category, 0.6);
        # Each unaddressed assumption reduces quality by 15%
        assumption_count = len(ev.assumptions) if ev.assumptions else 0;
        penalty = assumption_count * 0.15;
        quality = base - penalty;
        if quality < 0.1 { quality = 0.1; }
        evidence_scores[ev.id] = quality;
    }

    # --- Support coverage ---
    supported_ids: list[str] = [];
    for e in edges {
        if e.label == "supports" {
            supported_ids.append(e.to_id);
        }
    }
    supported_claims = len([c for c in claims if c.id in supported_ids]);
    support_pct = supported_claims / total_claims;

    thesis_nodes = [n for n in nodes if n.label == "thesis"];
    thesis_penalty = 0;
    if thesis_nodes {
        if thesis_nodes[0].id not in supported_ids {
            thesis_penalty = 15;
        }
    }

    # Penalty: low quality evidence supporting claims
    weak_evidence_penalty = 0;
    for c in claims {
        if c.id in supported_ids {
            # Get average quality of supporting evidence
            sup_qualities: list[float] = [];
            for e in edges {
                if e.to_id == c.id and e.label == "supports" {
                    q = evidence_scores.get(e.from_id, 0.5);
                    sup_qualities.append(q);
                }
            }
            if sup_qualities {
                avg_q = sum(sup_qualities) / len(sup_qualities);
                if avg_q < 0.4 {
                    weak_evidence_penalty = weak_evidence_penalty + 20;
                } elif avg_q < 0.6 {
                    weak_evidence_penalty = weak_evidence_penalty + 10;
                }
            }
        }
    }
    if weak_evidence_penalty > 40 { weak_evidence_penalty = 40; }

    # Penalty: thin support (only 1 evidence)
    thin_penalty = 0;
    for c in claims {
        sups: list[str] = [];
        for e in edges {
            if e.to_id == c.id and e.label == "supports" {
                sups.append(e.from_id);
            }
        }
        if len(sups) == 1 { thin_penalty = thin_penalty + 10; }
    }
    if thin_penalty > 20 { thin_penalty = 20; }

    support_score_val = max(0, int(support_pct * 100) - thesis_penalty - weak_evidence_penalty - thin_penalty);

    # --- Premise coverage ---
    # Claims with weak evidence quality are "weak premise"
    claims_missing = len([c for c in claims if "missing_premise" in c.issues]);
    claims_weak_premise = 0;
    for c in claims {
        if "missing_premise" not in c.issues {
            sup_qualities2: list[float] = [];
            for e in edges {
                if e.to_id == c.id and e.label == "supports" {
                    q2 = evidence_scores.get(e.from_id, 0.5);
                    sup_qualities2.append(q2);
                }
            }
            if sup_qualities2 {
                avg_q2 = sum(sup_qualities2) / len(sup_qualities2);
                if avg_q2 < 0.4 {
                    claims_weak_premise = claims_weak_premise + 1;
                }
            }
        }
    }
    total_premise_issues = claims_missing + claims_weak_premise;
    premise_score_val = int((1 - total_premise_issues / total_claims) * 100);
    if premise_score_val < 0 {
        premise_score_val = 0;
    }

    # --- Consistency ---
    counterargs = [n for n in nodes if n.label == "counterarg"];
    total_contras = len(counterargs);
    addressed_ids: list[str] = [];
    for e in edges {
        if e.label == "addresses" {
            addressed_ids.append(e.to_id);
        }
    }

    if total_contras > 0 {
        unresolved = len([ca for ca in counterargs if ca.id not in addressed_ids]);
        consistency_val = int((1 - unresolved / total_contras) * 100);
    } else {
        consistency_val = 100;
    }

    overall = int(0.4 * support_score_val + 0.4 * premise_score_val + 0.2 * consistency_val);

    thesis_ok = len(thesis_nodes) > 0 and thesis_nodes[0].id in supported_ids;
    unresolved_ct = len([ca for ca in counterargs if ca.id not in addressed_ids]);

    return ReasoningScore(
        overall=overall,
        support_coverage=support_score_val,
        premise_coverage=premise_score_val,
        consistency=consistency_val,
        passing=(overall >= 75 and thesis_ok and unresolved_ct <= 1)
    );
}


# ============================================================
# 6. MAIN PIPELINE (Optimized: 2 LLM calls)
# ============================================================

# Run the full pipeline: notes in, structured graph out.
def generate_argument_graph(
    raw_text: str,
    documents: list[Document] = [],
    existing_nodes: list[GraphNode] = [],
    existing_edges: list[GraphEdge] = [],
    mode: str = "education_argument",
    template: str = ""
) -> dict[str, object] {
    graph_mode = mode if mode else "education_argument";
    graph_template = template if template else ("business_meeting_decision" if graph_mode == "business_meeting_decision" else "");
    graph_title = "";
    graph_summary = "";
    schema_version = "";
    board_id = "";
    primary_decision_id = "";
    meeting_meta: dict[str, object] = {};

    # Step 1: Parse notes into nodes AND edges (single LLM call)
    t0 = time.time();
    print(f"  [Step 1/3] Parsing notes into graph structure...");
    raw_json = parse_notes_and_edges(raw_text, documents);
    if graph_mode == "business_meeting_decision" {
        print(f"  [Step 1/3] Using business meeting decision parser...");
        raw_json = parse_business_meeting_decision(raw_text, documents);
    }
    print(f"  [Step 1/3] Done in {time.time() - t0:.1f}s");
    parsed = safe_parse_json(raw_json);

    # Handle both list and dict responses
    raw_nodes_list = [];
    raw_edges_list = [];
    if isinstance(parsed, dict) {
        if "graphMode" in parsed and parsed["graphMode"] {
            graph_mode = str(parsed.get("graphMode", graph_mode));
        }
        if "graph_mode" in parsed and parsed["graph_mode"] {
            graph_mode = str(parsed.get("graph_mode", graph_mode));
        }
        if "template" in parsed and parsed["template"] {
            graph_template = str(parsed.get("template", graph_template));
        }
        schema_version = str(parsed.get("schema_version", parsed.get("schemaVersion", "")));
        board_id = str(parsed.get("board_id", parsed.get("boardId", "")));
        primary_decision_id = str(parsed.get("primary_decision_id", parsed.get("primaryDecisionId", "")));
        meeting_raw = parsed.get("meeting", {});
        if isinstance(meeting_raw, dict) {
            meeting_meta = meeting_raw;
        }
        graph_title = str(parsed.get("title", ""));
        graph_summary = str(parsed.get("summary", ""));
        raw_nodes_list = parsed.get("nodes", []);
        raw_edges_list = parsed.get("edges", []);
    } elif isinstance(parsed, list) {
        # Fallback: if LLM returns a list, treat it as nodes
        raw_nodes_list = parsed;
    }

    new_nodes: list[GraphNode] = [];
    for rd in raw_nodes_list {
        if isinstance(rd, dict) {
            new_nodes.append(dict_to_graphnode(rd));
        }
    }
    new_nodes = normalize_nodes(new_nodes);
    all_nodes = existing_nodes + new_nodes;

    new_edges: list[GraphEdge] = [];
    for rd in raw_edges_list {
        if isinstance(rd, dict) {
            new_edges.append(dict_to_graphedge(rd));
        }
    }
    new_edges = normalize_edges(new_edges);
    all_edges = existing_edges + new_edges;

    if graph_mode == "business_meeting_decision" {
        business_result = normalize_business_graph(all_nodes, all_edges);
        all_nodes = business_result[0];
        all_edges = business_result[1];
        if not graph_title {
            graph_title = business_result[2];
        }
        if not graph_summary {
            graph_summary = business_result[3];
        }
        if not schema_version {
            schema_version = "1.0";
        }
        if len(board_id) == 0 {
            board_id = f"board_{int(time.time())}";
        }
        if len(primary_decision_id) == 0 {
            decision_nodes = [n for n in all_nodes if n.role == "DECISION"];
            if len(decision_nodes) > 0 {
                primary_decision_id = decision_nodes[0].id;
            }
        }
    }

    analysis_dicts: list[dict[str, str]] = [];
    summary = GraphSummary();

    if graph_mode == "business_meeting_decision" {
        print(f"  [Step 2/3] Building decision board summary...");
        option_count = len([n for n in all_nodes if n.semantic_role == "OPTION"]);
        risk_count = len([n for n in all_nodes if n.semantic_role == "RISK"]);
        question_count = len([n for n in all_nodes if n.semantic_role == "OPEN_QUESTION"]);
        action_count = len([n for n in all_nodes if n.role == "ACTION" or n.semantic_role == "ACTION"]);
        if not graph_title {
            decision_nodes = [n for n in all_nodes if n.semantic_role == "DECISION"];
            if len(decision_nodes) > 0 {
                graph_title = decision_nodes[0].text;
            } else {
                graph_title = "Business meeting decision board";
            }
        }
        if not graph_summary {
            graph_summary = f"{option_count} option(s), {risk_count} risk(s), {question_count} open question(s), and {action_count} next action(s).";
        }
    } else {
        # Build JSON representations for critique call
        nj = json.dumps([{"id": n.id, "kind": n.label, "text": n.text, "parent_id": n.parent_id} for n in all_nodes]);
        issue_hints = build_issue_hints(all_nodes, all_edges);
        graph_meta = {
            "claim_ids": [n.id for n in all_nodes if n.label in ["claim", "thesis"]],
            "counterarg_ids": [n.id for n in all_nodes if n.label == "counterarg"],
            "strength_nodes": [n.id for n in all_nodes if n.label == "evidence"]
        };

        # Step 2: Brief analysis + summary (single LLM call)
        t1 = time.time();
        print(f"  [Step 2/3] Analyzing graph and generating summary...");
        raw_result = analyze_and_summarize_llm(nj, json.dumps(issue_hints), json.dumps(graph_meta));
        print(f"  [Step 2/3] Done in {time.time() - t1:.1f}s");
        parsed_result = safe_parse_json(raw_result);

        if isinstance(parsed_result, dict) {
            summary.top_issues = parsed_result.get("top_issues", []);
            summary.strength_nodes = parsed_result.get("strength_nodes", []);
            summary.improvement_nodes = parsed_result.get("improvement_nodes", []);
            raw_counters = parsed_result.get("counterarguments", []);
            if isinstance(raw_counters, list) {
                summary.suggested_counterarguments = raw_counters;
            }
        }
    }

    # Step 3: Calculate score (rule-based, no LLM)
    print(f"  [Step 3/3] Calculating score (rule-based)...");
    score = calculate_score(all_nodes, all_edges);
    print(f"  [Done] Total pipeline: {time.time() - t0:.1f}s | Nodes: {len(all_nodes)} | Edges: {len(all_edges)} | Score: {score.overall}");

    # Build output dicts
    node_dicts: list[dict[str, object]] = [];
    for n in all_nodes {
        nd: dict[str, object] = {
            "id": n.id, "type": n.label, "text": n.text,
            "parent_id": n.parent_id, "confidence": str(n.confidence),
            "status": n.status, "issues": ",".join(n.issues),
            "suggestions": ",".join(n.suggestions),
            "evidence_category": n.evidence_category,
            "assumptions": n.assumptions,
            "role": n.role,
            "semanticRole": n.semantic_role,
            "source_span_ids": n.source_span_ids,
            "speaker_ids": n.speaker_ids,
            "origin": n.origin,
            "question": n.question,
            "decision_status": n.decision_status,
            "resolution_text": n.resolution_text,
            "scope": n.scope,
            "time_horizon": n.time_horizon,
            "option_status": n.option_status,
            "evidence_kind": n.evidence_kind,
            "criterion_tags": n.criterion_tags,
            "risk_kind": n.risk_kind,
            "severity": n.severity,
            "is_blocker": n.is_blocker,
            "assumption_status": n.assumption_status,
            "question_status": n.question_status,
            "owner": n.owner,
            "owners": n.owners,
            "dueDate": n.due_date,
            "due_date": n.due_date,
            "priority": n.priority,
            "taskStatus": n.task_status,
            "task_status": n.task_status,
            "action_status": n.action_status
        };
        node_dicts.append(nd);
    }

    edge_dicts: list[dict[str, object]] = [];
    for e in all_edges {
        edge_type_out = e.label;
        if graph_mode == "business_meeting_decision" and e.role {
            edge_type_out = e.role;
        }
        ed: dict[str, object] = {
            "from_id": e.from_id, "to_id": e.to_id,
            "type": edge_type_out, "weight": str(e.weight),
            "role": e.role,
            "source_id": e.from_id,
            "target_id": e.to_id,
            "confidence": str(e.confidence),
            "reasoning_type": e.reasoning_type
        };
        edge_dicts.append(ed);
    }

    return {
        "graphMode": graph_mode,
        "graph_mode": graph_mode,
        "schema_version": schema_version,
        "board_id": board_id,
        "primary_decision_id": primary_decision_id,
        "meeting": meeting_meta,
        "template": graph_template,
        "title": graph_title,
        "summaryText": graph_summary,
        "nodes": node_dicts,
        "edges": edge_dicts,
        "analyses": analysis_dicts,
        "reasoning_score": {
            "overall": str(score.overall),
            "support_coverage": str(score.support_coverage),
            "premise_coverage": str(score.premise_coverage),
            "consistency": str(score.consistency),
            "passing": str(score.passing)
        },
        "summary": {
            "top_issues": summary.top_issues,
            "strength_nodes": summary.strength_nodes,
            "improvement_nodes": summary.improvement_nodes,
            "suggested_counterarguments": summary.suggested_counterarguments
        }
    };
}
