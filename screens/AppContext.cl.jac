import from react { createContext }

glob _ctx: any = createContext(None);

def:pub getAppContext() -> any {
    return _ctx;
}
