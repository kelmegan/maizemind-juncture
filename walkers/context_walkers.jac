"""Context walkers"""

import from graph.context { AppContext }

walker:pub InitContext {
    can run with `root entry {
        ctx = None;

        for c in [AppContext] {
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
    can run with `root entry {
        ctx = None;

        for c in [AppContext] {
            ctx = c;
            break;
        }

        if ctx == None {
            ctx = (root ++> AppContext())[0];
        }

        report ctx;
    }
}