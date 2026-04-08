"""Welcome Screen"""

import from "@jac/runtime" { jacSignup, jacLogin, useNavigate }
import from react { useContext }
import from "lucide-react" { Brain, Lightbulb, TrendingUp }
import from ..screens.AppContext { getAppContext }
import from ..components.Button { Button }
import from ..components.Card { Card }
import from ..components.Tabs { Tabs, TabsContent, TabsList, TabsTrigger }

def:pub WelcomeScreen(props: any) -> JsxElement {
    nav = useNavigate();
    _AppCtx = getAppContext();
    ctx = useContext(_AppCtx);

    has isSignup: bool = False,
        name: str = "",
        email: str = "",
        password: str = "",
        error: str = "",
        loading: bool = False;

    async def handleSignup() -> None {
        error = "";
        if email == "" or password == "" { error = "Please fill in all fields"; return; }

        at_idx = email.find("@");
        if at_idx <= 0 or at_idx == len(email) - 1 {
            error = "Please enter a valid email address.";
            return;
        }
        domain = email[at_idx + 1:];
        if "." not in domain or domain.startswith(".") or domain.endswith(".") {
            error = "Please enter a valid email address.";
            return;
        }

        loading = True;

        try {
            existing_result = await root spawn GetUserByEmail(email=email);
            existing_user = existing_result["reports"][0] if existing_result["reports"] else None;
            if existing_user and "id" in existing_user {
                error = "An account with this email already exists. Please log in instead.";
                loading = False;
                return;
            }
        } except Exception {}

        signup_result = await jacSignup(email, password);
        if not signup_result["success"] {
            error = signup_result["error"] if "error" in signup_result else "Signup failed";
            loading = False;
            return;
        }

        login_success = await jacLogin(email, password);
        if not login_success {
            error = "Account created but login failed. Please sign in.";
            loading = False;
            return;
        }

        userId = "";
        try {
            result = await root spawn CreateUser(
                name=name if name else email.split("@")[0],
                email=email,
                isGuest=False
            );
            user_data = result["reports"][0] if result["reports"] else {};
            if "error" in user_data and user_data["error"] == "account_exists" {
                error = "An account with this email already exists. Please log in instead.";
                loading = False;
                return;
            }
            userId = user_data["id"] if "id" in user_data else "";
        } except Exception {}

        loading = False;
        saved_email = email;
        email = "";
        password = "";
        name = "";
        ctx.setAuth(userId, saved_email, False, False);
        nav("/generate");
    }

    async def handleLogin() -> None {
        error = "";
        if email == "" or password == "" { error = "Please fill in all fields"; return; }
        loading = True;

        success = await jacLogin(email, password);
        if not success {
            error = "Invalid email or password";
            loading = False;
            return;
        }

        saved_email = email;
        email = "";
        password = "";

        try {
            result = await root spawn GetUserByEmail(email=saved_email);
            user_data = result["reports"][0] if result["reports"] else {};
            if user_data and "id" in user_data {
                is_dark = "theme" in user_data and user_data["theme"] == "dark";
                is_accessibility = "accessibilityMode" in user_data and user_data["accessibilityMode"];
                ctx.setAuth(user_data["id"], saved_email, is_dark, is_accessibility);
            }
        } except Exception {}

        loading = False;
        nav("/generate");
    }

    async def handleContinueAsGuest() -> None {
        nav("/generate");
    }

    def handleTabChange(v: str) -> None {
        isSignup = (v == "signup");
        error = "";
    }

    activeTab = "signup" if isSignup else "login";

    return (
        <div className="entry-page">
            <div className="branding-section">
                <h1 className="branding-title">MaizeMind</h1>
                <p className="tagline">Your paper & presentation copilot</p>
                <div className="feature-list">
                    <div className="feature-item">
                        <div className="feature-icon">
                            <Brain />
                        </div>
                        <div className="feature-content">
                            <h3>Paste your messy notes</h3>
                            <p>Transform scattered thoughts into structured arguments</p>
                        </div>
                    </div>
                    <div className="feature-item">
                        <div className="feature-icon">
                            <Lightbulb />
                        </div>
                        <div className="feature-content">
                            <h3>Get instant critique</h3>
                            <p>See exactly what to fix with AI-powered analysis</p>
                        </div>
                    </div>
                    <div className="feature-item">
                        <div className="feature-icon">
                            <TrendingUp />
                        </div>
                        <div className="feature-content">
                            <h3>Watch your score improve</h3>
                            <p>Track reasoning quality and export polished outlines</p>
                        </div>
                    </div>
                </div>
            </div>

            <div className="auth-container">
                <div className="auth-card">
                    <div className="auth-header">
                        <h4>Get Started</h4>
                        <p>Sign in to save your work or continue as guest</p>
                    </div>
                    <Tabs value={activeTab} onValueChange={handleTabChange} className="auth-tabs">
                        <TabsList className="auth-tabs-list">
                            <TabsTrigger value="login" activeValue={activeTab} onValueChange={handleTabChange} className="auth-tab-trigger">
                                Login
                            </TabsTrigger>
                            <TabsTrigger value="signup" activeValue={activeTab} onValueChange={handleTabChange} className="auth-tab-trigger">
                                Sign Up
                            </TabsTrigger>
                        </TabsList>

                        <TabsContent value="login" activeValue={activeTab} className="auth-tab-content">
                            {(<div className="auth-error">{error}</div>) if error else None}
                            <div className="form-field">
                                <label className="form-label">Email</label>
                                <input
                                    type="text"
                                    placeholder="you@example.com"
                                    value={email}
                                    onChange={lambda e -> None { email = e.target.value; }}
                                    className="auth-input"
                                />
                            </div>
                            <div className="form-field">
                                <label className="form-label">Password</label>
                                <input
                                    type="password"
                                    value={password}
                                    onChange={lambda e -> None { password = e.target.value; }}
                                    className="auth-input"
                                />
                            </div>
                            <Button label={"Processing..." if loading else "Login"} onClick={handleLogin} className="auth-submit-btn" />
                        </TabsContent>

                        <TabsContent value="signup" activeValue={activeTab} className="auth-tab-content">
                            {(<div className="auth-error">{error}</div>) if error and isSignup else None}
                            <div className="form-field">
                                <label className="form-label">Name</label>
                                <input
                                    type="text"
                                    placeholder="Your name"
                                    value={name}
                                    onChange={lambda e -> None { name = e.target.value; }}
                                    className="auth-input"
                                />
                            </div>
                            <div className="form-field">
                                <label className="form-label">Email</label>
                                <input
                                    type="text"
                                    placeholder="you@example.com"
                                    value={email}
                                    onChange={lambda e -> None { email = e.target.value; }}
                                    className="auth-input"
                                />
                            </div>
                            <div className="form-field">
                                <label className="form-label">Password</label>
                                <input
                                    type="password"
                                    value={password}
                                    onChange={lambda e -> None { password = e.target.value; }}
                                    className="auth-input"
                                />
                            </div>
                            <Button label={"Processing..." if loading else "Create Account"} onClick={handleSignup} className="auth-submit-btn" />
                        </TabsContent>
                    </Tabs>

                    <div className="auth-divider">OR</div>
                    <Button label={"Processing..." if loading else "Continue as Guest"} variant="outline" onClick={handleContinueAsGuest} disabled={loading} className="auth-guest-btn" />
                </div>
            </div>
        </div>
    );
}
