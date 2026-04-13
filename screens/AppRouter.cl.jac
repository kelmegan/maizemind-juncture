import from "@jac/runtime" { jacIsLoggedIn, Router, Routes, Route }
import from react { useContext }
import from ..screens.AppContext { getAppContext }
import from ..screens.WelcomeScreen { WelcomeScreen }
import from ..screens.ExportScreen { ExportScreen }
import from ..screens.GenerateScreen { GenerateScreen }
import from ..screens.ReviewScreen { ReviewScreen }
import from ..screens.ProfileScreen { ProfileScreen }
import "../styles.css";

def:pub AppRouter -> JsxElement {
    has isDark: bool = False,
        isLoading: bool = True,
        isLoggedIn: bool = False,
        accessibilityMode: bool = False,
        currentUserId: str = "",
        currentUserEmail: str = "",
        cachedGraphId: str = "",
        cachedCounterargSuggestions: list[{}] = [];

    async def loadContext() -> None {
        stored_id = localStorage.getItem("maizemind_graph_id");
        if stored_id { cachedGraphId = stored_id; }
        if jacIsLoggedIn() {
            try {
                result = await root spawn GetCurrentUser();
                data = result["reports"][0] if result["reports"] else {};
                if data and not data["isGuest"] {
                    isLoggedIn = True;
                    currentUserId = data["id"] if "id" in data else "";
                    currentUserEmail = data["email"] if "email" in data else "";
                    if "theme" in data { isDark = data["theme"] == "dark"; }
                    if "accessibilityMode" in data { accessibilityMode = data["accessibilityMode"]; }
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

    def setAuth(userId: str, userEmail: str, darkMode: bool = False) -> None {
        isLoggedIn = True;
        currentUserId = userId;
        currentUserEmail = userEmail;
        isDark = darkMode;
    }

    def logout() -> None {
        isLoggedIn = False;
        currentUserId = "";
        currentUserEmail = "";
        isDark = False;
        accessibilityMode = False;
        cachedGraphId = "";
        cachedCounterargSuggestions = [];
        localStorage.removeItem("maizemind_graph_id");
    }

    def toggleTheme() -> None {
        isDark = not isDark;
    }

    def toggleAccessibility() -> None {
        accessibilityMode = not accessibilityMode;
    }

    def setGraphCache(graphId: str, counterargs: list = []) -> None {
        if graphId {
            cachedGraphId = graphId;
            localStorage.setItem("maizemind_graph_id", graphId);
        }
        if counterargs is not None and len(counterargs) > 0 {
            cachedCounterargSuggestions = counterargs;
        }
    }

    if isLoading {
        return <div className="app-root"></div>;
    }

    _AppCtx = getAppContext();
    ctx_value = {
        "isLoggedIn": isLoggedIn,
        "userId": currentUserId,
        "userEmail": currentUserEmail,
        "isDark": isDark,
        "cachedGraphId": cachedGraphId,
        "cachedCounterargSuggestions": cachedCounterargSuggestions,
        "setAuth": setAuth,
        "logout": logout,
        "toggleTheme": toggleTheme,
        "accessibilityMode": accessibilityMode,
        "toggleAccessibility": toggleAccessibility,
        "setGraphCache": setGraphCache
    };

    return <div className={"app-root" + (" dark" if isDark else "") + (" accessibility" if accessibilityMode else "")}>
        <_AppCtx.Provider value={ctx_value}>
            <Router>
                <Routes>
                    <Route path="/" element={<WelcomeScreen />} />
                    <Route path="/generate" element={<GenerateScreen />} />
                    <Route path="/review" element={<ReviewScreen />} />
                    <Route path="/export" element={<ExportScreen />} />
                    <Route path="/profile" element={<ProfileScreen />} />
                </Routes>
            </Router>
        </_AppCtx.Provider>
    </div>;
}
