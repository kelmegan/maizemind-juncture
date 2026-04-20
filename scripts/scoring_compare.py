#!/usr/bin/env python3
"""Standalone legacy-vs-current scoring comparator.

This script compares the old education scorer and the current scorer on
static graph JSON fixtures without depending on the Jac runtime.

Usage:
  python3 scripts/scoring_compare.py
  python3 scripts/scoring_compare.py samples/scoring_compare/education_balanced.json
  python3 scripts/scoring_compare.py samples/scoring_compare --output tmp/report.json
  python3 scripts/scoring_compare.py samples/scoring_compare --strict --benchmark-runs 25
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from time import perf_counter
from typing import Any


STOPWORDS = {
    "the",
    "and",
    "for",
    "with",
    "this",
    "that",
    "from",
    "into",
    "have",
    "will",
    "been",
    "only",
    "than",
    "then",
    "they",
    "their",
    "our",
    "your",
    "about",
    "because",
}


def clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))


def to_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except Exception:
        return default


def node_text(node: dict[str, Any]) -> str:
    return str(node.get("content", node.get("text", ""))).strip()


def get_node(nodes: list[dict[str, Any]], node_id: str) -> dict[str, Any] | None:
    for node in nodes:
        if node.get("id", "") == node_id:
            return node
    return None


def get_claims(nodes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [n for n in nodes if n.get("type", "") in ["CLAIM", "THESIS"]]


def semantic_role(node: dict[str, Any] | None) -> str:
    if not node:
        return ""
    role = str(node.get("role", node.get("semanticRole", ""))).upper().strip()
    if role == "NEXT_ACTION":
        role = "ACTION"
    if role:
        return role
    ntype = str(node.get("type", "")).upper().strip()
    if ntype == "THESIS":
        return "DECISION"
    if ntype == "EVIDENCE":
        return "EVIDENCE"
    if ntype == "COUNTERARGUMENT":
        return "RISK"
    return "OPTION"


def edge_role(edge: dict[str, Any] | None) -> str:
    if not edge:
        return ""
    role = str(edge.get("role", edge.get("type", ""))).upper().strip()
    if role == "CONTRADICTS":
        return "OPPOSES"
    if role == "ADDRESSES":
        return "RESOLVES"
    return role


def nodes_with_role(nodes: list[dict[str, Any]], role: str) -> list[dict[str, Any]]:
    target = role.upper().strip()
    return [n for n in nodes if semantic_role(n) == target]


def target_ids_for_edge_role(edges: list[dict[str, Any]], source_id: str, role: str) -> list[str]:
    target_role = role.upper().strip()
    result: list[str] = []
    for edge in edges:
        if edge.get("source", "") == source_id and edge_role(edge) == target_role:
            result.append(str(edge.get("target", "")))
    return result


def source_ids_for_edge_role(edges: list[dict[str, Any]], target_id: str, role: str) -> list[str]:
    target_role = role.upper().strip()
    result: list[str] = []
    for edge in edges:
        if edge.get("target", "") == target_id and edge_role(edge) == target_role:
            result.append(str(edge.get("source", "")))
    return result


def node_degree(edges: list[dict[str, Any]], node_id: str) -> int:
    deg = 0
    for edge in edges:
        if edge.get("source", "") == node_id or edge.get("target", "") == node_id:
            deg += 1
    return deg


def edge_weight(edge: dict[str, Any]) -> float:
    return clamp01(to_float(edge.get("weight", 0.5), 0.5))


def is_acknowledged(node: dict[str, Any] | None) -> bool:
    if not node:
        return False
    ack = node.get("acknowledged", False)
    if isinstance(ack, str):
        return ack.lower() == "true"
    return bool(ack)


def has_issue_type(node: dict[str, Any] | None, issue_type: str) -> bool:
    if not node:
        return False
    target = issue_type.lower().strip()

    llm_issue_types = node.get("llmIssueTypes", [])
    if isinstance(llm_issue_types, str) and llm_issue_types:
        llm_issue_types = [s.strip() for s in llm_issue_types.split(",")]
    if isinstance(llm_issue_types, list):
        for item in llm_issue_types:
            if str(item).lower().strip() == target:
                return True

    node_issues = node.get("issues", [])
    if isinstance(node_issues, str) and node_issues:
        for raw in node_issues.split(","):
            if raw.lower().strip() == target:
                return True
    elif isinstance(node_issues, list):
        for issue in node_issues:
            if isinstance(issue, dict):
                if str(issue.get("type", "")).lower().strip() == target:
                    return True
            elif str(issue).lower().strip() == target:
                return True
    return False


def has_numeric_signal(text: str) -> bool:
    return any("0" <= ch <= "9" for ch in text)


def text_has_any(text: str, keywords: list[str]) -> bool:
    li = str(text).lower()
    return any(keyword.lower() in li for keyword in keywords)


def normalized_text_signature(text: str) -> str:
    sig = str(text).lower()
    for token in [",", ".", ";", ":", "(", ")", "/", "-", "?", "!", '"', "'"]:
        sig = sig.replace(token, " ")
    return " ".join(tok for tok in sig.split(" ") if tok.strip())


def token_list(text: str) -> list[str]:
    raw = normalized_text_signature(text).split(" ")
    return [tok.strip() for tok in raw if tok.strip() and tok.strip() not in STOPWORDS]


def token_overlap_ratio(text_a: str, text_b: str) -> float:
    toks_a = token_list(text_a)
    toks_b = token_list(text_b)
    if not toks_a or not toks_b:
        return 0.0
    matched: set[str] = set()
    overlap = 0
    for tok in toks_a:
        if tok in toks_b and tok not in matched:
            matched.add(tok)
            overlap += 1
    denom = min(len(toks_a), len(toks_b))
    return clamp01(overlap / max(1, denom))


def node_specificity_score(node: dict[str, Any] | None) -> float:
    if not node:
        return 0.0
    text = node_text(node)
    if not text:
        return 0.0
    score = 0.35
    words = token_list(text)
    if len(words) >= 5:
        score += 0.20
    if len(words) >= 9:
        score += 0.10
    if has_numeric_signal(text):
        score += 0.15
    if text_has_any(
        text.lower(),
        ["because", "whether", "should", "launch", "pilot", "reduce", "increase", "compare", "legal", "compliance", "customer", "cost", "timeline"],
    ):
        score += 0.12
    if text_has_any(text.lower(), ["something", "stuff", "things", "better", "good", "bad", "issue", "problem"]):
        score -= 0.12
    return clamp01(score)


def evidence_quality_current(node: dict[str, Any]) -> float:
    if node.get("type", "") != "EVIDENCE":
        return 0.0

    ev_cat = str(node.get("evidence_category", "")).lower().strip()
    ev_kind = str(node.get("evidence_kind", "")).lower().strip()
    content = node_text(node)
    source_url = str(node.get("sourceUrl", "")).strip()
    source_spans = node.get("source_span_ids", [])
    speaker_ids = node.get("speaker_ids", [])
    conf = clamp01(to_float(node.get("confidence", 0.5), 0.5))

    source_quality = 0.35
    if source_url:
        source_quality = 1.0
    elif isinstance(source_spans, list) and source_spans:
        source_quality = 0.8
    elif ev_kind in ["metric", "fact", "precedent"] or ev_cat in ["empirical_data", "expert_testimony"]:
        source_quality = 0.75
    elif isinstance(speaker_ids, list) and speaker_ids:
        source_quality = 0.6
    elif ev_kind == "stakeholder_observation" or ev_cat == "anecdotal":
        source_quality = 0.45

    specificity = 0.2
    if has_numeric_signal(content):
        specificity += 0.35
    if text_has_any(content.lower(), ["%", "increase", "decrease", "timeline", "quarter", "month", "week", "year", "deadline", "pilot", "study", "report", "review", "survey", "data"]):
        specificity += 0.25
    if text_has_any(content.lower(), ["because", "compared", "versus", "vs", "already", "completed", "cost", "legal", "compliance", "customer"]):
        specificity += 0.20
    specificity = clamp01(specificity)

    traceability = 0.0
    if source_url:
        traceability = 1.0
    elif isinstance(source_spans, list) and source_spans:
        traceability = 0.8
    elif isinstance(speaker_ids, list) and speaker_ids:
        traceability = 0.5

    assumptions = node.get("assumptions", [])
    assumption_count = len(assumptions) if isinstance(assumptions, list) else 0
    assumption_penalty = min(0.18, assumption_count * 0.04)

    quality = (
        0.40 * source_quality
        + 0.25 * specificity
        + 0.20 * traceability
        + 0.15 * conf
        - assumption_penalty
    )
    return clamp01(quality)


def evidence_quality_legacy(node: dict[str, Any]) -> float:
    if node.get("type", "") != "EVIDENCE":
        return 0.0
    cat_weights = {
        "empirical_data": 0.92,
        "expert_testimony": 0.82,
        "logical_reasoning": 0.65,
        "analogy": 0.52,
        "anecdotal": 0.38,
    }
    ev_cat = str(node.get("evidence_category", "logical_reasoning")).lower().strip()
    base = cat_weights.get(ev_cat, 0.65)
    conf = clamp01(to_float(node.get("confidence", 0.5), 0.5))
    assumptions = node.get("assumptions", [])
    assumption_count = len(assumptions) if isinstance(assumptions, list) else 0
    assumption_penalty = min(0.25, assumption_count * 0.05)
    source_bonus = 0.08 if str(node.get("sourceUrl", "")).strip() else 0.0
    return clamp01(base * 0.55 + conf * 0.45 + source_bonus - assumption_penalty)


def edge_validity_score(nodes: list[dict[str, Any]], edges: list[dict[str, Any]], is_business_mode: bool = False) -> float:
    if not edges:
        return 1.0
    valid = 0
    for edge in edges:
        src = get_node(nodes, str(edge.get("source", "")))
        tgt = get_node(nodes, str(edge.get("target", "")))
        if not src or not tgt:
            continue
        er = edge_role(edge)
        src_role = semantic_role(src)
        tgt_role = semantic_role(tgt)
        src_type = str(src.get("type", "")).upper()
        tgt_type = str(tgt.get("type", "")).upper()
        if is_business_mode:
            if er == "HAS_OPTION" and src_role == "DECISION" and tgt_role == "OPTION":
                valid += 1
            elif er == "SUPPORTS" and src_role == "EVIDENCE" and tgt_role in {"OPTION", "DECISION"}:
                valid += 1
            elif er == "OPPOSES" and src_role == "RISK" and tgt_role in {"OPTION", "DECISION"}:
                valid += 1
            elif er == "DEPENDS_ON" and src_role == "ASSUMPTION" and tgt_role in {"OPTION", "DECISION"}:
                valid += 1
            elif er == "BLOCKS" and src_role == "OPEN_QUESTION" and tgt_role in {"OPTION", "DECISION"}:
                valid += 1
            elif er == "RESOLVES" and src_role == "ACTION" and tgt_role == "OPEN_QUESTION":
                valid += 1
            elif er == "IMPLEMENTS" and src_role == "ACTION" and tgt_role == "DECISION":
                valid += 1
        else:
            if er == "SUPPORTS" and src_type in {"EVIDENCE", "CLAIM"} and tgt_type in {"CLAIM", "THESIS"}:
                valid += 1
            elif er == "OPPOSES" and src_type == "COUNTERARGUMENT" and tgt_type in {"CLAIM", "THESIS"}:
                valid += 1
            elif er == "RESOLVES" and src_type in {"CLAIM", "EVIDENCE"} and tgt_type == "COUNTERARGUMENT":
                valid += 1
    return clamp01(valid / max(1, len(edges)))


def has_evidence_support(nodes: list[dict[str, Any]], edges: list[dict[str, Any]], claim_id: str) -> bool:
    for edge in edges:
        if edge_role(edge) == "SUPPORTS" and edge.get("target", "") == claim_id:
            src_node = get_node(nodes, str(edge.get("source", "")))
            if src_node and src_node.get("type", "") == "EVIDENCE":
                return True
    return False


def has_assumption_current(nodes: list[dict[str, Any]], edges: list[dict[str, Any]], claim_id: str) -> bool:
    for edge in edges:
        if (edge.get("type", "") == "SUPPORTS" or edge_role(edge) == "DEPENDS_ON") and edge.get("target", "") == claim_id:
            src_node = get_node(nodes, str(edge.get("source", "")))
            if src_node and (src_node.get("type", "") == "EVIDENCE" or semantic_role(src_node) == "ASSUMPTION"):
                assumptions = src_node.get("assumptions", [])
                if isinstance(assumptions, list) and assumptions:
                    return True
                if semantic_role(src_node) == "ASSUMPTION":
                    return True
    return False


def has_assumption_legacy(nodes: list[dict[str, Any]], edges: list[dict[str, Any]], claim_id: str) -> bool:
    for edge in edges:
        if edge.get("type", "") == "SUPPORTS" and edge.get("target", "") == claim_id:
            src_node = get_node(nodes, str(edge.get("source", "")))
            if src_node and src_node.get("type", "") == "EVIDENCE":
                assumptions = src_node.get("assumptions", [])
                if isinstance(assumptions, list) and assumptions:
                    return True
    return False


def claim_support_score_current_internal(
    nodes: list[dict[str, Any]],
    edges: list[dict[str, Any]],
    claim_id: str,
    visited: set[str],
) -> float:
    if claim_id in visited:
        return 0.0
    next_visited = set(visited)
    next_visited.add(claim_id)

    total_support = 0.0
    evidence_count = 0
    claim_supporter_scores: list[float] = []
    for edge in edges:
        if edge_role(edge) == "SUPPORTS" and edge.get("target", "") == claim_id:
            src_node = get_node(nodes, str(edge.get("source", "")))
            if src_node and src_node.get("type", "") == "EVIDENCE":
                evidence_count += 1
                total_support += edge_weight(edge) * evidence_quality_current(src_node)
            elif src_node and src_node.get("type", "") in ["CLAIM", "THESIS"]:
                claim_supporter_scores.append(
                    claim_support_score_current_internal(nodes, edges, str(src_node.get("id", "")), next_visited)
                )
    if evidence_count > 0:
        avg_quality = clamp01(total_support / max(1, evidence_count))
        return clamp01(0.55 + 0.45 * avg_quality)
    if claim_supporter_scores:
        avg_supporter = clamp01(sum(claim_supporter_scores) / max(1, len(claim_supporter_scores)))
        base_credit = 0.28 + 0.52 * avg_supporter
        if has_assumption_current(nodes, edges, claim_id):
            base_credit += 0.08
        return clamp01(base_credit)
    return 0.0


def claim_support_score_current(nodes: list[dict[str, Any]], edges: list[dict[str, Any]], claim_id: str) -> float:
    return claim_support_score_current_internal(nodes, edges, claim_id, set())


def claim_support_score_legacy(nodes: list[dict[str, Any]], edges: list[dict[str, Any]], claim_id: str) -> float:
    total_support = 0.0
    evidence_count = 0
    for edge in edges:
        if edge.get("type", "") == "SUPPORTS" and edge.get("target", "") == claim_id:
            src_node = get_node(nodes, str(edge.get("source", "")))
            if src_node and src_node.get("type", "") == "EVIDENCE":
                evidence_count += 1
                total_support += edge_weight(edge) * evidence_quality_legacy(src_node)
    if evidence_count == 0:
        return 0.0
    return clamp01(min(1.0, total_support))


def get_thesis_ids_legacy(nodes: list[dict[str, Any]], edges: list[dict[str, Any]]) -> list[str]:
    thesis_nodes = [n for n in nodes if n.get("type", "") == "THESIS"]
    if thesis_nodes:
        return [str(n.get("id", "")) for n in thesis_nodes[:2]]
    claims = [n for n in nodes if n.get("type", "") == "CLAIM"]
    if not claims:
        return []
    roots: list[str] = []
    for claim in claims:
        cid = str(claim.get("id", ""))
        supports_parent_claim = False
        for edge in edges:
            if edge.get("type", "") == "SUPPORTS" and edge.get("source", "") == cid:
                target_node = get_node(nodes, str(edge.get("target", "")))
                if target_node and target_node.get("type", "") in ["CLAIM", "THESIS"]:
                    supports_parent_claim = True
                    break
        if not supports_parent_claim:
            roots.append(cid)
    if not roots:
        roots = [str(claims[0].get("id", ""))]
    return roots[:2]


def get_thesis_ids_current(nodes: list[dict[str, Any]], edges: list[dict[str, Any]]) -> list[str]:
    thesis_nodes = [n for n in nodes if n.get("type", "") == "THESIS"]
    if thesis_nodes:
        return [str(n.get("id", "")) for n in thesis_nodes[:2]]
    claims = [n for n in nodes if n.get("type", "") == "CLAIM"]
    if not claims:
        return []
    roots: list[str] = []
    for claim in claims:
        cid = str(claim.get("id", ""))
        supports_parent_claim = False
        for edge in edges:
            if edge.get("type", "") == "SUPPORTS" and edge.get("source", "") == cid:
                target_node = get_node(nodes, str(edge.get("target", "")))
                if target_node and target_node.get("type", "") in ["CLAIM", "THESIS"]:
                    supports_parent_claim = True
                    break
        if not supports_parent_claim:
            roots.append(cid)
    if not roots:
        roots = [str(claims[0].get("id", ""))]
    return roots[:2]


def claim_connected_to_thesis_legacy(nodes: list[dict[str, Any]], edges: list[dict[str, Any]], claim_id: str, thesis_ids: list[str]) -> bool:
    if claim_id in thesis_ids or not thesis_ids:
        return True
    visited = {claim_id}
    queue = [claim_id]
    idx = 0
    while idx < len(queue):
        cur = queue[idx]
        if cur in thesis_ids:
            return True
        for edge in edges:
            et = edge.get("type", "")
            if et not in ["SUPPORTS", "ADDRESSES", "CONTRADICTS"]:
                continue
            nxt = ""
            if edge.get("source", "") == cur:
                nxt = str(edge.get("target", ""))
            elif edge.get("target", "") == cur:
                nxt = str(edge.get("source", ""))
            if nxt and nxt not in visited:
                visited.add(nxt)
                queue.append(nxt)
        idx += 1
    return False


def claim_connected_to_thesis_current(nodes: list[dict[str, Any]], edges: list[dict[str, Any]], claim_id: str, thesis_ids: list[str]) -> bool:
    if claim_id in thesis_ids or not thesis_ids:
        return True
    visited = {claim_id}
    queue = [claim_id]
    idx = 0
    while idx < len(queue):
        cur = queue[idx]
        if cur in thesis_ids:
            return True
        for edge in edges:
            et = edge_role(edge)
            if et not in ["SUPPORTS", "RESOLVES", "OPPOSES"]:
                continue
            nxt = ""
            if edge.get("source", "") == cur:
                nxt = str(edge.get("target", ""))
            elif edge.get("target", "") == cur:
                nxt = str(edge.get("source", ""))
            if nxt and nxt not in visited:
                visited.add(nxt)
                queue.append(nxt)
        idx += 1
    return False


def contradiction_unresolved_legacy(nodes: list[dict[str, Any]], edges: list[dict[str, Any]], contradiction_edge: dict[str, Any]) -> bool:
    src_id = str(contradiction_edge.get("source", ""))
    tgt_id = str(contradiction_edge.get("target", ""))
    src_node = get_node(nodes, src_id)
    tgt_node = get_node(nodes, tgt_id)
    if is_acknowledged(src_node) or is_acknowledged(tgt_node):
        return False
    for edge in edges:
        if edge.get("type", "") == "ADDRESSES":
            addr_target = str(edge.get("target", ""))
            if addr_target == src_id or addr_target == tgt_id:
                return False
    return True


def contradiction_unresolved_current(nodes: list[dict[str, Any]], edges: list[dict[str, Any]], contradiction_edge: dict[str, Any]) -> bool:
    src_id = str(contradiction_edge.get("source", ""))
    tgt_id = str(contradiction_edge.get("target", ""))
    src_node = get_node(nodes, src_id)
    tgt_node = get_node(nodes, tgt_id)
    if is_acknowledged(src_node) or is_acknowledged(tgt_node):
        return False
    for edge in edges:
        if edge_role(edge) == "RESOLVES":
            addr_target = str(edge.get("target", ""))
            if addr_target == src_id or addr_target == tgt_id:
                return False
    return True


def calculate_score_legacy(nodes: list[dict[str, Any]], edges: list[dict[str, Any]]) -> dict[str, Any]:
    claims = get_claims(nodes)
    total_claims = len(claims)
    total_nodes = len(nodes)
    thesis_ids = get_thesis_ids_legacy(nodes, edges)
    contradictions = [e for e in edges if e.get("type", "") == "CONTRADICTS"]
    unresolved_contradictions = sum(1 for edge in contradictions if contradiction_unresolved_legacy(nodes, edges, edge))

    if total_claims == 0 or total_nodes == 0:
        return {
            "overall": 0,
            "support": 0,
            "premise": 0,
            "coherence": 0,
            "counterargument": 0,
            "consistency": 0,
            "unsupportedClaims": 0,
            "claimsNeedingPremise": 0,
            "unresolvedContradictions": unresolved_contradictions,
            "weakInferenceClaims": 0,
            "vagueClaims": 0,
            "orphanNodes": 0,
            "disconnectedClaims": 0,
            "thesisSupported": False,
            "passesBar": False,
        }

    support_sum = 0.0
    unsupported_claims = 0
    thesis_supported = bool(thesis_ids)
    for claim in claims:
        cid = str(claim.get("id", ""))
        c_support = claim_support_score_legacy(nodes, edges, cid)
        support_sum += c_support
        if c_support < 0.10:
            unsupported_claims += 1
        if cid in thesis_ids and c_support < 0.25:
            thesis_supported = False
    support_quality = clamp01(support_sum / max(1, total_claims))

    logical_penalty = 0.0
    claims_needing_premise = 0
    weak_inference_claims = 0
    vague_claims = 0
    for claim in claims:
        cid = str(claim.get("id", ""))
        if has_issue_type(claim, "missing_premise") and not has_assumption_legacy(nodes, edges, cid):
            claims_needing_premise += 1
            logical_penalty += 1.0
        if has_issue_type(claim, "weak_inference"):
            weak_inference_claims += 1
            logical_penalty += 0.7
        if has_issue_type(claim, "vague_language"):
            vague_claims += 1
            logical_penalty += 0.4
    max_logical_penalty = float(max(1, total_claims)) * 1.6
    logical_soundness = clamp01(1.0 - (logical_penalty / max_logical_penalty))

    orphan_nodes = sum(1 for node in nodes if node_degree(edges, str(node.get("id", ""))) == 0)
    disconnected_claims = 0
    for claim in claims:
        cid = str(claim.get("id", ""))
        if not claim_connected_to_thesis_legacy(nodes, edges, cid, thesis_ids):
            disconnected_claims += 1
    orphan_ratio = orphan_nodes / max(1, total_nodes)
    disconnected_ratio = disconnected_claims / max(1, total_claims)
    coherence = clamp01(1.0 - (0.7 * orphan_ratio + 0.3 * disconnected_ratio))

    counterarg_nodes = [n for n in nodes if n.get("type", "") == "COUNTERARGUMENT"]
    if contradictions:
        counterarg_handling = clamp01(1.0 - (unresolved_contradictions / max(1, len(contradictions))))
    else:
        addressed_counter_count = 0
        for counter in counterarg_nodes:
            cid = str(counter.get("id", ""))
            if any(edge.get("type", "") == "ADDRESSES" and edge.get("target", "") == cid for edge in edges):
                addressed_counter_count += 1
        if counterarg_nodes and addressed_counter_count > 0:
            counterarg_handling = 0.90
        elif counterarg_nodes:
            counterarg_handling = 0.75
        else:
            counterarg_handling = 0.50

    overall = int(
        100
        * (
            0.30 * support_quality
            + 0.25 * logical_soundness
            + 0.20 * coherence
            + 0.25 * counterarg_handling
        )
    )
    if not thesis_supported:
        overall -= 10
    overall = max(0, min(100, overall))
    passes_bar = overall >= 75 and thesis_supported and unresolved_contradictions <= 1

    return {
        "overall": overall,
        "support": int(support_quality * 100),
        "premise": int(logical_soundness * 100),
        "coherence": int(coherence * 100),
        "counterargument": int(counterarg_handling * 100),
        "consistency": int(counterarg_handling * 100),
        "unsupportedClaims": unsupported_claims,
        "claimsNeedingPremise": claims_needing_premise,
        "unresolvedContradictions": unresolved_contradictions,
        "weakInferenceClaims": weak_inference_claims,
        "vagueClaims": vague_claims,
        "orphanNodes": orphan_nodes,
        "disconnectedClaims": disconnected_claims,
        "thesisSupported": thesis_supported,
        "passesBar": passes_bar,
    }


def calculate_score_current(nodes: list[dict[str, Any]], edges: list[dict[str, Any]]) -> dict[str, Any]:
    claims = get_claims(nodes)
    total_claims = len(claims)
    total_nodes = len(nodes)
    thesis_ids = get_thesis_ids_current(nodes, edges)
    contradictions = [e for e in edges if edge_role(e) == "OPPOSES"]
    unresolved_contradictions = sum(1 for edge in contradictions if contradiction_unresolved_current(nodes, edges, edge))

    if total_claims == 0 or total_nodes == 0:
        return {
            "overall": 0,
            "support": 0,
            "premise": 0,
            "coherence": 0,
            "counterargument": 0,
            "consistency": 0,
            "unsupportedClaims": 0,
            "claimsNeedingPremise": 0,
            "unresolvedContradictions": unresolved_contradictions,
            "weakInferenceClaims": 0,
            "vagueClaims": 0,
            "orphanNodes": 0,
            "disconnectedClaims": 0,
            "thesisSupported": False,
            "passesBar": False,
        }

    unsupported_claims = 0
    disconnected_claims = 0
    claims_needing_premise = 0
    weak_inference_claims = 0
    vague_claims = 0
    thesis_supported = bool(thesis_ids)

    root_serving_claim_ids: list[str] = []
    for claim in claims:
        cid = str(claim.get("id", ""))
        if cid in thesis_ids or claim_connected_to_thesis_current(nodes, edges, cid, thesis_ids):
            root_serving_claim_ids.append(cid)
        else:
            disconnected_claims += 1
    if not root_serving_claim_ids:
        root_serving_claim_ids = list(thesis_ids)

    support_sum = 0.0
    unsupported_inference_count = 0
    for cid in root_serving_claim_ids:
        c_support = claim_support_score_current(nodes, edges, cid)
        support_sum += c_support
        if c_support < 0.10:
            unsupported_claims += 1
        if cid in thesis_ids and c_support < 0.25:
            thesis_supported = False

        direct_evidence = has_evidence_support(nodes, edges, cid)
        claim_supporters = 0
        for supporter_id in source_ids_for_edge_role(edges, cid, "SUPPORTS"):
            src_node = get_node(nodes, supporter_id)
            if src_node and src_node.get("type", "") in ["CLAIM", "THESIS"]:
                claim_supporters += 1
        if claim_supporters > 0 and not direct_evidence and not has_assumption_current(nodes, edges, cid) and c_support < 0.55:
            unsupported_inference_count += 1
            claims_needing_premise += 1

    root_support_coverage = clamp01(support_sum / max(1, len(root_serving_claim_ids)))

    root_evidence_quality_sum = 0.0
    root_evidence_count = 0
    evidence_categories: set[str] = set()
    for node in nodes:
        if node.get("type", "") != "EVIDENCE":
            continue
        node_id = str(node.get("id", ""))
        targets = target_ids_for_edge_role(edges, node_id, "SUPPORTS")
        is_root_evidence = any(target in root_serving_claim_ids for target in targets)
        if is_root_evidence:
            root_evidence_quality_sum += evidence_quality_current(node)
            root_evidence_count += 1
            ev_cat = str(node.get("evidence_category", "")).strip().lower()
            if ev_cat:
                evidence_categories.add(ev_cat)
    avg_evidence_quality = root_evidence_quality_sum / max(1, root_evidence_count) if root_evidence_count > 0 else 0.0
    evidence_diversity = clamp01(len(evidence_categories) / 3.0)
    evidence_quality = clamp01(0.85 * avg_evidence_quality + 0.15 * evidence_diversity)

    counter_presence = 1.0 if contradictions else 0.35
    counter_resolution = 0.5 if not contradictions else clamp01(1.0 - (unresolved_contradictions / max(1, len(contradictions))))
    dialectical_handling = clamp01(0.35 * counter_presence + 0.65 * counter_resolution)

    orphan_nodes = sum(1 for node in nodes if node_degree(edges, str(node.get("id", ""))) == 0)
    orphan_ratio = orphan_nodes / max(1, total_nodes)
    disconnected_ratio = disconnected_claims / max(1, total_claims) if total_claims > 0 else 0.0

    reachable_nonroot = 0
    visited: set[str] = set(thesis_ids)
    queue = list(thesis_ids)
    idx = 0
    while idx < len(queue):
        cur = queue[idx]
        for edge in edges:
            er = edge_role(edge)
            if er not in ["SUPPORTS", "OPPOSES", "RESOLVES"]:
                continue
            nxt = ""
            if edge.get("source", "") == cur:
                nxt = str(edge.get("target", ""))
            elif edge.get("target", "") == cur:
                nxt = str(edge.get("source", ""))
            if nxt and nxt not in visited:
                visited.add(nxt)
                queue.append(nxt)
        idx += 1
    for visited_id in visited:
        if visited_id not in thesis_ids:
            reachable_nonroot += 1
    root_reachability = reachable_nonroot / max(1, total_nodes - len(thesis_ids))
    structural_coherence = clamp01(0.45 * root_reachability + 0.35 * (1.0 - orphan_ratio) + 0.20 * edge_validity_score(nodes, edges, False))

    unsupported_inference_rate = unsupported_inference_count / max(1, len(root_serving_claim_ids))
    assumption_explicitness = clamp01(1.0 - unsupported_inference_rate)
    thesis_clarity = node_specificity_score(get_node(nodes, thesis_ids[0])) if thesis_ids else 0.0
    if thesis_clarity < 0.45:
        vague_claims += 1

    overall = int(
        100
        * (
            0.25 * root_support_coverage
            + 0.20 * evidence_quality
            + 0.20 * dialectical_handling
            + 0.15 * structural_coherence
            + 0.10 * assumption_explicitness
            + 0.10 * thesis_clarity
        )
    )
    if not thesis_ids and overall > 30:
        overall = 30
    overall = max(0, min(100, overall))
    passes_bar = overall >= 80 and thesis_supported and unresolved_contradictions == 0

    return {
        "overall": overall,
        "support": int(root_support_coverage * 100),
        "premise": int(assumption_explicitness * 100),
        "coherence": int(structural_coherence * 100),
        "counterargument": int(dialectical_handling * 100),
        "consistency": int(dialectical_handling * 100),
        "rootSupportCoverage": int(root_support_coverage * 100),
        "evidenceQuality": int(evidence_quality * 100),
        "dialecticalHandling": int(dialectical_handling * 100),
        "structuralCoherence": int(structural_coherence * 100),
        "assumptionExplicitness": int(assumption_explicitness * 100),
        "thesisClarity": int(thesis_clarity * 100),
        "unsupportedClaims": unsupported_claims,
        "claimsNeedingPremise": claims_needing_premise,
        "unresolvedContradictions": unresolved_contradictions,
        "weakInferenceClaims": weak_inference_claims,
        "vagueClaims": vague_claims,
        "orphanNodes": orphan_nodes,
        "disconnectedClaims": disconnected_claims,
        "thesisSupported": thesis_supported,
        "passesBar": passes_bar,
    }


def calculate_business_score_current(nodes: list[dict[str, Any]], edges: list[dict[str, Any]]) -> dict[str, Any]:
    decisions = nodes_with_role(nodes, "DECISION")
    options = nodes_with_role(nodes, "OPTION")
    evidence_nodes = nodes_with_role(nodes, "EVIDENCE")
    risks = nodes_with_role(nodes, "RISK")
    assumptions = nodes_with_role(nodes, "ASSUMPTION")
    questions = nodes_with_role(nodes, "OPEN_QUESTION")
    actions = nodes_with_role(nodes, "ACTION")

    clear_decision = len(decisions) == 1
    discussion_only = not clear_decision
    decision_node = decisions[0] if clear_decision else None
    decision_id = str(decision_node.get("id", "")) if decision_node else ""

    decision_present = 1.0 if clear_decision else (0.4 if len(decisions) > 1 else 0.0)
    decision_status = str(decision_node.get("decision_status", decision_node.get("status", ""))).strip().lower() if decision_node else ""
    status_present = 1.0 if decision_status else 0.0
    decision_specificity = node_specificity_score(decision_node) if decision_node else 0.0
    decision_framing = clamp01(0.50 * decision_present + 0.20 * status_present + 0.30 * decision_specificity)

    option_count = len(options)
    if option_count == 1:
        option_count_score = 0.40
    elif option_count == 2:
        option_count_score = 0.80
    elif 3 <= option_count <= 4:
        option_count_score = 1.0
    elif option_count > 4:
        option_count_score = 0.90
    else:
        option_count_score = 0.0

    duplicate_pairs = 0
    pair_count = 0
    for i, left in enumerate(options):
        for right in options[i + 1 :]:
            pair_count += 1
            overlap = token_overlap_ratio(node_text(left), node_text(right))
            left_sig = normalized_text_signature(node_text(left))
            right_sig = normalized_text_signature(node_text(right))
            if overlap >= 0.75 or (left_sig and right_sig and (left_sig in right_sig or right_sig in left_sig) and overlap >= 0.55):
                duplicate_pairs += 1
    duplicate_option_rate = duplicate_pairs / max(1, pair_count) if pair_count > 0 else 0.0

    comparison_supported = 0
    supported_option_count = 0
    evidence_quality_sum = 0.0
    evidence_link_count = 0
    selected_or_leading_ids: list[str] = []
    for option in options:
        option_status = str(option.get("option_status", "")).strip().lower()
        option_id = str(option.get("id", ""))
        if option_status in ["selected", "leading"]:
            selected_or_leading_ids.append(option_id)
        supporters = source_ids_for_edge_role(edges, option_id, "SUPPORTS")
        opposers = source_ids_for_edge_role(edges, option_id, "OPPOSES")
        has_option_evidence = False
        for supporter_id in supporters:
            support_node = get_node(nodes, supporter_id)
            if support_node and semantic_role(support_node) == "EVIDENCE":
                evidence_quality_sum += evidence_quality_current(support_node)
                evidence_link_count += 1
                has_option_evidence = True
        if has_option_evidence:
            supported_option_count += 1
        if has_option_evidence or opposers:
            comparison_supported += 1

    if not selected_or_leading_ids and option_count > 0:
        selected_or_leading_ids = [str(options[0].get("id", ""))]
    comparison_coverage = comparison_supported / max(1, option_count) if option_count > 0 else 0.0
    option_set_quality = clamp01(0.40 * option_count_score + 0.30 * (1.0 - duplicate_option_rate) + 0.30 * comparison_coverage)

    if selected_or_leading_ids:
        decision_support_coverage = sum(1 for option_id in selected_or_leading_ids if has_evidence_support(nodes, edges, option_id)) / max(1, len(selected_or_leading_ids))
    elif option_count > 0:
        decision_support_coverage = supported_option_count / max(1, option_count)
    elif decision_id and has_evidence_support(nodes, edges, decision_id):
        decision_support_coverage = 1.0
    else:
        decision_support_coverage = 0.0

    option_evidence_coverage = supported_option_count / max(1, option_count) if option_count > 0 else decision_support_coverage
    avg_evidence_quality = (
        evidence_quality_sum / max(1, evidence_link_count)
        if evidence_link_count > 0
        else (evidence_quality_current(evidence_nodes[0]) if evidence_nodes else 0.0)
    )
    evidence_strength = clamp01(0.30 * decision_support_coverage + 0.50 * avg_evidence_quality + 0.20 * option_evidence_coverage)

    mitigated_risks = 0
    risks_on_options = 0
    for risk in risks:
        risk_id = str(risk.get("id", ""))
        risk_targets = target_ids_for_edge_role(edges, risk_id, "OPPOSES")
        if risk_targets:
            risks_on_options += 1
        if source_ids_for_edge_role(edges, risk_id, "RESOLVES"):
            mitigated_risks += 1
    risk_presence_score = 0.5 if (not risks and option_count > 0) else (1.0 if risks else 0.0)
    option_risk_coverage = risks_on_options / max(1, option_count) if option_count > 0 else (1.0 if risks else 0.0)
    mitigation_rate = mitigated_risks / max(1, len(risks)) if risks else 1.0
    risk_objection_handling = clamp01(0.30 * risk_presence_score + 0.30 * option_risk_coverage + 0.40 * mitigation_rate)

    assumption_visibility = 1.0
    if assumptions:
        assumption_score_sum = 0.0
        for assumption in assumptions:
            status = str(assumption.get("assumption_status", "")).strip().lower()
            if status == "validated":
                assumption_score_sum += 1.0
            elif status == "explicit":
                assumption_score_sum += 0.75
            elif status in ["implicit", "unverified"]:
                assumption_score_sum += 0.35
            elif status == "invalidated":
                assumption_score_sum += 0.0
            else:
                assumption_score_sum += 0.55
        assumption_visibility = clamp01(assumption_score_sum / max(1, len(assumptions)))

    if questions:
        question_score_sum = 0.0
        for question in questions:
            qid = str(question.get("id", ""))
            q_status = str(question.get("question_status", "")).strip().lower()
            resolved = bool(source_ids_for_edge_role(edges, qid, "RESOLVES"))
            if resolved or q_status == "answered":
                question_score_sum += 1.0
            elif q_status == "parked":
                question_score_sum += 0.45
        question_handling_rate = clamp01(question_score_sum / max(1, len(questions)))
    else:
        question_handling_rate = 1.0
    assumption_question_handling = clamp01(0.35 * assumption_visibility + 0.65 * question_handling_rate)

    unresolved_items = 0
    for risk in risks:
        if not source_ids_for_edge_role(edges, str(risk.get("id", "")), "RESOLVES"):
            unresolved_items += 1
    for question in questions:
        if not source_ids_for_edge_role(edges, str(question.get("id", "")), "RESOLVES"):
            unresolved_items += 1

    action_presence = 1.0 if actions else 0.0
    owner_rate = 0.0
    due_date_rate = 0.0
    task_status_rate = 0.0
    if actions:
        owned = 0
        dated = 0
        statused = 0
        for action in actions:
            owner_count = len(action.get("owners", [])) if isinstance(action.get("owners", []), list) else 0
            if owner_count == 0 and str(action.get("owner", "")).strip():
                owner_count = 1
            if owner_count > 0:
                owned += 1
            if str(action.get("due_date", action.get("dueDate", ""))).strip():
                dated += 1
            action_status = str(action.get("action_status", action.get("task_status", action.get("taskStatus", "")))).strip()
            if action_status:
                statused += 1
        owner_rate = owned / max(1, len(actions))
        due_date_rate = dated / max(1, len(actions))
        task_status_rate = statused / max(1, len(actions))

    if unresolved_items == 0 and not actions:
        actionability_ownership = 1.0
    else:
        actionability_ownership = clamp01(0.20 * action_presence + 0.40 * owner_rate + 0.30 * due_date_rate + 0.10 * task_status_rate)

    orphan_nodes = sum(1 for node in nodes if node_degree(edges, str(node.get("id", ""))) == 0)
    orphan_ratio = orphan_nodes / max(1, len(nodes))

    trace_points = 0.0
    trace_items = 0
    for evidence in evidence_nodes:
        trace_items += 1
        if str(evidence.get("sourceUrl", "")).strip():
            trace_points += 1.0
        elif isinstance(evidence.get("source_span_ids", []), list) and evidence.get("source_span_ids", []):
            trace_points += 0.8
        elif isinstance(evidence.get("speaker_ids", []), list) and evidence.get("speaker_ids", []):
            trace_points += 0.5

    for action in actions:
        trace_items += 1
        action_trace = 0.0
        owner_count = len(action.get("owners", [])) if isinstance(action.get("owners", []), list) else 0
        if owner_count == 0 and str(action.get("owner", "")).strip():
            owner_count = 1
        if owner_count > 0:
            action_trace += 0.5
        if str(action.get("due_date", action.get("dueDate", ""))).strip():
            action_trace += 0.5
        trace_points += action_trace
    traceability_score = trace_points / max(1, trace_items) if trace_items > 0 else 0.65
    traceability_hygiene = clamp01(0.35 * traceability_score + 0.35 * (1.0 - orphan_ratio) + 0.30 * edge_validity_score(nodes, edges, True))

    raw_overall = int(
        100
        * (
            0.15 * decision_framing
            + 0.15 * option_set_quality
            + 0.20 * evidence_strength
            + 0.15 * risk_objection_handling
            + 0.10 * assumption_question_handling
            + 0.15 * actionability_ownership
            + 0.10 * traceability_hygiene
        )
    )

    critical_blockers = 0
    major_blockers = 0
    moderate_blockers = 0

    if clear_decision and selected_or_leading_ids:
        supported_leading = sum(1 for option_id in selected_or_leading_ids if has_evidence_support(nodes, edges, option_id))
        if supported_leading == 0:
            critical_blockers += 1

    for risk in risks:
        risk_id = str(risk.get("id", ""))
        risk_severity = str(risk.get("severity", "")).strip().lower()
        risk_blocker = bool(risk.get("is_blocker", False))
        if not source_ids_for_edge_role(edges, risk_id, "RESOLVES") and (risk_severity == "high" or risk_blocker):
            critical_blockers += 1

    for question in questions:
        question_id = str(question.get("id", ""))
        if bool(question.get("is_blocker", False)) and not source_ids_for_edge_role(edges, question_id, "RESOLVES"):
            critical_blockers += 1

    for action in actions:
        action_id = str(action.get("id", ""))
        owner_count = len(action.get("owners", [])) if isinstance(action.get("owners", []), list) else 0
        if owner_count == 0 and str(action.get("owner", "")).strip():
            owner_count = 1
        has_due = bool(str(action.get("due_date", action.get("dueDate", ""))).strip())
        resolves_any = bool(target_ids_for_edge_role(edges, action_id, "RESOLVES"))
        implements_any = bool(target_ids_for_edge_role(edges, action_id, "IMPLEMENTS"))
        if (resolves_any or (implements_any and decision_status in ["tentative", "final"])) and (owner_count == 0 or not has_due):
            critical_blockers += 1

    unsupported_ratio = 1.0 - option_evidence_coverage if option_count > 0 else 1.0
    if option_count <= 1:
        major_blockers += 1
    if unsupported_ratio > 0.50:
        major_blockers += 1
    if evidence_link_count == 0:
        major_blockers += 1
    if actions and owner_rate < 0.50:
        major_blockers += 1
    if orphan_ratio > 0.35:
        major_blockers += 1

    if actions and due_date_rate < 0.50:
        moderate_blockers += 1
    if duplicate_option_rate > 0.30:
        moderate_blockers += 1
    if assumptions:
        unresolved_assumptions = 0
        for assumption in assumptions:
            status = str(assumption.get("assumption_status", "")).strip().lower()
            if status not in ["validated", "explicit"]:
                unresolved_assumptions += 1
        if unresolved_assumptions > 0:
            moderate_blockers += 1

    blocker_cap = 100
    if critical_blockers > 0:
        blocker_cap = 59
    elif major_blockers > 0:
        blocker_cap = 69
    elif moderate_blockers > 0:
        blocker_cap = 79

    if discussion_only:
        overall = 0
    else:
        overall = min(raw_overall, blocker_cap)

    if discussion_only:
        readiness_status = "DISCUSSION_ONLY"
    elif overall >= 85 and critical_blockers == 0 and major_blockers == 0:
        readiness_status = "READY"
    elif overall >= 70 and critical_blockers == 0:
        readiness_status = "NEEDS_FOLLOW_UP"
    else:
        readiness_status = "NOT_READY"

    return {
        "overall": overall,
        "decisionClarity": int(decision_framing * 100),
        "decisionFraming": int(decision_framing * 100),
        "optionCoverage": int(option_set_quality * 100),
        "optionSetQuality": int(option_set_quality * 100),
        "evidenceStrength": int(evidence_strength * 100),
        "riskCoverage": int(risk_objection_handling * 100),
        "riskObjectionHandling": int(risk_objection_handling * 100),
        "openQuestionHandling": int(assumption_question_handling * 100),
        "assumptionQuestionHandling": int(assumption_question_handling * 100),
        "actionability": int(actionability_ownership * 100),
        "actionabilityOwnership": int(actionability_ownership * 100),
        "traceabilityHygiene": int(traceability_hygiene * 100),
        "readinessStatus": readiness_status,
        "discussionOnly": discussion_only,
        "blockerCap": blocker_cap,
        "criticalBlockers": critical_blockers,
        "majorBlockers": major_blockers,
        "moderateBlockers": moderate_blockers,
        "decisionCount": len(decisions),
        "optionCount": len(options),
        "riskCount": len(risks),
        "openQuestionCount": len(questions),
        "nextActionCount": len(actions),
        "hasMajorBlocker": critical_blockers > 0 or major_blockers > 0,
        "orphanNodes": orphan_nodes,
    }


def severity_weight_current(severity: str) -> float:
    sev = severity.lower().strip()
    if sev == "critical":
        return 3.0
    if sev == "major":
        return 2.0
    if sev == "moderate":
        return 1.0
    return 0.5


def issue_dimension_weight_current(issue: dict[str, Any]) -> float:
    area = str(issue.get("area", "")).strip()
    if area == "Support Quality":
        return 0.25
    if area in {"Evidence Quality", "Evidence Strength"}:
        return 0.20
    if area == "Dialectic / Risk":
        return 0.20
    if area == "Structure / Coherence":
        return 0.15
    if area == "Uncertainty Handling":
        return 0.10
    if area in {"Root / Framing", "Decision Framing"}:
        return 0.15
    if area == "Option Set Quality":
        return 0.15
    if area == "Risk / Objection Handling":
        return 0.15
    if area == "Assumption / Open Question Handling":
        return 0.10
    if area == "Actionability / Ownership":
        return 0.15
    if area == "Traceability / Hygiene":
        return 0.10
    return 0.10


def issue_effort_estimate_current(issue_type: str) -> float:
    itype = issue_type.lower().strip()
    if itype in {"missing_owner", "missing_due_date", "orphan_node", "orphan_board_node"}:
        return 0.5
    if itype in {"disconnected_claim", "duplicate_option", "missing_counterargument"}:
        return 1.0
    if itype in {"unsupported_thesis", "unsupported_claim", "unsupported_leading_option", "weak_option_comparison"}:
        return 1.5
    return 1.0


def issue_priority_current(issue: dict[str, Any]) -> float:
    return (
        severity_weight_current(str(issue.get("severity", "low")))
        * issue_dimension_weight_current(issue)
        * float(issue.get("centralityMultiplier", 1.0))
        * float(issue.get("urgencyMultiplier", 1.0))
        / issue_effort_estimate_current(str(issue.get("type", "")))
    )


def severity_weight_legacy(severity: str) -> int:
    sev = severity.lower().strip()
    if sev == "high":
        return 300
    if sev == "medium":
        return 200
    return 100


def issue_priority_legacy(issue: dict[str, Any]) -> int:
    return severity_weight_legacy(str(issue.get("severity", "low"))) + int(to_float(issue.get("estimatedLift", 0), 0.0)) * 5


def identify_issues_current_education(nodes: list[dict[str, Any]], edges: list[dict[str, Any]], score: dict[str, Any]) -> list[dict[str, Any]]:
    claims = get_claims(nodes)
    issues: list[dict[str, Any]] = []
    issue_index = 1
    thesis_ids = get_thesis_ids_current(nodes, edges)
    if not thesis_ids:
        issues.append(
            {
                "id": f"issue_{issue_index}",
                "nodeId": "",
                "severity": "critical",
                "type": "no_thesis",
                "description": "There is no clear thesis or central claim to evaluate yet",
                "suggestedAction": "Add one clear thesis so the graph has a review target.",
                "area": "Root / Framing",
                "estimatedLift": 18,
                "centralityMultiplier": 1.2,
                "urgencyMultiplier": 1.2,
            }
        )
        issue_index += 1
    else:
        thesis_node = get_node(nodes, thesis_ids[0])
        thesis_clarity = node_specificity_score(thesis_node)
        thesis_support = claim_support_score_current(nodes, edges, thesis_ids[0])
        if thesis_clarity < 0.55:
            issues.append(
                {
                    "id": f"issue_{issue_index}",
                    "nodeId": thesis_ids[0],
                    "severity": "moderate",
                    "type": "vague_thesis",
                    "description": "The thesis is too vague to evaluate cleanly",
                    "suggestedAction": "Rewrite the thesis in more concrete, reviewable terms.",
                    "area": "Root / Framing",
                    "estimatedLift": 9,
                    "centralityMultiplier": 1.2,
                }
            )
            issue_index += 1
        if thesis_support < 0.25:
            issues.append(
                {
                    "id": f"issue_{issue_index}",
                    "nodeId": thesis_ids[0],
                    "severity": "major",
                    "type": "unsupported_thesis",
                    "description": "The thesis does not yet have enough visible support",
                    "suggestedAction": "Add evidence or a stronger support chain for the main thesis.",
                    "area": "Support Quality",
                    "estimatedLift": 15,
                    "centralityMultiplier": 1.2,
                    "urgencyMultiplier": 1.2,
                }
            )
            issue_index += 1

    contradictions = [e for e in edges if edge_role(e) == "OPPOSES"]
    if not contradictions:
        issues.append(
            {
                "id": f"issue_{issue_index}",
                "nodeId": thesis_ids[0] if thesis_ids else "",
                "severity": "moderate",
                "type": "missing_counterargument",
                "description": "The graph does not surface a counterargument yet",
                "suggestedAction": "Add at least one meaningful counterargument to test the thesis.",
                "area": "Dialectic / Risk",
                "estimatedLift": 8,
            }
        )
        issue_index += 1

    for claim in claims:
        cid = str(claim.get("id", ""))
        ctype = "thesis" if cid in thesis_ids else "claim"
        c_support = claim_support_score_current(nodes, edges, cid)
        is_root_serving = cid in thesis_ids or claim_connected_to_thesis_current(nodes, edges, cid, thesis_ids)

        if cid not in thesis_ids and not is_root_serving:
            issues.append(
                {
                    "id": f"issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "moderate",
                    "type": "disconnected_claim",
                    "description": "This claim is disconnected from the main thesis path",
                    "suggestedAction": "Connect this claim to the thesis or a parent claim so it supports the argument.",
                    "area": "Structure / Coherence",
                    "estimatedLift": 7,
                }
            )
            issue_index += 1

        if c_support < 0.10 and cid not in thesis_ids:
            issues.append(
                {
                    "id": f"issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "major" if is_root_serving else "moderate",
                    "type": "unsupported_claim",
                    "description": f"This {ctype} does not yet have supporting evidence",
                    "suggestedAction": "Add at least one evidence node that directly supports this claim.",
                    "area": "Support Quality",
                    "estimatedLift": 11,
                    "centralityMultiplier": 1.2 if is_root_serving else 1.0,
                }
            )
            issue_index += 1
        elif c_support < 0.55:
            issues.append(
                {
                    "id": f"issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "moderate",
                    "type": "weak_evidence",
                    "description": f"This {ctype} relies on weak or thin support",
                    "suggestedAction": "Strengthen this point with more concrete or better sourced evidence.",
                    "area": "Evidence Quality",
                    "estimatedLift": 8,
                    "centralityMultiplier": 1.2 if is_root_serving else 1.0,
                }
            )
            issue_index += 1

        supporters = source_ids_for_edge_role(edges, cid, "SUPPORTS")
        has_claim_supporter = False
        for supporter_id in supporters:
            src_node = get_node(nodes, supporter_id)
            if src_node and src_node.get("type", "") in ["CLAIM", "THESIS"]:
                has_claim_supporter = True
                break
        if has_claim_supporter and not has_evidence_support(nodes, edges, cid) and not has_assumption_current(nodes, edges, cid) and c_support < 0.55:
            issues.append(
                {
                    "id": f"issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "moderate",
                    "type": "missing_assumption",
                    "description": f"This {ctype} depends on an unstated assumption",
                    "suggestedAction": "Add an assumption node or evidence that makes the reasoning jump explicit.",
                    "area": "Uncertainty Handling",
                    "estimatedLift": 8,
                    "centralityMultiplier": 1.2 if is_root_serving else 1.0,
                }
            )
            issue_index += 1

    for contradiction in contradictions:
        if contradiction_unresolved_current(nodes, edges, contradiction):
            issue_node_id = str(contradiction.get("source", ""))
            issues.append(
                {
                    "id": f"issue_{issue_index}",
                    "nodeId": issue_node_id,
                    "severity": "major",
                    "type": "unresolved_counterargument",
                    "description": "A counterargument is still unaddressed",
                    "suggestedAction": "Add a response, rebuttal, or acknowledgement that deals with this counterargument.",
                    "area": "Dialectic / Risk",
                    "estimatedLift": 12,
                    "urgencyMultiplier": 1.1,
                }
            )
            issue_index += 1

    for node in nodes:
        nid = str(node.get("id", ""))
        ntype = str(node.get("type", ""))
        if node_degree(edges, nid) == 0 and ntype in ["CLAIM", "EVIDENCE", "COUNTERARGUMENT", "THESIS"]:
            issues.append(
                {
                    "id": f"issue_{issue_index}",
                    "nodeId": nid,
                    "severity": "low",
                    "type": "orphan_node",
                    "description": "This node is isolated from the main argument graph",
                    "suggestedAction": "Connect this node to a relevant claim or remove it if it is not helping the argument.",
                    "area": "Structure / Coherence",
                    "estimatedLift": 5,
                }
            )
            issue_index += 1

    return sorted(issues, key=issue_priority_current, reverse=True)[:14]


def identify_issues_legacy_education(nodes: list[dict[str, Any]], edges: list[dict[str, Any]], score: dict[str, Any]) -> list[dict[str, Any]]:
    claims = get_claims(nodes)
    total_claims = len(claims)
    total_nodes = len(nodes)
    contradictions = [e for e in edges if e.get("type", "") == "CONTRADICTS"]

    support_unit = max(3, int(30 / max(1, total_claims)))
    logical_unit = max(2, int(25 / max(1, total_claims)))
    coherence_unit = max(2, int(20 / max(1, total_nodes)))
    counter_unit = max(4, int(25 / max(1, len(contradictions))))

    issues: list[dict[str, Any]] = []
    issue_index = 1

    for claim in claims:
        cid = str(claim.get("id", ""))
        ctype = str(claim.get("type", "CLAIM")).lower()
        c_support = claim_support_score_legacy(nodes, edges, cid)

        if c_support < 0.10:
            issues.append(
                {
                    "id": f"legacy_issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "high",
                    "type": "unsupported_claim",
                    "description": f"This {ctype} has no supporting evidence",
                    "suggestedAction": f"Add at least one evidence node that directly supports this {ctype}.",
                    "area": "Support Quality",
                    "estimatedLift": support_unit + 4,
                }
            )
            issue_index += 1
        elif c_support < 0.35:
            issues.append(
                {
                    "id": f"legacy_issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "medium",
                    "type": "weak_evidence",
                    "description": f"This {ctype} has weak supporting evidence",
                    "suggestedAction": "Strengthen with higher-quality evidence (data, source, or stronger link).",
                    "area": "Support Quality",
                    "estimatedLift": max(2, int(support_unit * 0.7)),
                }
            )
            issue_index += 1

        if has_issue_type(claim, "missing_premise") and not has_assumption_legacy(nodes, edges, cid):
            issues.append(
                {
                    "id": f"legacy_issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "high" if c_support >= 0.10 else "medium",
                    "type": "missing_premise",
                    "description": f"This {ctype} depends on an unstated assumption",
                    "suggestedAction": "Add an assumption to the supporting evidence to make the logic explicit.",
                    "area": "Logical Soundness",
                    "estimatedLift": logical_unit + 3,
                }
            )
            issue_index += 1

        if has_issue_type(claim, "weak_inference"):
            issues.append(
                {
                    "id": f"legacy_issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "medium",
                    "type": "weak_inference",
                    "description": f"The reasoning in this {ctype} is weak",
                    "suggestedAction": "Clarify why the evidence justifies the claim, or narrow the claim.",
                    "area": "Logical Soundness",
                    "estimatedLift": logical_unit,
                }
            )
            issue_index += 1

        if has_issue_type(claim, "vague_language"):
            issues.append(
                {
                    "id": f"legacy_issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "low",
                    "type": "vague_language",
                    "description": f"This {ctype} is vague",
                    "suggestedAction": "Clarify wording with concrete terms and scope.",
                    "area": "Logical Soundness",
                    "estimatedLift": max(1, logical_unit - 1),
                }
            )
            issue_index += 1

    for contradiction in contradictions:
        if contradiction_unresolved_legacy(nodes, edges, contradiction):
            src_id = str(contradiction.get("source", ""))
            tgt_id = str(contradiction.get("target", ""))
            src_node = get_node(nodes, src_id)
            issue_node_id = src_id if src_node and src_node.get("type", "") == "COUNTERARGUMENT" else tgt_id
            issues.append(
                {
                    "id": f"legacy_issue_{issue_index}",
                    "nodeId": issue_node_id,
                    "severity": "high",
                    "type": "unresolved_contradiction",
                    "description": "A contradiction is unaddressed",
                    "suggestedAction": "Add a response that addresses this counterargument, or mark it as acknowledged.",
                    "area": "Counterargument Handling",
                    "estimatedLift": counter_unit + 2,
                }
            )
            issue_index += 1

    thesis_ids = get_thesis_ids_legacy(nodes, edges)
    for claim in claims:
        cid = str(claim.get("id", ""))
        if not claim_connected_to_thesis_legacy(nodes, edges, cid, thesis_ids):
            issues.append(
                {
                    "id": f"legacy_issue_{issue_index}",
                    "nodeId": cid,
                    "severity": "medium",
                    "type": "disconnected_claim",
                    "description": "This claim is disconnected from the main thesis path",
                    "suggestedAction": "Link this claim to the thesis or a parent claim so it supports the argument.",
                    "area": "Coherence",
                    "estimatedLift": coherence_unit + 1,
                }
            )
            issue_index += 1

    for node in nodes:
        nid = str(node.get("id", ""))
        ntype = str(node.get("type", ""))
        if node_degree(edges, nid) == 0 and ntype in ["CLAIM", "EVIDENCE", "COUNTERARGUMENT"]:
            issues.append(
                {
                    "id": f"legacy_issue_{issue_index}",
                    "nodeId": nid,
                    "severity": "low",
                    "type": "orphan_node",
                    "description": "This node is isolated from the argument graph",
                    "suggestedAction": "Connect this node to a relevant claim or remove it if unnecessary.",
                    "area": "Coherence",
                    "estimatedLift": coherence_unit,
                }
            )
            issue_index += 1

    return sorted(issues, key=issue_priority_legacy, reverse=True)[:12]


def compare_fixture(fixture: dict[str, Any]) -> dict[str, Any]:
    nodes = fixture.get("nodes", [])
    edges = fixture.get("edges", [])
    graph_mode = str(fixture.get("graph_mode", fixture.get("graphMode", "education_argument")))

    if graph_mode == "business_meeting_decision":
        current = calculate_business_score_current(nodes, edges)
        return {
            "fixture": fixture.get("id", ""),
            "title": fixture.get("title", fixture.get("id", "")),
            "graphMode": graph_mode,
            "legacyAvailable": False,
            "current": {
                "score": current,
                "issueCount": None,
            },
            "legacy": None,
            "delta": {},
            "legacyNote": "Legacy scorer comparison is only available for education_argument graphs.",
        }

    current_score = calculate_score_current(nodes, edges)
    current_issues = identify_issues_current_education(nodes, edges, current_score)
    legacy_score = calculate_score_legacy(nodes, edges)
    legacy_issues = identify_issues_legacy_education(nodes, edges, legacy_score)

    return {
        "fixture": fixture.get("id", ""),
        "title": fixture.get("title", fixture.get("id", "")),
        "graphMode": graph_mode,
        "legacyAvailable": True,
        "current": {
            "score": current_score,
            "issueCount": len(current_issues),
            "topIssueTypes": [issue.get("type", "") for issue in current_issues[:5]],
        },
        "legacy": {
            "score": legacy_score,
            "issueCount": len(legacy_issues),
            "topIssueTypes": [issue.get("type", "") for issue in legacy_issues[:5]],
        },
        "delta": {
            "overall": int(current_score.get("overall", 0) - legacy_score.get("overall", 0)),
            "issueCount": len(current_issues) - len(legacy_issues),
            "passesBarChanged": bool(current_score.get("passesBar", False)) != bool(legacy_score.get("passesBar", False)),
        },
        "legacyNote": "",
    }


def iter_fixture_paths(inputs: list[str]) -> list[Path]:
    if not inputs:
        inputs = ["samples/scoring_compare"]
    resolved: list[Path] = []
    seen: set[Path] = set()
    for raw in inputs:
        path = Path(raw)
        if path.is_dir():
            for found in sorted(path.rglob("*.json")):
                if found not in seen:
                    resolved.append(found)
                    seen.add(found)
        elif path.is_file():
            if path not in seen:
                resolved.append(path)
                seen.add(path)
    return resolved


def validate_fixture_structure(fixture: dict[str, Any]) -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    nodes = fixture.get("nodes", [])
    edges = fixture.get("edges", [])
    graph_mode = str(fixture.get("graph_mode", fixture.get("graphMode", "education_argument")))
    fixture_id = str(fixture.get("id", ""))

    if not isinstance(nodes, list) or not nodes:
        issues.append({"level": "error", "type": "missing_nodes", "message": "Fixture must include a non-empty nodes list."})
        return issues
    if not isinstance(edges, list):
        issues.append({"level": "error", "type": "invalid_edges", "message": "Fixture edges must be a list."})
        return issues

    node_ids: list[str] = []
    duplicate_ids: list[str] = []
    for idx, node in enumerate(nodes):
        node_id = str(node.get("id", "")).strip()
        if not node_id:
            issues.append({"level": "error", "type": "missing_node_id", "message": f"Node at index {idx} is missing an id."})
        elif node_id in node_ids and node_id not in duplicate_ids:
            duplicate_ids.append(node_id)
        else:
            node_ids.append(node_id)
        if not str(node.get("type", "")).strip():
            issues.append({"level": "error", "type": "missing_node_type", "message": f"Node {node_id or idx} is missing a type."})
        if not node_text(node):
            issues.append({"level": "warning", "type": "empty_node_text", "message": f"Node {node_id or idx} has empty text/content."})

    for duplicate_id in duplicate_ids:
        issues.append({"level": "error", "type": "duplicate_node_id", "message": f"Duplicate node id found: {duplicate_id}."})

    node_id_set = set(node_ids)
    for idx, edge in enumerate(edges):
        edge_id = str(edge.get("id", f"edge_{idx + 1}"))
        source_id = str(edge.get("source", "")).strip()
        target_id = str(edge.get("target", "")).strip()
        if not source_id or not target_id:
            issues.append({"level": "error", "type": "missing_edge_endpoint", "message": f"Edge {edge_id} is missing source or target."})
            continue
        if source_id not in node_id_set:
            issues.append({"level": "error", "type": "unknown_edge_source", "message": f"Edge {edge_id} points to unknown source node {source_id}."})
        if target_id not in node_id_set:
            issues.append({"level": "error", "type": "unknown_edge_target", "message": f"Edge {edge_id} points to unknown target node {target_id}."})
        if not str(edge.get("type", edge.get("role", ""))).strip():
            issues.append({"level": "warning", "type": "missing_edge_type", "message": f"Edge {edge_id} is missing a type/role."})

    if graph_mode == "business_meeting_decision":
        decision_nodes = [node for node in nodes if semantic_role(node) == "DECISION"]
        option_nodes = [node for node in nodes if semantic_role(node) == "OPTION"]
        primary_decision_id = str(fixture.get("primary_decision_id", "")).strip()
        if len(decision_nodes) != 1:
            issues.append(
                {
                    "level": "warning",
                    "type": "decision_count",
                    "message": f"Business fixture {fixture_id or '<unknown>'} should usually have exactly one decision node; found {len(decision_nodes)}.",
                }
            )
        if primary_decision_id and primary_decision_id not in node_id_set:
            issues.append(
                {
                    "level": "warning",
                    "type": "missing_primary_decision",
                    "message": f"primary_decision_id {primary_decision_id} does not match any node id.",
                }
            )
        if not option_nodes:
            issues.append({"level": "warning", "type": "missing_options", "message": "Business fixture has no option nodes."})
    else:
        thesis_nodes = [node for node in nodes if str(node.get("type", "")).upper() == "THESIS"]
        if not thesis_nodes:
            issues.append({"level": "warning", "type": "missing_thesis", "message": "Education fixture has no THESIS node."})

    return issues


def evaluate_expectations(result: dict[str, Any], fixture: dict[str, Any]) -> dict[str, Any]:
    expectations = fixture.get("expectations", {})
    if not isinstance(expectations, dict) or not expectations:
        return {"defined": False, "passed": True, "failedCount": 0, "checks": []}

    current_score = result["current"]["score"]
    legacy_score = result.get("legacy", {}).get("score") if result.get("legacyAvailable") else {}
    delta = result.get("delta", {})
    checks: list[dict[str, Any]] = []

    def add_check(name: str, actual: Any, comparator: str, expected: Any, passed: bool) -> None:
        checks.append({"name": name, "actual": actual, "comparator": comparator, "expected": expected, "passed": passed})

    def maybe_range(label: str, actual: int, min_key: str, max_key: str) -> None:
        if min_key in expectations:
            expected = int(expectations[min_key])
            add_check(label, actual, ">=", expected, actual >= expected)
        if max_key in expectations:
            expected = int(expectations[max_key])
            add_check(label, actual, "<=", expected, actual <= expected)

    maybe_range("current.overall", int(current_score.get("overall", 0)), "currentOverallMin", "currentOverallMax")
    if result.get("legacyAvailable"):
        maybe_range("legacy.overall", int(legacy_score.get("overall", 0)), "legacyOverallMin", "legacyOverallMax")
        maybe_range("delta.overall", int(delta.get("overall", 0)), "deltaOverallMin", "deltaOverallMax")
        maybe_range("current.issueCount", int(result["current"].get("issueCount", 0)), "currentIssueCountMin", "currentIssueCountMax")
        maybe_range("legacy.issueCount", int(result["legacy"].get("issueCount", 0)), "legacyIssueCountMin", "legacyIssueCountMax")
    if "currentPassesBar" in expectations:
        expected = bool(expectations["currentPassesBar"])
        actual = bool(current_score.get("passesBar", False))
        add_check("current.passesBar", actual, "==", expected, actual == expected)
    if "legacyPassesBar" in expectations and result.get("legacyAvailable"):
        expected = bool(expectations["legacyPassesBar"])
        actual = bool(legacy_score.get("passesBar", False))
        add_check("legacy.passesBar", actual, "==", expected, actual == expected)
    if "requireCurrentGteLegacy" in expectations and result.get("legacyAvailable"):
        expected = bool(expectations["requireCurrentGteLegacy"])
        actual = int(current_score.get("overall", 0)) >= int(legacy_score.get("overall", 0))
        add_check("current.overall>=legacy.overall", actual, "==", expected, actual == expected)
    maybe_range("current.criticalBlockers", int(current_score.get("criticalBlockers", 0)), "criticalBlockersMin", "criticalBlockersMax")
    maybe_range("current.majorBlockers", int(current_score.get("majorBlockers", 0)), "majorBlockersMin", "majorBlockersMax")
    maybe_range("current.moderateBlockers", int(current_score.get("moderateBlockers", 0)), "moderateBlockersMin", "moderateBlockersMax")
    if "readinessStatus" in expectations:
        expected = str(expectations["readinessStatus"])
        actual = str(current_score.get("readinessStatus", ""))
        add_check("current.readinessStatus", actual, "==", expected, actual == expected)
    if "blockerCap" in expectations:
        expected = int(expectations["blockerCap"])
        actual = int(current_score.get("blockerCap", 0))
        add_check("current.blockerCap", actual, "==", expected, actual == expected)

    failed_count = sum(1 for check in checks if not check["passed"])
    return {"defined": True, "passed": failed_count == 0, "failedCount": failed_count, "checks": checks}


def benchmark_fixture(result: dict[str, Any], fixture: dict[str, Any], runs: int) -> dict[str, Any]:
    if runs <= 1:
        return {"runs": 1, "currentMsAvg": None, "legacyMsAvg": None, "totalCompareMsAvg": None}

    nodes = fixture.get("nodes", [])
    edges = fixture.get("edges", [])
    graph_mode = str(fixture.get("graph_mode", fixture.get("graphMode", "education_argument")))
    current_total = 0.0
    legacy_total = 0.0
    compare_total = 0.0

    for _ in range(runs):
        compare_start = perf_counter()
        if graph_mode == "business_meeting_decision":
            current_start = perf_counter()
            calculate_business_score_current(nodes, edges)
            current_total += perf_counter() - current_start
        else:
            current_start = perf_counter()
            current_score = calculate_score_current(nodes, edges)
            identify_issues_current_education(nodes, edges, current_score)
            current_total += perf_counter() - current_start

            legacy_start = perf_counter()
            legacy_score = calculate_score_legacy(nodes, edges)
            identify_issues_legacy_education(nodes, edges, legacy_score)
            legacy_total += perf_counter() - legacy_start
        compare_total += perf_counter() - compare_start

    return {
        "runs": runs,
        "currentMsAvg": round((current_total / runs) * 1000.0, 4),
        "legacyMsAvg": round((legacy_total / runs) * 1000.0, 4) if result.get("legacyAvailable") else None,
        "totalCompareMsAvg": round((compare_total / runs) * 1000.0, 4),
    }


def format_int_cell(value: Any) -> str:
    if value is None or value == "":
        return "-"
    try:
        return str(int(value))
    except Exception:
        return str(value)


def format_delta_cell(value: Any) -> str:
    if value is None or value == "":
        return "-"
    try:
        return f"{int(value):+d}"
    except Exception:
        return str(value)


def make_summary_rows(results: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for result in results:
        current_score = result["current"]["score"]
        legacy_score = result.get("legacy", {}).get("score") if result.get("legacyAvailable") else None
        delta = result.get("delta", {})
        validation = result.get("validation", [])
        expectation_checks = result.get("expectationChecks", {})
        benchmark = result.get("benchmark", {})
        rows.append(
            {
                "fixture": result.get("fixture", ""),
                "title": result.get("title", ""),
                "mode": result.get("graphMode", ""),
                "legacy_overall": legacy_score.get("overall") if legacy_score else "",
                "current_overall": current_score.get("overall", ""),
                "delta_overall": delta.get("overall", ""),
                "legacy_issue_count": result.get("legacy", {}).get("issueCount") if result.get("legacyAvailable") else "",
                "current_issue_count": result.get("current", {}).get("issueCount", ""),
                "delta_issue_count": delta.get("issueCount", ""),
                "legacy_passes_bar": legacy_score.get("passesBar") if legacy_score else "",
                "current_passes_bar": current_score.get("passesBar", ""),
                "passes_bar_changed": delta.get("passesBarChanged", ""),
                "readiness_status": current_score.get("readinessStatus", ""),
                "critical_blockers": current_score.get("criticalBlockers", ""),
                "major_blockers": current_score.get("majorBlockers", ""),
                "moderate_blockers": current_score.get("moderateBlockers", ""),
                "blocker_cap": current_score.get("blockerCap", ""),
                "validation_error_count": sum(1 for item in validation if item.get("level") == "error"),
                "validation_warning_count": sum(1 for item in validation if item.get("level") == "warning"),
                "expectation_passed": expectation_checks.get("passed", True),
                "expectation_failed_count": expectation_checks.get("failedCount", 0),
                "benchmark_runs": benchmark.get("runs", 1),
                "current_ms_avg": benchmark.get("currentMsAvg", ""),
                "legacy_ms_avg": benchmark.get("legacyMsAvg", ""),
                "total_compare_ms_avg": benchmark.get("totalCompareMsAvg", ""),
                "fixture_path": result.get("fixturePath", ""),
            }
        )
    return rows


def write_csv_report(path: Path, results: list[dict[str, Any]]) -> None:
    rows = make_summary_rows(results)
    fieldnames = [
        "fixture",
        "title",
        "mode",
        "legacy_overall",
        "current_overall",
        "delta_overall",
        "legacy_issue_count",
        "current_issue_count",
        "delta_issue_count",
        "legacy_passes_bar",
        "current_passes_bar",
        "passes_bar_changed",
        "readiness_status",
        "critical_blockers",
        "major_blockers",
        "moderate_blockers",
        "blocker_cap",
        "validation_error_count",
        "validation_warning_count",
        "expectation_passed",
        "expectation_failed_count",
        "benchmark_runs",
        "current_ms_avg",
        "legacy_ms_avg",
        "total_compare_ms_avg",
        "fixture_path",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def compute_overview(results: list[dict[str, Any]]) -> dict[str, Any]:
    education = [result for result in results if result.get("legacyAvailable")]
    business = [result for result in results if not result.get("legacyAvailable")]
    delta_values = [int(result.get("delta", {}).get("overall", 0)) for result in education]
    issue_delta_values = [int(result.get("delta", {}).get("issueCount", 0)) for result in education]
    pass_bar_changes = sum(1 for result in education if result.get("delta", {}).get("passesBarChanged"))
    expectation_failures = sum(int(result.get("expectationChecks", {}).get("failedCount", 0)) for result in results)
    validation_errors = 0
    validation_warnings = 0
    current_benchmarks: list[float] = []
    compare_benchmarks: list[float] = []
    for result in results:
        validation = result.get("validation", [])
        validation_errors += sum(1 for item in validation if item.get("level") == "error")
        validation_warnings += sum(1 for item in validation if item.get("level") == "warning")
        benchmark = result.get("benchmark", {})
        current_ms = benchmark.get("currentMsAvg")
        compare_ms = benchmark.get("totalCompareMsAvg")
        if current_ms is not None:
            current_benchmarks.append(float(current_ms))
        if compare_ms is not None:
            compare_benchmarks.append(float(compare_ms))
    return {
        "totalFixtures": len(results),
        "educationFixtures": len(education),
        "businessFixtures": len(business),
        "avgEducationDelta": round(sum(delta_values) / len(delta_values), 2) if delta_values else 0.0,
        "avgEducationIssueDelta": round(sum(issue_delta_values) / len(issue_delta_values), 2) if issue_delta_values else 0.0,
        "passBarChanges": pass_bar_changes,
        "expectationFailures": expectation_failures,
        "validationErrors": validation_errors,
        "validationWarnings": validation_warnings,
        "avgCurrentMs": round(sum(current_benchmarks) / len(current_benchmarks), 4) if current_benchmarks else None,
        "avgCompareMs": round(sum(compare_benchmarks) / len(compare_benchmarks), 4) if compare_benchmarks else None,
    }


def render_table(headers: list[str], rows: list[list[str]]) -> str:
    widths = [len(header) for header in headers]
    for row in rows:
        for idx, cell in enumerate(row):
            widths[idx] = max(widths[idx], len(cell))

    def make_line(values: list[str]) -> str:
        padded = [value.ljust(widths[idx]) for idx, value in enumerate(values)]
        return " | ".join(padded)

    divider = "-+-".join("-" * width for width in widths)
    lines = [make_line(headers), divider]
    for row in rows:
        lines.append(make_line(row))
    return "\n".join(lines)


def print_diff_table(results: list[dict[str, Any]]) -> None:
    headers = ["Fixture", "Mode", "Legacy", "Current", "Delta", "Issues", "State"]
    rows: list[list[str]] = []
    for result in results:
        current_score = result["current"]["score"]
        legacy_score = result.get("legacy", {}).get("score") if result.get("legacyAvailable") else None
        mode = result.get("graphMode", "")
        state = current_score.get("readinessStatus", "") if mode == "business_meeting_decision" else (
            "pass" if current_score.get("passesBar") else "revise"
        )
        issue_text = "-"
        if result.get("legacyAvailable"):
            issue_text = "{legacy}->{current} ({delta})".format(
                legacy=format_int_cell(result.get("legacy", {}).get("issueCount")),
                current=format_int_cell(result.get("current", {}).get("issueCount")),
                delta=format_delta_cell(result.get("delta", {}).get("issueCount")),
            )
        rows.append(
            [
                str(result.get("title", "")),
                str(mode),
                format_int_cell(legacy_score.get("overall") if legacy_score else ""),
                format_int_cell(current_score.get("overall")),
                format_delta_cell(result.get("delta", {}).get("overall")),
                issue_text,
                state or "-",
            ]
        )
    print("=== Before / After Table ===")
    print(render_table(headers, rows))
    print("")


def print_overview(results: list[dict[str, Any]]) -> None:
    overview = compute_overview(results)
    print("=== Overview ===")
    print(f"Fixtures compared: {overview['totalFixtures']}")
    print(f"Education fixtures: {overview['educationFixtures']}")
    print(f"Business fixtures:  {overview['businessFixtures']}")
    print(f"Avg education delta: {overview['avgEducationDelta']:+.2f}")
    print(f"Avg issue delta:     {overview['avgEducationIssueDelta']:+.2f}")
    print(f"Pass-bar changes:    {overview['passBarChanges']}")
    print(f"Expectation failures:{overview['expectationFailures']}")
    print(f"Validation errors:   {overview['validationErrors']}")
    print(f"Validation warnings: {overview['validationWarnings']}")
    if overview["avgCurrentMs"] is not None:
        print(f"Avg current ms:      {overview['avgCurrentMs']:.4f}")
    if overview["avgCompareMs"] is not None:
        print(f"Avg compare ms:      {overview['avgCompareMs']:.4f}")
    print("")


def print_report(result: dict[str, Any]) -> None:
    print(f"=== {result['title']} ===")
    print(f"Mode: {result['graphMode']}")
    validation = result.get("validation", [])
    errors = [item for item in validation if item.get("level") == "error"]
    warnings = [item for item in validation if item.get("level") == "warning"]
    if errors or warnings:
        print(f"Validation: errors={len(errors)} warnings={len(warnings)}")
    if result["legacyAvailable"]:
        current_score = result["current"]["score"]
        legacy_score = result["legacy"]["score"]
        delta = result["delta"]
        print(f"Legacy overall:  {legacy_score['overall']}")
        print(f"Current overall: {current_score['overall']}")
        print(f"Delta overall:   {delta['overall']:+d}")
        print(f"Legacy issues:   {result['legacy']['issueCount']}")
        print(f"Current issues:  {result['current']['issueCount']}")
        print(f"Pass bar changed: {delta['passesBarChanged']}")
        print("Legacy dims: support={support} premise={premise} coherence={coherence} counter={counterargument}".format(**legacy_score))
        print(
            "Current dims: root={rootSupportCoverage} evidence={evidenceQuality} dialectic={dialecticalHandling} "
            "coherence={structuralCoherence} assumptions={assumptionExplicitness} clarity={thesisClarity}".format(**current_score)
        )
    else:
        current_score = result["current"]["score"]
        print(f"Current overall: {current_score['overall']}")
        print(f"Readiness:       {current_score['readinessStatus']}")
        print(
            "Breakdown: decision={decisionFraming} options={optionSetQuality} evidence={evidenceStrength} "
            "risk={riskObjectionHandling} questions={assumptionQuestionHandling} actionability={actionabilityOwnership} "
            "traceability={traceabilityHygiene}".format(**current_score)
        )
        print(
            "Blockers: critical={criticalBlockers} major={majorBlockers} moderate={moderateBlockers} cap={blockerCap}".format(
                **current_score
            )
        )
        print(result["legacyNote"])
    expectation_checks = result.get("expectationChecks", {})
    if expectation_checks.get("defined"):
        status = "PASS" if expectation_checks.get("passed") else "FAIL"
        print(f"Expectations:    {status} ({expectation_checks.get('failedCount', 0)} failed checks)")
    benchmark = result.get("benchmark", {})
    if benchmark.get("currentMsAvg") is not None:
        if result["legacyAvailable"] and benchmark.get("legacyMsAvg") is not None:
            print(
                "Benchmark avg:  current={:.4f}ms legacy={:.4f}ms total={:.4f}ms over {} runs".format(
                    benchmark["currentMsAvg"],
                    benchmark["legacyMsAvg"],
                    benchmark["totalCompareMsAvg"],
                    benchmark["runs"],
                )
            )
        else:
            print(
                "Benchmark avg:  current={:.4f}ms total={:.4f}ms over {} runs".format(
                    benchmark["currentMsAvg"],
                    benchmark["totalCompareMsAvg"],
                    benchmark["runs"],
                )
            )
    print("")


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare legacy and current scoring on graph fixtures.")
    parser.add_argument("inputs", nargs="*", help="Fixture JSON files or directories.")
    parser.add_argument("--output", default="scoring_compare_report.json", help="Path to write JSON report.")
    parser.add_argument(
        "--csv-output",
        default="scoring_compare_report.csv",
        help="Path to write CSV summary output.",
    )
    parser.add_argument(
        "--benchmark-runs",
        type=int,
        default=1,
        help="Repeat scoring N times per fixture and report average timings.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero if any fixture fails validation errors or expectation checks.",
    )
    args = parser.parse_args()

    fixture_paths = iter_fixture_paths(args.inputs)
    if not fixture_paths:
        print("No fixture JSON files found.", flush=True)
        return 1

    results: list[dict[str, Any]] = []
    print("=== Standalone Scoring Comparator ===")
    print("Comparing legacy education scoring against the current scoring implementation.\n")

    strict_failures = 0
    for fixture_path in fixture_paths:
        with fixture_path.open("r", encoding="utf-8") as fh:
            fixture = json.load(fh)
        result = compare_fixture(fixture)
        result["fixturePath"] = str(fixture_path)
        result["validation"] = validate_fixture_structure(fixture)
        result["expectationChecks"] = evaluate_expectations(result, fixture)
        result["benchmark"] = benchmark_fixture(result, fixture, max(1, args.benchmark_runs))
        results.append(result)
        print_report(result)
        if args.strict:
            validation_errors = sum(1 for item in result["validation"] if item.get("level") == "error")
            expectation_failures = int(result["expectationChecks"].get("failedCount", 0))
            strict_failures += validation_errors + expectation_failures

    print_overview(results)
    print_diff_table(results)

    output_path = Path(args.output)
    output_path.write_text(json.dumps(results, indent=2), encoding="utf-8")
    csv_output_path = Path(args.csv_output)
    write_csv_report(csv_output_path, results)
    print(f"Saved JSON report to {output_path}")
    print(f"Saved CSV report to  {csv_output_path}")
    if args.strict and strict_failures > 0:
        print(f"STRICT CHECK FAILED: {strict_failures} validation / expectation problems detected.")
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
