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
            if ctx and ctx["currentScreen"] {
                currentScreen = ctx["currentScreen"];
            }
        } except Exception {
            # Not logged in yet, stay on welcome
        }
    }

    can with entry {
        loadContext();
    }

    def navigate(screen: str, data: dict = {}) -> None {
        # Guard against undefined/None data from Jac client compiler
        if not data {
            data = {};
        }

        # Cache graph data whenever it's passed through navigation
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

        # When navigating to review without data, use cached
        if screen == "review" and "graphData" not in data and cachedGraphData {
            data = {
                "graphData": cachedGraphData,
                "scoreData": cachedScoreData,
                "issuesData": cachedIssuesData,
                "nextActionsData": cachedNextActionsData,
                "suggestedCounterarguments": cachedCounterargSuggestions
            };
        }

        screenData = data;
        currentScreen = screen;
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
