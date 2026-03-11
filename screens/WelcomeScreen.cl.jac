"""Welcome Screen"""

import from "@jac/runtime" { jacSignup, jacLogin }
import from "lucide-react" { Brain, Lightbulb, TrendingUp }

import from ..components.Button { Button }
import from ..components.Card { Card }
import from ..components.Tabs { Tabs, TabsContent, TabsList, TabsTrigger }

def:pub WelcomeScreen(props: any) -> JsxElement {
    navigate = props.navigate;

    has isSignup: bool = False,
        name: str = "",
        email: str = "",
        password: str = "",
        error: str = "",
        loading: bool = False;

    async def handleSignup() -> None {
        error = "";
        if email == "" or password == "" {
            error = "Please fill in all fields";
            return;
        }
        loading = True;
        result = await jacSignup(email, password);
        loading = False;

        if result["success"] {
            walker_result = await root spawn CreateUser(
                name=name if name else email.split("@")[0],
                email=email,
                isGuest=False
            );
            email = "";
            password = "";
            name = "";
        } else {
            error = result["error"] if result["error"] else "Signup failed";
        }

        if not error {
            navigate("generate");
        }
    }

    async def handleLogin() -> None {
        error = "";
        if email == "" or password == "" {
            error = "Please fill in all fields";
            return;
        }

        loading = True;
        success = await jacLogin(email, password);
        loading = False;

        if success {
            walker_result = await root spawn GetUserProfile(userId=email);
            email = "";
            password = "";
        } else {
            error = "Invalid email or password";
        }

        if not error {
            navigate("generate");
        }
    }

    async def handleContinueAsGuest() -> None {
        await root spawn CreateUser(
            name="Guest",
            email="",
            isGuest=True
        );
        navigate("generate");
    }

    def handleTabChange(v: str) -> None {
        isSignup = (v == "signup");
        error = "";
    }

    activeTab = "signup" if isSignup else "login";

    return (
        <div className="entry-page">
            <div className="branding-section">
                <h1 className="branding-title">Juncture</h1>
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
                            {(<div className="auth-error">{error}</div>) if error and not isSignup else None}
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
                    <Button label="Continue as Guest" variant="outline" onClick={handleContinueAsGuest} className="auth-guest-btn" />
                </div>
            </div>
        </div>
    );
}
