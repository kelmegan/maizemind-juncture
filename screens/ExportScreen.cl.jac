"""Export Screen"""

import from "@jac/runtime" { useNavigate, useLocation }
import from react { useContext }
import from "lucide-react" { Download, FileText, AlertTriangle, CheckCircle2, Copy }
import from "jspdf" { jsPDF }
import from ..screens.AppContext { getAppContext }
import from ..components.Alert { Alert }
import from ..components.Badge { Badge }
import from ..components.Button { Button }
import from ..components.Card { Card }
import from ..components.Header { Header }

def:pub ExportScreen(props: any) -> JsxElement {
    nav = useNavigate();
    location = useLocation();
    _AppCtx = getAppContext();
    ctx = useContext(_AppCtx);

    loc_state = location.state if location.state else {};

    has currentGraph: dict = None,
    currentScore: dict = None,
    currentIssues: list = [],
    currentNextActions: list = [],
    exportFormat: str = "text",
    copyStatus: str = "",
    saved: bool = False;

    def semanticRole(node_data: dict) -> str {
        role = str(node_data["role"]).upper() if "role" in node_data and node_data["role"] else "";
        if not role {
            role = str(node_data["semanticRole"]).upper() if "semanticRole" in node_data and node_data["semanticRole"] else "";
        }
        if role == "NEXT_ACTION" { role = "ACTION"; }
        if role { return role; }
        node_type = node_data["type"] if "type" in node_data else "";
        if node_type == "THESIS" { return "DECISION"; }
        if node_type == "EVIDENCE" { return "EVIDENCE"; }
        if node_type == "COUNTERARGUMENT" { return "RISK"; }
        return "OPTION";
    }

    def roleNodes(node_list: list, role: str) -> list {
        result: list = [];
        ni = 0;
        while ni < len(node_list) {
            if semanticRole(node_list[ni]) == role {
                result.append(node_list[ni]);
            }
            ni = ni + 1;
        }
        return result;
    }

    def firstOwnerText(node_data: dict) -> str {
        if not node_data { return ""; }
        if "owner" in node_data and node_data["owner"] {
            return str(node_data["owner"]);
        }
        if "owners" in node_data and node_data["owners"] {
            owner_candidates = node_data["owners"];
            try {
                if len(owner_candidates) > 0 and owner_candidates[0] {
                    return str(owner_candidates[0]);
                }
            } except Exception as e {
                return str(owner_candidates);
            }
        }
        return "";
    }

    async def loadGraphData() -> None {
        if "graph" in loc_state and loc_state["graph"] {
            currentGraph = loc_state["graph"];
            currentScore = loc_state["score"] if "score" in loc_state else None;
            currentIssues = loc_state["issues"] if "issues" in loc_state else [];
            currentNextActions = loc_state["nextActions"] if "nextActions" in loc_state else [];
            return;
        }
        graph_id = loc_state["graphId"] if "graphId" in loc_state else ctx.cachedGraphId;
        if graph_id {
            try {
                result = await root spawn GetGraphWithScoring(graphId=graph_id);
                data = result["reports"][0] if result["reports"] else {};
                if "graph" in data { currentGraph = data["graph"]; }
                if "score" in data { currentScore = data["score"]; }
                if "issues" in data { currentIssues = data["issues"]; }
                if "nextActions" in data { currentNextActions = data["nextActions"]; }
            } except Exception as e {
                print(f"ExportScreen load error: {e}");
            }
        }
    }

    can with entry {
        loadGraphData();
    }

    def generateOutlineText(includeFlags: bool) -> str {
        if not currentGraph { return ""; }
        nodes = currentGraph["nodes"] if "nodes" in currentGraph else [];
        edges = currentGraph["edges"] if "edges" in currentGraph else [];
        NL = chr(10);
        graph_mode = currentGraph["graph_mode"] if "graph_mode" in currentGraph and currentGraph["graph_mode"] else (currentGraph["graphMode"] if "graphMode" in currentGraph else "education_argument");

        if graph_mode == "business_meeting_decision" {
            decision_nodes = roleNodes(nodes, "DECISION");
            option_nodes = roleNodes(nodes, "OPTION");
            evidence_nodes = roleNodes(nodes, "EVIDENCE");
            risk_nodes = roleNodes(nodes, "RISK");
            assumption_nodes = roleNodes(nodes, "ASSUMPTION");
            question_nodes = roleNodes(nodes, "OPEN_QUESTION");
            action_nodes = roleNodes(nodes, "ACTION");

            out = "DECISION BOARD" + NL;
            out += "==================================================" + NL + NL;
            if "title" in currentGraph and currentGraph["title"] {
                out += "Title: " + currentGraph["title"] + NL;
            }
            if "summary" in currentGraph and currentGraph["summary"] {
                out += "Summary: " + currentGraph["summary"] + NL;
            }
            out += NL;

            decision_text = decision_nodes[0]["content"] if len(decision_nodes) > 0 and "content" in decision_nodes[0] else "Decision still under discussion";
            out += "DECISION" + NL;
            out += decision_text + NL + NL;

            if currentScore {
                out += "READINESS SCORE" + NL;
                overall_text = str(currentScore["overall"]) + "/100" if ("readinessStatus" not in currentScore or currentScore["readinessStatus"] != "DISCUSSION_ONLY") else "Discussion Only";
                out += f"Overall: {overall_text}" + NL;
                out += f"Status: {currentScore['readinessStatus'] if 'readinessStatus' in currentScore else 'NEEDS_FOLLOW_UP'}" + NL;
                out += NL;
            }

            def appendRoleSection(title: str, node_list: list, include_action_meta: bool = False) -> str {
                section = title + NL;
                if len(node_list) == 0 {
                    return section + "- None" + NL + NL;
                }
                ni = 0;
                while ni < len(node_list) {
                    node_item = node_list[ni];
                    line = "- " + (node_item["content"] if "content" in node_item else "");
                    if include_action_meta {
                        owner = firstOwnerText(node_item);
                        due = node_item["dueDate"] if "dueDate" in node_item else (node_item["due_date"] if "due_date" in node_item else "");
                        if owner or due {
                            meta_bits: list = [];
                            if owner { meta_bits.append("owner: " + owner); }
                            if due { meta_bits.append("due: " + due); }
                            line = line + " (" + ", ".join(meta_bits) + ")";
                        }
                    }
                    section += line + NL;
                    ni = ni + 1;
                }
                return section + NL;
            }

            out += appendRoleSection("OPTIONS", option_nodes);
            out += appendRoleSection("EVIDENCE", evidence_nodes);
            out += appendRoleSection("RISKS / OBJECTIONS", risk_nodes);
            out += appendRoleSection("ASSUMPTIONS", assumption_nodes);
            out += appendRoleSection("OPEN QUESTIONS", question_nodes);
            out += appendRoleSection("NEXT ACTIONS", action_nodes, True);

            if len(currentIssues) > 0 {
                out += "TOP BLOCKERS" + NL;
                bi = 0;
                blocker_count = len(currentIssues);
                if blocker_count > 3 { blocker_count = 3; }
                while bi < blocker_count {
                    out += "- " + (currentIssues[bi]["description"] if "description" in currentIssues[bi] else "") + NL;
                    bi = bi + 1;
                }
                out += NL;
            }

            return out;
        }

        node_map: dict = {};
        ni = 0;
        while ni < len(nodes) {
            node_map[nodes[ni]["id"]] = nodes[ni];
            ni = ni + 1;
        }

        def node_score_str(n: dict) -> str {
            if "nodeScore" in n { return f" [score: {n['nodeScore']}]"; }
            return "";
        }

        def get_supporters_of_type(target_id: str, ntype: str) -> str {
            out = "";
            ei = 0;
            while ei < len(edges) {
                e = edges[ei];
                if e["type"] == "SUPPORTS" and e["target"] == target_id {
                    src_id = e["source"] if "source" in e else "";
                    if src_id in node_map and node_map[src_id]["type"] == ntype {
                        out += src_id + ",";
                    }
                }
                ei = ei + 1;
            }
            return out;
        }

        def get_contradictors_of_type(target_id: str, ntype: str) -> str {
            out = "";
            ei = 0;
            while ei < len(edges) {
                e = edges[ei];
                if e["type"] == "CONTRADICTS" and e["target"] == target_id {
                    src_id = e["source"] if "source" in e else "";
                    if src_id in node_map and node_map[src_id]["type"] == ntype {
                        out += src_id + ",";
                    }
                }
                ei = ei + 1;
            }
            return out;
        }

        def get_addressers_of_type(target_id: str, ntype: str) -> str {
            out = "";
            ei = 0;
            while ei < len(edges) {
                e = edges[ei];
                if e["type"] == "ADDRESSES" and e["target"] == target_id {
                    src_id = e["source"] if "source" in e else "";
                    if src_id in node_map and node_map[src_id]["type"] == ntype {
                        out += src_id + ",";
                    }
                }
                ei = ei + 1;
            }
            return out;
        }

        def format_evidence_block(nid: str, indent: str) -> str {
            block = "";
            supporter_ids = get_supporters_of_type(nid, "EVIDENCE");
            if len(supporter_ids) > 0 {
                block += indent + "  Supporting Evidence:" + NL;
                parts = supporter_ids.split(",");
                pi = 0;
                while pi < len(parts) {
                    part = str(parts[pi]);
                    if part and part in node_map {
                        ev = node_map[part];
                        ev_cat = ev["evidence_category"] if "evidence_category" in ev else "";
                        cat_tag = f" ({ev_cat.replace('_', ' ')})" if ev_cat else "";
                        ev_src = ev["sourceUrl"] if "sourceUrl" in ev else "";
                        block += indent + "    - " + ev["content"] + cat_tag + node_score_str(ev) + NL;
                        if ev_src { block += indent + "      Source: " + ev_src + NL; }
                    }
                    pi = pi + 1;
                }
            } elif includeFlags {
                block += indent + "  ~ No supporting evidence" + NL;
            }
            return block;
        }

        def format_counter_block(nid: str, indent: str) -> str {
            block = "";
            counter_ids = get_contradictors_of_type(nid, "COUNTERARGUMENT");
            if len(counter_ids) > 0 {
                block += indent + "  Counterarguments:" + NL;
                parts = counter_ids.split(",");
                pi = 0;
                while pi < len(parts) {
                    part = str(parts[pi]);
                    if part and part in node_map {
                        ca = node_map[part];
                        block += indent + "    [X] " + ca["content"] + NL;
                        addr_claim_ids = get_addressers_of_type(part, "CLAIM");
                        addr_ev_ids = get_addressers_of_type(part, "EVIDENCE");
                        addr_ids = addr_claim_ids + addr_ev_ids;
                        addr_parts = addr_ids.split(",");
                        api = 0;
                        while api < len(addr_parts) {
                            ap = str(addr_parts[api]);
                            if ap and ap in node_map {
                                block += indent + "      -> Response: " + node_map[ap]["content"] + NL;
                            }
                            api = api + 1;
                        }
                    }
                    pi = pi + 1;
                }
            }
            return block;
        }

        def format_node_block(nid: str, indent: str, index: str) -> str {
            if nid not in node_map { return ""; }
            n = node_map[nid];
            content = n["content"] if "content" in n else "";
            assumptions = n["assumptions"] if "assumptions" in n else [];
            source = n["sourceUrl"] if "sourceUrl" in n else "";
            block = indent + index + content + node_score_str(n) + NL;
            ai = 0;
            while ai < len(assumptions) {
                block += indent + "  ~ Assumes: " + str(assumptions[ai]) + NL;
                ai = ai + 1;
            }
            if source { block += indent + "  Source: " + source + NL; }
            block += format_evidence_block(nid, indent);
            block += format_counter_block(nid, indent);
            return block;
        }

        thesis_id = "";
        ni = 0;
        while ni < len(nodes) {
            if nodes[ni]["type"] == "THESIS" { thesis_id = nodes[ni]["id"]; break; }
            ni = ni + 1;
        }

        out = "ARGUMENT OUTLINE" + NL;
        out += "==================================================" + NL + NL;

        if thesis_id and thesis_id in node_map {
            thesis = node_map[thesis_id];
            out += "THESIS" + node_score_str(thesis) + NL;
            out += thesis["content"] + NL + NL;

            thesis_ev_ids = get_supporters_of_type(thesis_id, "EVIDENCE");
            if len(thesis_ev_ids) > 0 {
                out += "  Direct Evidence:" + NL;
                parts = thesis_ev_ids.split(",");
                pi = 0;
                while pi < len(parts) {
                    part = str(parts[pi]);
                    if part and part in node_map {
                        out += "  - " + node_map[part]["content"] + node_score_str(node_map[part]) + NL;
                    }
                    pi = pi + 1;
                }
                out += NL;
            }

            thesis_claim_ids_str = get_supporters_of_type(thesis_id, "CLAIM");

            all_claim_ids_str = thesis_claim_ids_str;
            ni = 0;
            while ni < len(nodes) {
                if nodes[ni]["type"] == "CLAIM" {
                    cid = nodes[ni]["id"];
                    if all_claim_ids_str.indexOf(cid + ",") == -1 {
                        all_claim_ids_str += cid + ",";
                    }
                }
                ni = ni + 1;
            }

            if len(all_claim_ids_str) > 0 {
                out += "SUPPORTING CLAIMS:" + NL + NL;
                claim_parts = all_claim_ids_str.split(",");
                ci = 0;
                seen_claims = "";
                while ci < len(claim_parts) {
                    cid = str(claim_parts[ci]);
                    if cid and cid in node_map and seen_claims.indexOf(cid + ",") == -1 {
                        seen_claims += cid + ",";
                        out += format_node_block(cid, "", f"{ci + 1}. ");
                        sub_ids = get_supporters_of_type(cid, "CLAIM");
                        if len(sub_ids) > 0 {
                            out += "   Sub-Claims:" + NL;
                            sub_parts = sub_ids.split(",");
                            si = 0;
                            while si < len(sub_parts) {
                                sp = str(sub_parts[si]);
                                if sp and sp in node_map {
                                    out += format_node_block(sp, "   ", f"{chr(97 + si)}. ");
                                }
                                si = si + 1;
                            }
                        }
                        out += NL;
                    }
                    ci = ci + 1;
                }
            }

            thesis_counter_ids = get_contradictors_of_type(thesis_id, "COUNTERARGUMENT");
            if len(thesis_counter_ids) > 0 {
                out += "COUNTERARGUMENTS TO THESIS:" + NL + NL;
                parts = thesis_counter_ids.split(",");
                pi = 0;
                while pi < len(parts) {
                    part = str(parts[pi]);
                    if part and part in node_map {
                        out += "  [X] " + node_map[part]["content"] + NL;
                        resp_claim_ids = get_addressers_of_type(part, "CLAIM");
                        resp_ev_ids = get_addressers_of_type(part, "EVIDENCE");
                        resp_ids = resp_claim_ids + resp_ev_ids;
                        resp_parts = resp_ids.split(",");
                        ri = 0;
                        while ri < len(resp_parts) {
                            rp = str(resp_parts[ri]);
                            if rp and rp in node_map {
                                out += "    -> Response: " + node_map[rp]["content"] + NL;
                            }
                            ri = ri + 1;
                        }
                        out += NL;
                    }
                    pi = pi + 1;
                }
            }
        }

        out += "==================================================" + NL;
        if currentScore {
            overall = currentScore["overall"] if "overall" in currentScore else 0;
            support = currentScore["rootSupportCoverage"] if "rootSupportCoverage" in currentScore else (currentScore["support"] if "support" in currentScore else 0);
            evidence_quality = currentScore["evidenceQuality"] if "evidenceQuality" in currentScore else (currentScore["premise"] if "premise" in currentScore else 0);
            dialectic = currentScore["dialecticalHandling"] if "dialecticalHandling" in currentScore else (currentScore["counterargument"] if "counterargument" in currentScore else 0);
            coherence = currentScore["structuralCoherence"] if "structuralCoherence" in currentScore else (currentScore["coherence"] if "coherence" in currentScore else 0);
            assumptions = currentScore["assumptionExplicitness"] if "assumptionExplicitness" in currentScore else 0;
            thesis_clarity = currentScore["thesisClarity"] if "thesisClarity" in currentScore else 0;
            out += f"Overall Score:              {overall}/100" + NL;
            out += f"Root Support Coverage (25%): {support}%" + NL;
            out += f"Evidence Quality (20%):      {evidence_quality}%" + NL;
            out += f"Dialectical Handling (20%):  {dialectic}%" + NL;
            out += f"Structural Coherence (15%):  {coherence}%" + NL;
            out += f"Assumption Explicitness (10%): {assumptions}%" + NL;
            out += f"Thesis Clarity (10%):        {thesis_clarity}%" + NL;
        }

        return out;
    }

    def handleCopyOutline() -> None {
        show_flags = currentScore["overall"] < 80;
        outline_text = generateOutlineText(show_flags);
        navigator.clipboard.writeText(outline_text)
            .then(lambda _: any -> None {
                copyStatus = "success";
                setTimeout(lambda -> None { copyStatus = ""; }, 3000);
            })
            .catch(lambda _: any -> None {
                copyStatus = "failure";
                setTimeout(lambda -> None { copyStatus = ""; }, 3000);
            });
    }

    def handleExportPDF() -> None {
        show_flags = currentScore["overall"] < 80;
        outline = generateOutlineText(show_flags);
        doc = Reflect.construct(jsPDF, []);
        margin = 10;
        page_width = doc.internal.pageSize.getWidth();
        usable_width = page_width - (margin * 2);
        doc.setFont("courier", "normal");
        doc.setFontSize(10);
        y = margin;
        line_height = 5;
        for raw_line in outline.split(chr(10)) {
            wrapped = doc.splitTextToSize(raw_line, usable_width);
            for segment in wrapped {
                if y + line_height > doc.internal.pageSize.getHeight() - margin {
                    doc.addPage();
                    y = margin;
                }
                doc.text(segment, margin, y);
                y += line_height;
            }
        }
        doc.save("argument-outline.pdf");
        copyStatus = "pdf-success";
        setTimeout(lambda -> None { copyStatus = ""; }, 3000);
    }

    def handleFixTopIssues() -> None {
        if not currentGraph { return; }
        nav("/review", {"state": {"graphId": currentGraph["id"] if "id" in currentGraph else ""}});
    }

    async def handleSaveSession() -> None {
        if not ctx.userId or not ctx.isLoggedIn or saved { return; }
        graphId = currentGraph["id"] if currentGraph and "id" in currentGraph else "";
        await root spawn CreateSession(
            userId=ctx.userId,
            graphId=graphId,
            notes="",
            score=currentScore
        );
        saved = True;
    }

    if not currentGraph or not currentScore {
        return (
            <div className="export-loading">
                <p>No data available. Please generate an argument map first.</p>
                <Button label="Go to Generate" onClick={lambda -> None { nav("/generate"); }} />
            </div>
        );
    }

    graph_mode = currentGraph["graph_mode"] if "graph_mode" in currentGraph and currentGraph["graph_mode"] else (currentGraph["graphMode"] if "graphMode" in currentGraph else "education_argument");
    is_business_mode = graph_mode == "business_meeting_decision";
    show_warning = currentScore["overall"] < (85 if is_business_mode else 80);
    unsupported_claims = currentScore["unsupportedClaims"] if "unsupportedClaims" in currentScore else 0;
    fix_count = unsupported_claims;
    if fix_count > 3 { fix_count = 3; }
    if fix_count < 1 { fix_count = min(3, len(currentIssues)); }
    if fix_count < 1 { fix_count = 1; }

    outline_text = generateOutlineText(show_warning);

    return (
        <div className="export-page">
            <Header screen="export" title="Export" backTo="/review" />

            {(
                <Alert className="export-alert-success">
                    <CheckCircle2 className="export-alert-success-icon" />
                    <p className="export-alert-success-text">Outline copied to clipboard successfully!</p>
                </Alert>
            ) if copyStatus == "success" else (
                <Alert className="export-alert-warning">
                    <AlertTriangle className="export-alert-warning-icon" />
                    <p>Copy to clipboard failed. Please try again.</p>
                </Alert>
            ) if copyStatus == "failure" else (
                <Alert className="export-alert-success">
                    <CheckCircle2 className="export-alert-success-icon" />
                    <p className="export-alert-success-text">Outline downloaded successfully!</p>
                </Alert>
            ) if copyStatus == "pdf-success" else (
                <Alert className="export-alert-warning">
                    <AlertTriangle className="export-alert-warning-icon" />
                    <p>Download failed. Please try again.</p>
                </Alert>
            ) if copyStatus == "pdf-failure" else None}

            <div className="export-content">
                <Card
                    title={
                        <div className="export-score-header">
                            <span>{"Decision Readiness" if is_business_mode else "Final Score"}</span>
                            <Badge
                                variant={"default" if currentScore["overall"] >= (85 if is_business_mode else 80) else "destructive"}
                                className="export-score-badge"
                            >
                                {currentScore["overall"]}/100{(" · " + currentScore["readinessStatus"]) if is_business_mode and "readinessStatus" in currentScore else ""}
                            </Badge>
                        </div>
                    }
                    description={"Your decision board is structured enough to share with the team."
                        if is_business_mode and currentScore["overall"] >= 85 else
                        "Your decision board still needs follow-up before sharing."
                        if is_business_mode else
                        "Your argument is well-structured and ready to export!"
                        if currentScore["overall"] >= 80 else
                        "Your argument could be improved before exporting."}
                />

                {(
                    <Alert className="export-alert-success">
                        <CheckCircle2 className="export-alert-success-icon" />
                        <p className="export-alert-success-text">Great work! Your argument is ready to export.</p>
                    </Alert>
                ) if not show_warning else (
                    <Alert className="export-alert-warning">
                        <AlertTriangle className="export-alert-warning-icon" />
                        <div>
                            <p>
                                {"Export now, but this decision still has unresolved blockers or follow-up gaps. Want to fix the top issues first?"
                                    if is_business_mode else
                                    "Export now, but " + str(unsupported_claims) + " claims are unsupported. Want to fix the top " + str(fix_count) + " issues first?"}
                            </p>
                            <div style={{"marginTop": "10px"}}>
                                <Button label="Fix Top Issues First" variant="outline" onClick={handleFixTopIssues} />
                            </div>
                        </div>
                    </Alert>
                )}

                <Card title="Outline Preview">
                    <pre className="export-preview">
                        {outline_text}
                    </pre>
                </Card>

                <Card title="Export Options">
                    <div className="export-options-body">
                        <div className="export-options-grid">
                            <Button label={(<><Copy className="export-btn-icon" />Copy Outline</>)} variant="outline" onClick={handleCopyOutline} />
                            <Button label={(<><Download className="export-btn-icon" />Download PDF</>)} variant="outline" onClick={handleExportPDF} />
                        </div>
                        {<Button
                            label={(<><FileText className="export-btn-icon-sm" />{("Saved!" if saved else "Save to History")}</>)}
                            onClick={handleSaveSession}
                            disabled={saved or not ctx.userId}
                            className="export-save-btn"
                        /> if ctx.isLoggedIn else None}
                    </div>
                </Card>
            </div>
        </div>
    );
}
