import React, { createContext, useContext, useState, ReactNode } from "react";
import {
  ArgumentGraph,
  Issue,
  ReasoningScore,
  UserProfile,
  ArgumentSession,
} from "../types";

interface AppContextType {
  user: UserProfile | null;
  setUser: (user: UserProfile | null) => void;
  isGuest: boolean;
  setIsGuest: (guest: boolean) => void;
  currentGraph: ArgumentGraph | null;
  setCurrentGraph: (graph: ArgumentGraph | null) => void;
  currentNotes: string;
  setCurrentNotes: (notes: string) => void;
  currentScore: ReasoningScore | null;
  setCurrentScore: (score: ReasoningScore | null) => void;
  currentIssues: Issue[];
  setCurrentIssues: (issues: Issue[]) => void;
  sessions: ArgumentSession[];
  addSession: (session: ArgumentSession) => void;
  currentSessionId: string | null;
  setCurrentSessionId: (id: string | null) => void;
}

const AppContext = createContext<AppContextType | undefined>(undefined);

export function AppProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<UserProfile | null>(null);
  const [isGuest, setIsGuest] = useState(true);
  const [currentGraph, setCurrentGraph] = useState<ArgumentGraph | null>(null);
  const [currentNotes, setCurrentNotes] = useState("");
  const [currentScore, setCurrentScore] = useState<ReasoningScore | null>(null);
  const [currentIssues, setCurrentIssues] = useState<Issue[]>([]);
  const [sessions, setSessions] = useState<ArgumentSession[]>([]);
  const [currentSessionId, setCurrentSessionId] = useState<string | null>(null);

  const addSession = (session: ArgumentSession) => {
    setSessions((prev) => [session, ...prev]);
  };

  return (
    <AppContext.Provider
      value={{
        user,
        setUser,
        isGuest,
        setIsGuest,
        currentGraph,
        setCurrentGraph,
        currentNotes,
        setCurrentNotes,
        currentScore,
        setCurrentScore,
        currentIssues,
        setCurrentIssues,
        sessions,
        addSession,
        currentSessionId,
        setCurrentSessionId,
      }}
    >
      {children}
    </AppContext.Provider>
  );
}

export function useApp() {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error("useApp must be used within AppProvider");
  }
  return context;
}
