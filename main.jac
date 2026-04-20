"""Main entry point for maizemind."""

import from walkers.user_walkers { CreateUser, GetUserProfile, GetUserByEmail, UpdateUserProfile, GetCurrentUser }
import from walkers.session_walkers { CreateSession, GetUserSessions, CalculateUserStats, DeleteSession, GetSessionGraph }
import from walkers.graph_generate_walkers { GenerateArgumentGraph, GetGraphWithScoring }
import from walkers.graph_revise_walkers { AddEvidenceToNode, AddAssumptionToEvidence, UpdateNodeContent, DeleteNode, AddCounterargumentNode, AddAddressEdge, AddNextActionNode, EvaluateNewNode, GenerateCounter, ClarifyNode, InvestigateNode, ExpandBranch, PersistGraphLayout, RestoreGraphSnapshot }

cl import from .screens.AppRouter { AppRouter }

cl {
    def:pub app -> JsxElement {
        return <AppRouter />;
    }
}
