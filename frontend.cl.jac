"""Juncture - Client-Side UI."""

import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }

import "./styles.css";

import from .components.AuthForm { AuthForm }

def:pub app -> JsxElement {
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

    def toggleLogin(isSign: bool) -> None {
        isSignup = isSign;
        error = "";
    }

    async def handleLogin() -> None {
        error = "";
        loading = True;
        success = await jacLogin(email, password);
        loading = False;
        if success {
            isLoggedIn = True;
            email = "";
            password = "";
        } else {
            error = "Invalid email or password";
        }
    }

    async def handleSignup() -> None {
        error = "";
        loading = True;
        result = await jacSignup(email, password);
        loading = False;
        if result["success"] {
            isLoggedIn = True;
        } else {
            error = result["error"] if result["error"] else "Signup failed";
        }
    }

    def handleLogout() -> None {
        jacLogout();
        isLoggedIn = False;
    }

    async def handleSubmit(e: any) -> None {
        e.preventDefault();
        if isSignup {
            await handleSignup();
        } else {
            await handleLogin();
        }
    }

    if checkingAuth {
        return <div>Loading...</div>;
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
                onToggleMode={toggleLogin}
            />
        </div>;
}
