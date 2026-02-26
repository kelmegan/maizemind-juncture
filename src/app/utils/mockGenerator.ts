import { ArgumentGraph, ArgumentNode, ArgumentEdge } from "../types";

export function generateMockGraph(notes: string): ArgumentGraph {
  // Mock graph generation based on notes
  // In real app, this would call an AI API
  
  const nodes: ArgumentNode[] = [
    {
      id: "thesis-1",
      type: "THESIS",
      content: "Remote work increases productivity and employee satisfaction",
      position: { x: 400, y: 50 },
    },
    {
      id: "claim-1",
      type: "CLAIM",
      content: "Employees save time without commuting",
      position: { x: 200, y: 200 },
    },
    {
      id: "claim-2",
      type: "CLAIM",
      content: "Flexible schedules improve work-life balance",
      position: { x: 600, y: 200 },
      issues: ["missing_premise"],
    },
    {
      id: "evidence-1",
      type: "EVIDENCE",
      content: "Study shows average commute time is 54 minutes daily",
      position: { x: 200, y: 350 },
    },
    {
      id: "claim-3",
      type: "CLAIM",
      content: "Remote work reduces office distractions",
      position: { x: 100, y: 500 },
    },
    {
      id: "claim-4",
      type: "CLAIM",
      content: "Remote workers report feeling isolated",
      position: { x: 700, y: 500 },
    },
    {
      id: "assumption-1",
      type: "ASSUMPTION",
      content: "Time saved equals increased productivity",
      position: { x: 350, y: 350 },
    },
  ];

  const edges: ArgumentEdge[] = [
    {
      id: "edge-1",
      source: "claim-1",
      target: "thesis-1",
      type: "SUPPORTS",
      strength: 0.8,
    },
    {
      id: "edge-2",
      source: "claim-2",
      target: "thesis-1",
      type: "SUPPORTS",
      strength: 0.7,
    },
    {
      id: "edge-3",
      source: "evidence-1",
      target: "claim-1",
      type: "SUPPORTS",
      strength: 0.9,
    },
    {
      id: "edge-4",
      source: "assumption-1",
      target: "claim-1",
      type: "DEPENDS_ON",
    },
    {
      id: "edge-5",
      source: "claim-3",
      target: "claim-1",
      type: "SUPPORTS",
      strength: 0.6,
    },
    {
      id: "edge-6",
      source: "claim-4",
      target: "thesis-1",
      type: "CONTRADICTS",
    },
  ];

  return { nodes, edges };
}

export function addEvidenceToNode(
  graph: ArgumentGraph,
  nodeId: string,
  evidenceContent: string
): ArgumentGraph {
  const newEvidenceId = `evidence-${Date.now()}`;
  const newEvidence: ArgumentNode = {
    id: newEvidenceId,
    type: "EVIDENCE",
    content: evidenceContent,
  };

  const newEdge: ArgumentEdge = {
    id: `edge-${Date.now()}`,
    source: newEvidenceId,
    target: nodeId,
    type: "SUPPORTS",
    strength: 0.8,
  };

  return {
    nodes: [...graph.nodes, newEvidence],
    edges: [...graph.edges, newEdge],
  };
}

export function addAssumptionToNode(
  graph: ArgumentGraph,
  nodeId: string,
  assumptionContent: string
): ArgumentGraph {
  const newAssumptionId = `assumption-${Date.now()}`;
  const newAssumption: ArgumentNode = {
    id: newAssumptionId,
    type: "ASSUMPTION",
    content: assumptionContent,
  };

  const newEdge: ArgumentEdge = {
    id: `edge-${Date.now()}`,
    source: newAssumptionId,
    target: nodeId,
    type: "DEPENDS_ON",
  };

  // Remove missing_premise issue from the node
  const updatedNodes = graph.nodes.map((node) =>
    node.id === nodeId
      ? { ...node, issues: node.issues?.filter((i) => i !== "missing_premise") }
      : node
  );

  return {
    nodes: [...updatedNodes, newAssumption],
    edges: [...graph.edges, newEdge],
  };
}

export function updateNodeContent(
  graph: ArgumentGraph,
  nodeId: string,
  newContent: string
): ArgumentGraph {
  return {
    ...graph,
    nodes: graph.nodes.map((node) =>
      node.id === nodeId ? { ...node, content: newContent } : node
    ),
  };
}

export function deleteNode(
  graph: ArgumentGraph,
  nodeId: string
): ArgumentGraph {
  return {
    nodes: graph.nodes.filter((node) => node.id !== nodeId),
    edges: graph.edges.filter(
      (edge) => edge.source !== nodeId && edge.target !== nodeId
    ),
  };
}
