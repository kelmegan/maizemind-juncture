sv import from ...main { GetContext }

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

    if currentScreen == "welcome" {
        return <WelcomeScreen navigate={navigate} />;
    } elif currentScreen == "export" {
        return <ExportScreen navigate={navigate} screenData={screenData} />;
    } elif currentScreen == "generate" {
        return <GenerateScreen navigate={navigate} />;
    } elif currentScreen == "review" {
        return <ReviewScreen navigate={navigate} screenData={screenData} />;
    } elif currentScreen == "profile" {
        return <ProfileScreen navigate={navigate} />;
    } elif currentScreen == "revise" {
        return <ReviseScreen navigate={navigate} screenData={screenData} />;
    }
    return <WelcomeScreen navigate={navigate} />;
}
