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
        currentUserEmail: str = "",
        navigationCount: int = 0,
        cachedGraphId: str = "",
        cachedCounterargSuggestions: list = [];

    async def loadContext() -> None {
        if jacIsLoggedIn() {
            try {
                result = await root spawn GetCurrentUser();
                data = result["reports"][0] if result["reports"] else {};
                if data and not data["isGuest"] {
                    isLoggedIn = True;
                    currentUserId = data["id"] if "id" in data else "";
                    currentUserEmail = data["email"] if "email" in data else "";
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
        graphId: str,
        counterargSuggestions: list = []
    ) -> None {
        if graphId { cachedGraphId = graphId; }
        if counterargSuggestions is not None and len(counterargSuggestions) > 0 {
            cachedCounterargSuggestions = counterargSuggestions;
        }
    }

    async def navigate(screen: str, data: dict = {}) -> None {
        if not data { data = {}; }

        if screen == "welcome" {
            isLoggedIn = False;
            currentUserId = "";
            currentUserEmail = "";
            isDark = False;
            cachedGraphId = "";
            cachedCounterargSuggestions = [];
            screenData = {};
            currentScreen = "welcome";
            navigationCount = navigationCount + 1;
            return;
        }

        if currentScreen == "welcome" {
            cachedGraphId = "";
            cachedCounterargSuggestions = [];

            # Guest users skip auth entirely
            is_guest_nav = "isGuest" in data and data["isGuest"];

            if not is_guest_nav and jacIsLoggedIn() {
                try {
                    known_email = data["userEmail"] if "userEmail" in data and data["userEmail"] else "";
                    if known_email {
                        result = await root spawn GetUserByEmail(email=known_email);
                        user_data = result["reports"][0] if result["reports"] else {};
                        if user_data and "id" in user_data {
                            isLoggedIn = True;
                            currentUserId = user_data["id"];
                            currentUserEmail = user_data["email"] if "email" in user_data else known_email;
                            if "theme" in user_data { isDark = user_data["theme"] == "dark"; }
                        }
                    } else {
                        result = await root spawn GetCurrentUser();
                        data_ctx = result["reports"][0] if result["reports"] else {};
                        if data_ctx and not data_ctx["isGuest"] {
                            isLoggedIn = True;
                            currentUserId = data_ctx["id"] if "id" in data_ctx else "";
                            currentUserEmail = data_ctx["email"] if "email" in data_ctx else "";
                            if "theme" in data_ctx { isDark = data_ctx["theme"] == "dark"; }
                        }
                    }
                } except Exception as e {
                    print(f"navigate loadContext error: {e}");
                }
            }
        }

        if "userId" in data and data["userId"] {
            currentUserId = data["userId"];
            isLoggedIn = True;
        }

        if "graphId" in data and data["graphId"] { cachedGraphId = data["graphId"]; }
        if "suggestedCounterarguments" in data { cachedCounterargSuggestions = data["suggestedCounterarguments"]; }

        if screen == "review" and "graphId" not in data and cachedGraphId {
            data = {
                "graphId": cachedGraphId,
                "suggestedCounterarguments": cachedCounterargSuggestions
            };
        }

        if screen == "export" and "graphId" not in data and cachedGraphId {
            data = {"graphId": cachedGraphId};
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

    nav_key = str(navigationCount);

    return <div className={"app-root" + (" dark" if isDark else "")}>
        {
            <WelcomeScreen navigate={navigate} /> if currentScreen == "welcome" else
            <ExportScreen key={"export_" + nav_key} navigate={navigate} screenData={screenData} onDataUpdate={handleDataUpdate} isLoggedIn={isLoggedIn} userId={currentUserId} /> if currentScreen == "export" else
            <GenerateScreen navigate={navigate} onDataUpdate={handleDataUpdate} isLoggedIn={isLoggedIn} userId={currentUserId} /> if currentScreen == "generate" else
            <ReviewScreen key={"review_" + nav_key} navigate={navigate} screenData={screenData} onDataUpdate={handleDataUpdate} /> if currentScreen == "review" else
            <ProfileScreen key={"profile_" + nav_key} navigate={navigate} screenData={screenData} toggleTheme={toggleTheme} isDark={isDark} isLoggedIn={isLoggedIn} userEmail={currentUserEmail} /> if currentScreen == "profile" else
            <WelcomeScreen navigate={navigate} />
        }
    </div>;
}