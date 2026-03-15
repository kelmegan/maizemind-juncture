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
    has currentUser: dict = None,
        currentGraph: dict = None,
        currentSession: dict = None,
        currentScreen: str = None;

    can run with Root entry {
        ctx = None;

        for c in [-->](?:AppContext) {
            ctx = c;
            break;
        }

        if ctx == None {
            ctx = (root ++> AppContext())[0];
        }

        if self.currentUser is not None { ctx.currentUser = self.currentUser; }
        if self.currentGraph is not None { ctx.currentGraph = self.currentGraph; }
        if self.currentSession is not None { ctx.currentSession = self.currentSession; }
        if self.currentScreen is not None { ctx.currentScreen = self.currentScreen; }

        report ctx;
    }
}
