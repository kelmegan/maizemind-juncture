"""Main entry point for maizemind-juncture."""

import from walkers.user_walkers { CreateUser, GetUserProfile, GetUserByEmail, UpdateUserProfile }
import from walkers.session_walkers { CreateSession, GetUserSessions, CalculateUserStats, DeleteSession, GetSessionGraph }
import from walkers.context_walkers { InitContext, GetContext, UpdateContext }
import from walkers.graph_generate_walkers { GenerateArgumentGraph, GetGraphWithScoring }
import from walkers.graph_revise_walkers { AddEvidenceToNode, AddAssumptionToEvidence, UpdateNodeContent, DeleteNode, AddCounterargumentNode, AddAddressEdge, EvaluateNewNode, GenerateCounter, ClarifyNode, InvestigateNode, ExpandBranch }
import from walkers.navigation_walkers { NavigateTo }

cl import from .screens.AppRouter { AppRouter }

cl {
    def:pub app -> JsxElement {
        return <AppRouter />;
    }
}
