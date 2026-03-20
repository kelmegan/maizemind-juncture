import from ..screens.WelcomeScreen { WelcomeScreen }
import from ..screens.ExportScreen { ExportScreen }
import from ..screens.GenerateScreen { GenerateScreen }
import from ..screens.ReviewScreen { ReviewScreen }
import from ..screens.ProfileScreen { ProfileScreen }

import "../styles.css";

def:pub AppRouter -> JsxElement {
    has currentScreen: str = "welcome",
        screenData: dict = {},
        isDark: bool = False,
        navigationCount: int = 0,
        cachedGraphData: dict | None = None,
        cachedScoreData: dict | None = None,
        cachedIssuesData: list = [],
        cachedNextActionsData: list = [],
        cachedCounterargSuggestions: list = [];

    has safe_screens: list = ["generate", "review", "profile"];

    has graph_screens: list = ["review", "profile"];

    async def loadContext() -> None {
        try {
            ctx = await root spawn GetContext();
            if ctx and ctx["reports"] {
                ctx = ctx["reports"][0];
            }

            local_isGuest = True;
            if ctx and ctx["currentUser"] {
                if "isGuest" in ctx["currentUser"] {
                    local_isGuest = ctx["currentUser"]["isGuest"];
                }
                if "id" in ctx["currentUser"] and ctx["currentUser"]["id"] == "guest_local" {
                    local_isGuest = True;
                }
            }

            if ctx and ctx["currentUser"] and not local_isGuest and "theme" in ctx["currentUser"] {
                isDark = ctx["currentUser"]["theme"] == "dark";
            }

            if not local_isGuest {
                restored_screen = "generate";
                if ctx and ctx["currentScreen"] and ctx["currentScreen"] in safe_screens {
                    restored_screen = ctx["currentScreen"];
                }

                if ctx and "currentGraph" in ctx and ctx["currentGraph"]
                    and restored_screen in graph_screens {

                    cachedGraphData = ctx["currentGraph"];

                    graphId = "";
                    if "id" in ctx["currentGraph"] {
                        graphId = ctx["currentGraph"]["id"];
                    }

                    if graphId {
                        try {
                            scored = await root spawn GetGraphWithScoring(graphId=graphId);
                            scored_data: dict = {};
                            if scored and scored["reports"] {
                                scored_data = scored["reports"][0];
                            }

                            if "error" not in scored_data {
                                if "graph" in scored_data { cachedGraphData = scored_data["graph"]; }
                                if "score" in scored_data { cachedScoreData = scored_data["score"]; }
                                if "issues" in scored_data { cachedIssuesData = scored_data["issues"]; }
                                if "nextActions" in scored_data { cachedNextActionsData = scored_data["nextActions"]; }
                                if "suggestedCounterarguments" in scored_data { cachedCounterargSuggestions = scored_data["suggestedCounterarguments"]; }
                            }
                        } except Exception {
                            # Keep whatever graph data we already have
                        }
                    }

                    if restored_screen == "review" {
                        screenData = {
                            "graphData": cachedGraphData,
                            "scoreData": cachedScoreData,
                            "issuesData": cachedIssuesData,
                            "nextActionsData": cachedNextActionsData,
                            "suggestedCounterarguments": cachedCounterargSuggestions
                        };
                    }
                }

                currentScreen = restored_screen;
            }
        } except Exception {
            # Not logged in or context unavailable — stay on welcome with defaults
            currentScreen = "welcome";
            isDark = False;
        }
    }

    can with entry {
        loadContext();
    }

    def handleDataUpdate(
        graphData: dict | None,
        scoreData: dict | None,
        issuesData: list,
        nextActionsData: list,
        counterargSuggestions: list = []
    ) -> None {
        if graphData { cachedGraphData = graphData; }
        if scoreData { cachedScoreData = scoreData; }
        if issuesData is not None { cachedIssuesData = issuesData; }
        if nextActionsData is not None { cachedNextActionsData = nextActionsData; }
        if counterargSuggestions is not None { cachedCounterargSuggestions = counterargSuggestions; }
    }

    async def navigate(screen: str, data: dict = {}) -> None {
        if not data {
            data = {};
        }

        # On logout: clear all state, notify server, and return early
        if screen == "welcome" {
            isDark = False;
            cachedGraphData = None;
            cachedScoreData = None;
            cachedIssuesData = [];
            cachedNextActionsData = [];
            cachedCounterargSuggestions = [];
            screenData = {};
            currentScreen = "welcome";
            navigationCount = navigationCount + 1;

            try {
                root spawn UpdateContext(currentScreen="welcome", currentGraph=None);
            } except Exception {
                # Non-critical
            }

            return;
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
        navigationCount = navigationCount + 1;

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
    nav_key = str(navigationCount);

    return <div className={wrapper_class}>
        {
            <WelcomeScreen navigate={navigate} /> if currentScreen == "welcome" else
            <ExportScreen key={"export_" + nav_key} navigate={navigate} screenData={screenData} onDataUpdate={handleDataUpdate} /> if currentScreen == "export" else
            <GenerateScreen navigate={navigate} onDataUpdate={handleDataUpdate} /> if currentScreen == "generate" else
            <ReviewScreen key={"review_" + nav_key} navigate={navigate} screenData={screenData} onDataUpdate={handleDataUpdate} /> if currentScreen == "review" else
            <ProfileScreen key={"profile_" + nav_key} navigate={navigate} screenData={screenData} toggleTheme={toggleTheme} isDark={isDark} /> if currentScreen == "profile" else
            <WelcomeScreen navigate={navigate} />
        }
    </div>;
}