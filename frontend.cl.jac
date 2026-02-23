"""Juncture - Client-Side UI."""

import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }

import "./styles.css";

cl import from .components.AuthForm { AuthForm }

def:pub app -> any {
    has isLoggedIn: bool = False,
        checkingAuth: bool = True,
        isSignup: bool = False,
        name: str = "",
        email: str = "",
        password: str = "",
        error: str = "",
        loading: bool = False;

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    # Method declarations (implementations in frontend.impl.jac)
    async def handleLogin -> None;
    async def handleSignup -> None;
    def handleLogout -> None;
    async def handleSubmit(e: any) -> None;
    def toggleLogin -> None {
        setIsSignup(not isSignup);
    };

    if checkingAuth {
        return
            <div style={{"display": "flex", "justifyContent": "center",
                         "alignItems": "center", "minHeight": "100vh",
                         "color": "rgba(255,255,255,0.6)", "fontFamily": "system-ui"}}>
                Loading...
            </div>;
    }

    return
        <div className="auth-form-container">
            <AuthForm
                isSignup={isSignup}
                name={name}
                email={email}
                password={password}
                error={error}
                loading={loading}
                onNameChange={lambda e: any -> None { name = e.target.value; }}
                onEmailChange={lambda e: any -> None { email = e.target.value; }}
                onPasswordChange={lambda e: any -> None { password = e.target.value; }}
                onSubmit={handleSubmit}
                onToggleMode={lambda -> None { isSignup = not isSignup; error = ""; }}
            />
        </div>;
    # return
    # <div className="auth-form-container">
    #     <button onClick={lambda -> None { isSignup = not isSignup; error = ""; }}>
    #         Toggle (isSignup={isSignup})
    #     </button>
    # </div>;
}