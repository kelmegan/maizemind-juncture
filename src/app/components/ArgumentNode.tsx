import { Handle, Position } from "reactflow";
import { ArgumentNode as ArgumentNodeType } from "../types";
import { AlertCircle, CheckCircle2 } from "lucide-react";

interface ArgumentNodeProps {
  data: {
    node: ArgumentNodeType;
  };
}

const nodeColors = {
  THESIS: "bg-purple-100 border-purple-400",
  CLAIM: "bg-blue-100 border-blue-400",
  EVIDENCE: "bg-green-100 border-green-400",
  ASSUMPTION: "bg-yellow-100 border-yellow-400",
  COUNTERARGUMENT: "bg-red-100 border-red-400",
};

const nodeIcons = {
  THESIS: "🎯",
  CLAIM: "💭",
  EVIDENCE: "📊",
  ASSUMPTION: "🔗",
  COUNTERARGUMENT: "⚠️",
};

export function ArgumentNodeComponent({ data }: ArgumentNodeProps) {
  const { node } = data;
  const hasIssues = node.isWeak || (node.issues && node.issues.length > 0);

  return (
    <div
      className={`
        ${nodeColors[node.type]}
        ${hasIssues ? "ring-2 ring-red-400 animate-pulse" : ""}
        border-2 rounded-lg p-3 cursor-pointer hover:shadow-lg transition-all
        min-w-[200px] max-w-[300px]
      `}
    >
      <Handle type="target" position={Position.Top} className="!bg-gray-400" />
      
      <div className="space-y-2">
        <div className="flex items-center justify-between gap-2">
          <span className="text-xs font-semibold uppercase text-gray-600">
            {nodeIcons[node.type]} {node.type}
          </span>
          {hasIssues ? (
            <AlertCircle className="h-4 w-4 text-red-500" />
          ) : (
            <CheckCircle2 className="h-4 w-4 text-green-500" />
          )}
        </div>
        
        <p className="text-sm leading-tight text-gray-800">
          {node.content}
        </p>

        {node.issues && node.issues.length > 0 && (
          <div className="text-xs text-red-600 font-medium">
            {node.issues.length} issue{node.issues.length > 1 ? "s" : ""} found
          </div>
        )}
      </div>

      <Handle type="source" position={Position.Bottom} className="!bg-gray-400" />
    </div>
  );
}