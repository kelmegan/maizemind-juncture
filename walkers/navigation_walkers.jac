"""Navigation walkers"""

import from graph.context { AppContext }

walker:pub NavigateTo {
    has screen: str;

    can run with `root entry {
        ctx = None;
        for c in [AppContext] {
            ctx = c;
            break;
        }
        if ctx == None {
            ctx = (root ++> AppContext())[0];
        }
        ctx.currentScreen = self.screen;
        report ctx;
    }
}