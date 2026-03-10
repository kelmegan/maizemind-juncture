"""Global application state"""

node AppContext {

    has currentUser: dict = {},
        currentGraph: dict = {},
        currentSession: dict = {},
        currentScreen: str = "welcome";
}