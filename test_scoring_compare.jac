"""Compare legacy and current scoring on static graph fixtures.
Run with: jac run test_scoring_compare.jac
"""

import json;
import time;
import from graph.argument_graph_nodes { ArgumentGraph }
import from walkers.graph_generate_walkers { GetGraphWithScoring }

with entry {
    fixture_paths: list[str] = [
        "samples/scoring_compare/education_balanced.json",
        "samples/scoring_compare/education_fragmented.json",
        "samples/scoring_compare/business_decision_board.json"
    ];

    scorer = GetGraphWithScoring(graphId="score_compare");
    report_rows: list[dict] = [];

    print("=== Scoring Comparison Harness ===");
    print("Comparing current working-tree scoring against the legacy education scorer.\n");

    for fixture_path in fixture_paths {
        fixture: dict = {};
        with open(fixture_path, "r") as f {
            loaded_fixture = json.load(f);
            if isinstance(loaded_fixture, dict) {
                fixture = loaded_fixture;
            }
        }

        graph_id: str = str(fixture["id"]) if "id" in fixture else f"fixture_{int(time.time())}";
        raw_graph_mode = fixture["graph_mode"] if "graph_mode" in fixture else (fixture["graphMode"] if "graphMode" in fixture else "education_argument");
        graph_mode: str = str(raw_graph_mode);
        graph_title: str = str(fixture["title"]) if "title" in fixture else graph_id;
        graph_summary: str = str(fixture["summary"]) if "summary" in fixture else "";
        primary_decision_id: str = str(fixture["primary_decision_id"]) if "primary_decision_id" in fixture else "";
        raw_nodes = fixture["nodes"] if "nodes" in fixture else [];
        raw_edges = fixture["edges"] if "edges" in fixture else [];
        raw_meeting = fixture["meeting"] if "meeting" in fixture else {};
        graph_nodes: list = [];
        graph_edges: list = [];
        graph_meeting: dict = {};
        if isinstance(raw_nodes, list) {
            graph_nodes = raw_nodes;
        }
        if isinstance(raw_edges, list) {
            graph_edges = raw_edges;
        }
        if isinstance(raw_meeting, dict) {
            graph_meeting = raw_meeting;
        }
        graph_schema_version: str = str(fixture["schema_version"]) if "schema_version" in fixture else "";
        graph_board_id: str = str(fixture["board_id"]) if "board_id" in fixture else graph_id;
        graph_template: str = str(fixture["template"]) if "template" in fixture else "";

        graph_node = (root ++> ArgumentGraph(
            id=graph_id,
            nodes=graph_nodes,
            edges=graph_edges,
            graphMode=graph_mode,
            graph_mode=graph_mode,
            schema_version=graph_schema_version,
            board_id=graph_board_id,
            primary_decision_id=primary_decision_id,
            meeting=graph_meeting,
            template=graph_template,
            title=graph_title,
            summary=graph_summary,
            createdAt=str(int(time.time())),
            updatedAt=str(int(time.time()))
        ))[0];

        comparison_raw = scorer.compare_score_versions(graph_node);
        comparison: dict = {};
        if isinstance(comparison_raw, dict) {
            comparison = comparison_raw;
        }
        raw_current = comparison["current"] if "current" in comparison else {};
        current_block: dict = {};
        if isinstance(raw_current, dict) {
            current_block = raw_current;
        }
        raw_current_score = current_block["score"] if "score" in current_block else {};
        raw_current_issues = current_block["issues"] if "issues" in current_block else [];
        raw_current_actions = current_block["nextActions"] if "nextActions" in current_block else [];
        current_score: dict = {};
        current_issues: list = [];
        current_actions: list = [];
        if isinstance(raw_current_score, dict) {
            current_score = raw_current_score;
        }
        if isinstance(raw_current_issues, list) {
            current_issues = raw_current_issues;
        }
        if isinstance(raw_current_actions, list) {
            current_actions = raw_current_actions;
        }
        current_issue_types: list[str] = [];
        ci: int = 0;
        while ci < len(current_issues) and ci < 5 {
            if isinstance(current_issues[ci], dict) {
                current_issue = current_issues[ci];
                current_issue_types.append(str(current_issue["type"]) if "type" in current_issue else "");
            }
            ci = ci + 1;
        }

        print(f"=== {graph_title} ===");
        print(f"Fixture: {fixture_path}");
        graph_mode_display = str(comparison["graphMode"]) if "graphMode" in comparison else graph_mode;
        current_overall_display = str(current_score["overall"]) if "overall" in current_score else "n/a";
        print(f"Mode: {graph_mode_display}");
        print(f"Current overall: {current_overall_display}");
        print(f"Current issues: {len(current_issues)} | Current next actions: {len(current_actions)}");

        row = {
            "fixture": fixture_path,
            "title": graph_title,
            "graphMode": graph_mode_display,
            "current": {
                "score": current_score,
                "issueCount": len(current_issues),
                "nextActionCount": len(current_actions),
                "topIssueTypes": current_issue_types
            }
        };

        if "legacyAvailable" in comparison and comparison["legacyAvailable"] == True {
            raw_legacy = comparison["legacy"] if "legacy" in comparison else {};
            legacy_block: dict = {};
            if isinstance(raw_legacy, dict) {
                legacy_block = raw_legacy;
            }
            raw_legacy_score = legacy_block["score"] if "score" in legacy_block else {};
            raw_legacy_issues = legacy_block["issues"] if "issues" in legacy_block else [];
            raw_legacy_actions = legacy_block["nextActions"] if "nextActions" in legacy_block else [];
            raw_delta = comparison["delta"] if "delta" in comparison else {};
            legacy_score: dict = {};
            legacy_issues: list = [];
            legacy_actions: list = [];
            delta: dict = {};
            if isinstance(raw_legacy_score, dict) {
                legacy_score = raw_legacy_score;
            }
            if isinstance(raw_legacy_issues, list) {
                legacy_issues = raw_legacy_issues;
            }
            if isinstance(raw_legacy_actions, list) {
                legacy_actions = raw_legacy_actions;
            }
            if isinstance(raw_delta, dict) {
                delta = raw_delta;
            }
            legacy_issue_types: list[str] = [];
            li: int = 0;
            while li < len(legacy_issues) and li < 5 {
                if isinstance(legacy_issues[li], dict) {
                    legacy_issue = legacy_issues[li];
                    legacy_issue_types.append(str(legacy_issue["type"]) if "type" in legacy_issue else "");
                }
                li = li + 1;
            }

            legacy_overall_display = str(legacy_score["overall"]) if "overall" in legacy_score else "n/a";
            delta_overall_display = int(delta["overall"]) if "overall" in delta else 0;
            delta_issue_display = int(delta["issueCount"]) if "issueCount" in delta else 0;
            delta_pass_bar = delta["passesBarChanged"] if "passesBarChanged" in delta else False;

            print(f"Legacy overall: {legacy_overall_display}");
            print(f"Legacy issues: {len(legacy_issues)} | Legacy next actions: {len(legacy_actions)}");
            print(f"Delta overall: {delta_overall_display}");
            print(f"Delta issue count: {delta_issue_display}");
            print(f"Pass bar changed: {delta_pass_bar}");

            row["legacy"] = {
                "score": legacy_score,
                "issueCount": len(legacy_issues),
                "nextActionCount": len(legacy_actions),
                "topIssueTypes": legacy_issue_types
            };
            row["delta"] = delta;
        } else {
            legacy_note = str(comparison["legacyNote"]) if "legacyNote" in comparison else "Legacy comparison unavailable.";
            print(legacy_note);
            row["legacy"] = None;
            row["delta"] = {};
            row["legacyNote"] = legacy_note;
        }

        report_rows.append(row);
        print("");
    }

    with open("scoring_compare_report.json", "w") as f {
        json.dump(report_rows, f, indent=2);
    }

    print("Saved comparison report to scoring_compare_report.json");
}
