# context.jac

glob has currentUser: dict = None;
glob has currentGraph: dict = None;
glob has currentSession: dict = None;
glob has currentScreen: str = "welcome";

def setCurrentUser(user: dict) -> None {
    currentUser = user;
}

def setCurrentGraph(graph: dict) -> None {
    currentGraph = graph;
}

def setCurrentSession(session: dict) -> None {
    currentSession = session;
}

def navigateTo(screen: str) -> None {
    currentScreen = screen;
}