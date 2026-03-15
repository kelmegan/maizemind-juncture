"""Context walkers"""

import from graph.context { AppContext }

walker:pub InitContext {
    can run with Root entry {
        ctx = None;

        for c in [-->](?:AppContext) {
            ctx = c;
            break;
        }
        if ctx == None {
            ctx = (root ++> AppContext())[0];
        }

        report ctx;
    }
}


walker:pub GetContext {
    can run with Root entry {
        ctx = None;

        for c in [-->](?:AppContext) {
            ctx = c;
            break;
        }

        if ctx == None {
            ctx = (root ++> AppContext())[0];
        }

        report ctx;
    }
}


walker:pub UpdateContext {
    has currentUser: dict = {},
        currentGraph: dict = {},
        currentSession: dict = {},
        currentScreen: str = "";

    can run with Root entry {
        ctx = None;

        for c in [-->](?:AppContext) {
            ctx = c;
            break;
        }

        if ctx == None {
            ctx = (root ++> AppContext())[0];
        }

        if self.currentUser { ctx.currentUser = self.currentUser; }
        if self.currentGraph { ctx.currentGraph = self.currentGraph; }
        if self.currentSession { ctx.currentSession = self.currentSession; }
        if self.currentScreen { ctx.currentScreen = self.currentScreen; }

        report ctx;
    }
}
