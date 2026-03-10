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
    }

    activeTab = "signup" if isSignup else "login";

    return (
        <div className="min-h-screen flex items-center justify-center">
            <Card
                title="Get Started"
                description="Sign in to save your work or continue as guest"
            >
                <Tabs value={activeTab} onValueChange={handleTabChange}>
                    <TabsList className="grid grid-cols-2">
                        <TabsTrigger value="login" activeValue={activeTab} onValueChange={handleTabChange}>
                            Login
                        </TabsTrigger>
                        <TabsTrigger value="signup" activeValue={activeTab} onValueChange={handleTabChange}>
                            Sign Up
                        </TabsTrigger>
                    </TabsList>
                    <TabsContent value="login" activeValue={activeTab}>
                        <input
                            placeholder="Email"
                            value={email}
                            onChange={lambda e -> None { email = e.target.value; }}
                        />
                        <input
                            placeholder="Password"
                            type="password"
                            value={password}
                            onChange={lambda e -> None { password = e.target.value; }}
                        />
                        {(<div className="text-red-600">{error}</div>) if error and not isSignup else None}
                        <Button label={"Loading..." if loading else "Login"} onClick={handleLogin} />
                    </TabsContent>
                    <TabsContent value="signup" activeValue={activeTab}>
                        <input
                            placeholder="Name"
                            value={name}
                            onChange={lambda e -> None { name = e.target.value; }}
                        />
                        <input
                            placeholder="Email"
                            value={email}
                            onChange={lambda e -> None { email = e.target.value; }}
                        />
                        <input
                            placeholder="Password"
                            type="password"
                            value={password}
                            onChange={lambda e -> None { password = e.target.value; }}
                        />
                        {(<div className="text-red-600">{error}</div>) if error and isSignup else None}
                        <Button label={"Creating..." if loading else "Sign Up"} onClick={handleSignup} />
                    </TabsContent>
                </Tabs>
                <Button label="Continue as Guest" variant="outline" onClick={handleContinueAsGuest} />
            </Card>
        </div>
    );
}