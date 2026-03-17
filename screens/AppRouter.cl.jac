import from ..screens.WelcomeScreen { WelcomeScreen }
import from ..screens.ExportScreen { ExportScreen }
import from ..screens.GenerateScreen { GenerateScreen }
import from ..screens.ReviewScreen { ReviewScreen }
import from ..screens.ReviseScreen { ReviseScreen }
import from ..screens.ProfileScreen { ProfileScreen }

import "../styles.css";

def:pub AppRouter -> JsxElement {
    has currentScreen: str = "welcome",
        screenData: dict = {},
        isDark: bool = False,
        cachedGraphData: any = None,
        cachedScoreData: any = None,
        cachedIssuesData: list = [],
        cachedNextActionsData: list = [],
        cachedCounterargSuggestions: list = [];

    async def loadContext() -> None {
        try {
            ctx = await root spawn GetContext();
            if ctx and ctx["reports"] {
                ctx = ctx["reports"][0];
            }
            if ctx and ctx["currentUser"] and "theme" in ctx["currentUser"] {
                isDark = ctx["currentUser"]["theme"] == "dark";
            }

            local_isGuest = True;
            if ctx and ctx["currentUser"] {
                local_isGuest = ctx["currentUser"]["isGuest"] if "isGuest" in ctx["currentUser"] else True;
                if ctx["currentUser"]["id"] == "guest_local" { local_isGuest = True; }
            }

            if ctx and "currentGraph" in ctx and ctx["currentGraph"] {
                cachedGraphData = ctx["currentGraph"];
                graphId = ctx["currentGraph"]["id"] if "id" in ctx["currentGraph"] else "";
                if graphId {
                    try {
                        scored = await root spawn GetGraphWithScoring(graphId=graphId);
                        scored_data = scored["reports"][0] if scored["reports"] else {};
                        if "error" not in scored_data {
                            cachedGraphData = scored_data["graph"] if "graph" in scored_data else cachedGraphData;
                            cachedScoreData = scored_data["score"] if "score" in scored_data else None;
                            cachedIssuesData = scored_data["issues"] if "issues" in scored_data else [];
                            cachedNextActionsData = scored_data["nextActions"] if "nextActions" in scored_data else [];
                        }
                    } except Exception {
                        # Keep whatever we have
                    }
                }
            }

            if ctx and ctx["currentScreen"] and not local_isGuest {
                currentScreen = ctx["currentScreen"];
            }
        } except Exception {
            # Not logged in yet, stay on welcome
        }
    }

    can with entry {
        loadContext();
    }

    async def navigate(screen: str, data: dict = {}) -> None {
        if not data {
            data = {};
        }

        if "graphData" in data and data["graphData"] {
            cachedGraphData = data["graphData"];
        }
        if "scoreData" in data and data["scoreData"] {
            cachedScoreData = data["scoreData"];
        }
        if "issuesData" in data {
            cachedIssuesData = data["issuesData"];
        }
        if "nextActionsData" in data {
            cachedNextActionsData = data["nextActionsData"];
        }
        if "suggestedCounterarguments" in data {
            cachedCounterargSuggestions = data["suggestedCounterarguments"];
        }

        if screen == "review" and "graphData" not in data and cachedGraphData {
            data = {
                "graphData": cachedGraphData,
                "scoreData": cachedScoreData,
                "issuesData": cachedIssuesData,
                "nextActionsData": cachedNextActionsData,
                "suggestedCounterarguments": cachedCounterargSuggestions
            };
        }

        if screen == "export" and "graphData" not in data and cachedGraphData {
            data = {
                "graphData": cachedGraphData,
                "scoreData": cachedScoreData,
                "issuesData": cachedIssuesData,
                "nextActionsData": cachedNextActionsData
            };
        }

        screenData = data;
        currentScreen = screen;

        # Persist screen to context so reload restores the correct screen
        try {
            root spawn UpdateContext(currentScreen=screen);
        } except Exception {
            # Non-critical
        }
    }

    def toggleTheme() -> None {
        isDark = not isDark;
    }

    wrapper_class = "app-root dark" if isDark else "app-root";

    return <div className={wrapper_class}> 
        {
            <WelcomeScreen navigate={navigate} /> if currentScreen == "welcome" else
            <ExportScreen navigate={navigate} screenData={screenData} /> if currentScreen == "export" else
            <GenerateScreen navigate={navigate} /> if currentScreen == "generate" else
            <ReviewScreen navigate={navigate} screenData={screenData} /> if currentScreen == "review" else
            <ProfileScreen navigate={navigate} screenData={screenData} toggleTheme={toggleTheme} isDark={isDark}/> if currentScreen == "profile" else
            <ReviseScreen navigate={navigate} screenData={screenData} /> if currentScreen == "revise" else
            <WelcomeScreen navigate={navigate} />
        }
    </div>;
}
