import from "@jac/runtime" { jacIsLoggedIn }
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
        isLoading: bool = True,
        isLoggedIn: bool = False,
        currentUserId: str = "",
        navigationCount: int = 0,
        cachedGraphData: dict | None = None,
        cachedScoreData: dict | None = None,
        cachedIssuesData: list = [],
        cachedNextActionsData: list = [],
        cachedCounterargSuggestions: list = [];

    async def loadContext() -> None {
        if jacIsLoggedIn() {
            try {
                result = await root spawn GetCurrentUser();
                data = result["reports"][0] if result["reports"] else {};
                if data and not data["isGuest"] {
                    isLoggedIn = True;
                    currentUserId = data["id"] if "id" in data else "";
                    if "theme" in data { isDark = data["theme"] == "dark"; }
                    currentScreen = "generate";
                }
            } except Exception as e {
                print(f"loadContext error: {e}");
            }
        }
        
        isLoading = False;
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
        if not data { data = {}; }

        if screen == "welcome" {
            isLoggedIn = False;
            currentUserId = "";
            isDark = False;
            cachedGraphData = None;
            cachedScoreData = None;
            cachedIssuesData = [];
            cachedNextActionsData = [];
            cachedCounterargSuggestions = [];
            screenData = {};
            currentScreen = "welcome";
            navigationCount = navigationCount + 1;
            return;
        }

        if currentScreen == "welcome" {
            cachedGraphData = None;
            cachedScoreData = None;
            cachedIssuesData = [];
            cachedNextActionsData = [];
            cachedCounterargSuggestions = [];
        }

        if "userId" in data and data["userId"] {
            currentUserId = data["userId"];
            isLoggedIn = True;
        }

        if "graphData" in data and data["graphData"] { cachedGraphData = data["graphData"]; }
        if "scoreData" in data and data["scoreData"] { cachedScoreData = data["scoreData"]; }
        if "issuesData" in data { cachedIssuesData = data["issuesData"]; }
        if "nextActionsData" in data { cachedNextActionsData = data["nextActionsData"]; }
        if "suggestedCounterarguments" in data { cachedCounterargSuggestions = data["suggestedCounterarguments"]; }

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
    }

    def toggleTheme() -> None {
        isDark = not isDark;
    }

    if isLoading {
        return <div className="app-root"></div>;
    }

    wrapper_class = "app-root dark" if isDark else "app-root";
    nav_key = str(navigationCount);

    return <div className={wrapper_class}>
        {
            <WelcomeScreen navigate={navigate} /> if currentScreen == "welcome" else
            <ExportScreen key={"export_" + nav_key} navigate={navigate} screenData={screenData} onDataUpdate={handleDataUpdate} isLoggedIn={isLoggedIn} userId={currentUserId} /> if currentScreen == "export" else
            <GenerateScreen navigate={navigate} onDataUpdate={handleDataUpdate} isLoggedIn={isLoggedIn} userId={currentUserId} /> if currentScreen == "generate" else
            <ReviewScreen key={"review_" + nav_key} navigate={navigate} screenData={screenData} onDataUpdate={handleDataUpdate} /> if currentScreen == "review" else
            <ProfileScreen key={"profile_" + nav_key} navigate={navigate} screenData={screenData} toggleTheme={toggleTheme} isDark={isDark} isLoggedIn={isLoggedIn} /> if currentScreen == "profile" else
            <WelcomeScreen navigate={navigate} />
        }
    </div>;
}