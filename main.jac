# """Main entry point for maizemind-juncture."""

# import from walkers.user_walkers { CreateUser, GetUserProfile, UpdateUserProfile }
# import from walkers.session_walkers { CreateSession, GetUserSessions, CalculateUserStats }
# import from walkers.context_walkers { InitContext, GetContext }
# import from walkers.graph_generate_walkers { GenerateArgumentGraph, GetGraphWithScoring }
# import from walkers.graph_revise_walkers { AddEvidenceToNode, AddAssumptionToNode, UpdateNodeContent, DeleteNode }

# cl import from .screens.AppRouter { AppRouter }

# cl {
#     def:pub app -> JsxElement {
#         return <AppRouter />;
#     }
# }
"""Test import."""

import from src.graph_generator { Document, generate_argument_graph }

with entry {
    print("Import worked!");
}