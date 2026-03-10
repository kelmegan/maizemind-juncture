cl import from ..screens.WelcomeScreen { WelcomeScreen }
cl import from ..screens.ExportScreen { ExportScreen }
cl import from ..screens.GenerateScreen { GenerateScreen }
cl import from ..screens.ReviewScreen { ReviewScreen }
cl import from ..screens.ReviseScreen { ReviseScreen }
cl import from ..screens.ProfileScreen { ProfileScreen }

def:pub AppRouter -> JsxElement {
    has currentScreen: str = "welcome",
        screenData: dict = {};

    async def loadContext() -> None {
        ctx = await root spawn GetContext();
        if ctx {
            currentScreen = ctx["currentScreen"];
        }
    }

    can with entry {
        loadContext();
    }

    def navigate(screen: str, data: dict = {}) -> None {
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