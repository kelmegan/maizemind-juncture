import { ArgumentGraph, ReasoningScore } from "../types";

export function calculateReasoningScore(graph: ArgumentGraph): ReasoningScore {
  const { nodes, edges } = graph;

  // Count claim and thesis nodes
  const claimNodes = nodes.filter(
    (n) => n.type === "CLAIM" || n.type === "THESIS"
  );
  const totalClaims = claimNodes.length;

  // Calculate support coverage (40%)
  const supportedClaims = claimNodes.filter((claim) =>
    edges.some(
      (e) =>
        e.target === claim.id &&
        e.type === "SUPPORTS" &&
        nodes.find((n) => n.id === e.source)?.type === "EVIDENCE"
    )
  ).length;

  const supportCoverage = totalClaims > 0 ? supportedClaims / totalClaims : 1;

  // Check if thesis is supported (penalty if not)
  const thesisNode = nodes.find((n) => n.type === "THESIS");
  const thesisPenalty =
    thesisNode &&
    !edges.some(
      (e) =>
        e.target === thesisNode.id &&
        e.type === "SUPPORTS" &&
        nodes.find((n) => n.id === e.source)?.type === "EVIDENCE"
    )
      ? 0.15
      : 0;

  // Calculate premise coverage (40%)
  const claimsWithMissingPremise = claimNodes.filter(
    (claim) => claim.issues?.includes("missing_premise")
  ).length;

  const premiseCoverage =
    totalClaims > 0 ? 1 - claimsWithMissingPremise / totalClaims : 1;

  // Calculate consistency (20%)
  const contradictions = edges.filter((e) => e.type === "CONTRADICTS");
  const totalContradictions = contradictions.length;

  const unresolvedContradictions = contradictions.filter((contra) => {
    // Check if there's a counterargument addressing this contradiction
    const hasCounterargument = edges.some(
      (e) => e.type === "ADDRESSES" && e.source === contra.source
    );
    return !hasCounterargument;
  }).length;

  const consistency =
    totalContradictions > 0
      ? 1 - unresolvedContradictions / totalContradictions
      : 1;

  // Calculate final score
  const supportScore = Math.max(0, Math.min(1, supportCoverage));
  const premiseScore = Math.max(0, Math.min(1, premiseCoverage));
  const consistencyScore = Math.max(0, Math.min(1, consistency));

  const rawScore =
    supportScore * 0.4 + premiseScore * 0.4 + consistencyScore * 0.2;
  const finalScore = Math.max(
    0,
    Math.min(100, Math.round((rawScore - thesisPenalty) * 100))
  );

  return {
    overall: finalScore,
    support: Math.round(supportScore * 100),
    premise: Math.round(premiseScore * 100),
    consistency: Math.round(consistencyScore * 100),
    unsupportedClaims: totalClaims - supportedClaims,
    missingPremises: claimsWithMissingPremise,
    unresolvedContradictions,
  };
}

export function identifyIssues(graph: ArgumentGraph) {
  const { nodes, edges } = graph;
  const issues: Array<{
    id: string;
    nodeId: string;
    severity: "high" | "medium" | "low";
    type: string;
    description: string;
    suggestedAction: string;
  }> = [];

  // Find unsupported claims
  nodes.forEach((node) => {
    if (node.type === "CLAIM" || node.type === "THESIS") {
      const hasEvidence = edges.some(
        (e) =>
          e.target === node.id &&
          e.type === "SUPPORTS" &&
          nodes.find((n) => n.id === e.source)?.type === "EVIDENCE"
      );

      if (!hasEvidence) {
        issues.push({
          id: `issue-${node.id}-unsupported`,
          nodeId: node.id,
          severity: node.type === "THESIS" ? "high" : "medium",
          type: "unsupported_claim",
          description: `This ${node.type.toLowerCase()} lacks supporting evidence`,
          suggestedAction: "Add evidence (examples, stats, or source links)",
        });
      }

      // Check for missing premises
      if (node.issues?.includes("missing_premise")) {
        issues.push({
          id: `issue-${node.id}-premise`,
          nodeId: node.id,
          severity: "medium",
          type: "missing_premise",
          description: "This claim relies on unstated assumptions",
          suggestedAction: "Add the missing assumption or logical link",
        });
      }
    }
  });

  // Find unresolved contradictions
  edges
    .filter((e) => e.type === "CONTRADICTS")
    .forEach((contradiction) => {
      const hasResponse = edges.some(
        (e) => e.type === "ADDRESSES" && e.target === contradiction.id
      );

      if (!hasResponse) {
        issues.push({
          id: `issue-${contradiction.id}-contradiction`,
          nodeId: contradiction.source,
          severity: "high",
          type: "contradiction",
          description: "Unresolved contradiction detected",
          suggestedAction: "Address with a counterargument or acknowledgment",
        });
      }
    });

  return issues.sort((a, b) => {
    const severityOrder = { high: 0, medium: 1, low: 2 };
    return severityOrder[a.severity] - severityOrder[b.severity];
  });
}
