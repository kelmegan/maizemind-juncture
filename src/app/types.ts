export type NodeType = "THESIS" | "CLAIM" | "EVIDENCE" | "ASSUMPTION" | "COUNTERARGUMENT";

export type EdgeType = "SUPPORTS" | "DEPENDS_ON" | "CONTRADICTS" | "ADDRESSES";

export interface ArgumentNode {
  id: string;
  type: NodeType;
  content: string;
  isWeak?: boolean;
  issues?: string[];
  position?: { x: number; y: number };
}

export interface ArgumentEdge {
  id: string;
  source: string;
  target: string;
  type: EdgeType;
  strength?: number;
}

export interface ArgumentGraph {
  nodes: ArgumentNode[];
  edges: ArgumentEdge[];
}

export interface Issue {
  id: string;
  nodeId: string;
  severity: "high" | "medium" | "low";
  type: "unsupported_claim" | "missing_premise" | "contradiction" | "weak_evidence";
  description: string;
  suggestedAction: string;
}

export interface ReasoningScore {
  overall: number;
  support: number;
  premise: number;
  consistency: number;
  unsupportedClaims: number;
  missingPremises: number;
  unresolvedContradictions: number;
}

export interface UserProfile {
  name: string;
  userType: "student" | "business" | "researcher" | "other";
  goals: string[];
  strengths: string[];
  weaknesses: string[];
  theme: "light" | "dark" | "system";
  accessibilityMode: boolean;
}

export interface ArgumentSession {
  id: string;
  date: string;
  title: string;
  initialScore: number;
  finalScore: number;
  graph: ArgumentGraph;
  notes: string;
}
