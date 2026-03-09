"""Juncture - Welcome Screen with Authentication."""

import from "@jac/runtime" { jacSignup, jacLogin, jacIsLoggedIn }

# Import UI components - assume these work as intended
import from .components.ui.button { Button }
import from .components.ui.input { Input }
import from .components.ui.label { Label }
import from .components.ui.card { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from .components.ui.tabs { Tabs, TabsContent, TabsList, TabsTrigger }

# Import icons - lucide-react equivalents
import from .components.icons { Brain, Lightbulb, TrendingUp }

# Node types for data persistence
node User {
    has id: str,
        name: str,
        email: str,
        createdAt: str,
        userType: str = "student",  # student | business | researcher | other
        goals: list[str] = [],
        strengths: list[str] = [],
        weaknesses: list[str] = [],
        theme: str = "system",  # light | dark | system
        accessibilityMode: bool = False,
        isGuest: bool = False;
}

node Session {
    has id: str,
        date: str,
        title: str,
        initialScore: int,
        finalScore: int,
        notes: str = "";
}

node ArgumentGraph {
    has id: str,
        nodes: list[dict],
        edges: list[dict],
        createdAt: str,
        updatedAt: str;
}

# Walker to create a new user
walker CreateUser {
    has name: str,
        email: str,
        userType: str = "student",
        isGuest: bool = False;
    
    can create_user with `root entry {
        new_user = User(
            id=f"user_{str(time.time()).replace('.', '')}",
            name=self.name,
            email=self.email,
            userType=self.userType,
            createdAt=str(datetime.now()),
            isGuest=self.isGuest
        );
        `root ++> new_user;
        report new_user;
    }
}

# Walker to fetch user profile
walker GetUserProfile {
    has userId: str;
    
    can fetch_profile with `root entry {
        # Find user node connected to root
        user_node = None;
        for user in -->`root[?User] {
            if user.id == self.userId {
                user_node = user;
                break;
            }
        }
        report user_node;
    }
}

# Client-side component
def:pub WelcomeScreen -> JsxElement {
    has isSignup: bool = False,
        name: str = "",
        email: str = "",
        password: str = "",
        error: str = "",
        loading: bool = False;
    
    def toggleLogin(isSign: bool) -> None {
        isSignup = isSign;
        error = "";
    }
    
    async def handleSignup() -> None {
        error = "";
        
        # Validation
        if not email.trim() or not password {
            error = "Please fill in all fields";
            return;
        }
        
        if password.length < 4 {
            error = "Password must be at least 4 characters";
            return;
        }
        
        loading = True;
        
        # Call Jaseci auth
        result = await jacSignup(email, password);
        
        loading = False;
        
        if result["success"] {
            # Create user node in graph
            # TODO: Replace with actual walker call when backend is integrated
            # walker_result = root spawn CreateUser(
            #     name=name if name else email.split("@")[0],
            #     email=email,
            #     isGuest=False
            # );
            
            # For now, mock user creation
            print(f"User created: {email}");
            
            # Navigate to generate screen
            # TODO: Add navigation when routing is implemented
            # navigate("/generate");
            
            email = "";
            password = "";
            name = "";
        } else {
            error = result["error"] if result["error"] else "Signup failed";
        }
    }
    
    async def handleLogin() -> None {
        error = "";
        
        if not email.trim() or not password {
            error = "Please fill in all fields";
            return;
        }
        
        loading = True;
        
        success = await jacLogin(email, password);
        
        loading = False;
        
        if success {
            # Fetch user profile from graph
            # TODO: Replace with actual walker call when backend is integrated
            # walker_result = root spawn GetUserProfile(userId=email);
            
            email = "";
            password = "";
        } else {
            error = "Invalid email or password";
        }
    }
    
    def handleContinueAsGuest() -> None {
        # Create guest user in graph
        # TODO: Replace with actual walker call when backend is integrated
        # walker_result = root spawn CreateUser(
        #     name="Guest",
        #     email="",
        #     isGuest=True
        # );
        
        print("Guest mode activated");
        
        # Navigate to generate screen
        # TODO: Add navigation when routing is implemented
        # navigate("/generate");
    }
    
    async def handleSubmit(e: any) -> None {
        e.preventDefault();
        if isSignup {
            await handleSignup();
        } else {
            await handleLogin();
        }
    }
    
    return
        <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-white to-purple-50 flex items-center justify-center p-4">
            <div className="w-full max-w-5xl grid md:grid-cols-2 gap-8 items-center">
                <div className="space-y-6">
                    <div className="space-y-2">
                        <h1 className="text-5xl font-bold bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent">
                            Juncture
                        </h1>
                        <p className="text-xl text-gray-600">
                            Your paper & presentation copilot
                        </p>
                    </div>

                    <div className="space-y-4">
                        <div className="flex items-start gap-3">
                            <div className="mt-1 p-2 rounded-lg bg-indigo-100">
                                <Brain className="h-5 w-5 text-indigo-600" />
                            </div>
                            <div>
                                <h3 className="font-semibold">Paste your messy notes</h3>
                                <p className="text-sm text-gray-600">
                                    Transform scattered thoughts into structured arguments
                                </p>
                            </div>
                        </div>

                        <div className="flex items-start gap-3">
                            <div className="mt-1 p-2 rounded-lg bg-purple-100">
                                <Lightbulb className="h-5 w-5 text-purple-600" />
                            </div>
                            <div>
                                <h3 className="font-semibold">Get instant critique</h3>
                                <p className="text-sm text-gray-600">
                                    See exactly what to fix with AI-powered analysis
                                </p>
                            </div>
                        </div>

                        <div className="flex items-start gap-3">
                            <div className="mt-1 p-2 rounded-lg bg-indigo-100">
                                <TrendingUp className="h-5 w-5 text-indigo-600" />
                            </div>
                            <div>
                                <h3 className="font-semibold">Watch your score improve</h3>
                                <p className="text-sm text-gray-600">
                                    Track reasoning quality and export polished outlines
                                </p>
                            </div>
                        </div>
                    </div>
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle>Get Started</CardTitle>
                        <CardDescription>
                            Sign in to save your work or continue as guest
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <Tabs defaultValue="login" className="w-full">
                            <TabsList className="grid w-full grid-cols-2">
                                <TabsTrigger value="login">Login</TabsTrigger>
                                <TabsTrigger value="signup">Sign Up</TabsTrigger>
                            </TabsList>

                            <TabsContent value="login" className="space-y-4">
                                <div className="space-y-2">
                                    <Label htmlFor="login-email">Email</Label>
                                    <Input
                                        id="login-email"
                                        type="email"
                                        placeholder="you@example.com"
                                        value={email}
                                        onChange={lambda e: any -> None { email = e.target.value; }}
                                    />
                                </div>
                                <div className="space-y-2">
                                    <Label htmlFor="login-password">Password</Label>
                                    <Input
                                        id="login-password"
                                        type="password"
                                        value={password}
                                        onChange={lambda e: any -> None { password = e.target.value; }}
                                    />
                                </div>
                                {(
                                    <div className="text-sm text-red-600">{error}</div>
                                ) if error and not isSignup else None}
                                <Button 
                                    onClick={handleLogin} 
                                    className="w-full"
                                    disabled={loading}
                                >
                                    {"Loading..." if loading else "Login"}
                                </Button>
                            </TabsContent>

                            <TabsContent value="signup" className="space-y-4">
                                <div className="space-y-2">
                                    <Label htmlFor="signup-name">Name</Label>
                                    <Input
                                        id="signup-name"
                                        placeholder="Your name"
                                        value={name}
                                        onChange={lambda e: any -> None { name = e.target.value; }}
                                    />
                                </div>
                                <div className="space-y-2">
                                    <Label htmlFor="signup-email">Email</Label>
                                    <Input
                                        id="signup-email"
                                        type="email"
                                        placeholder="you@example.com"
                                        value={email}
                                        onChange={lambda e: any -> None { email = e.target.value; }}
                                    />
                                </div>
                                <div className="space-y-2">
                                    <Label htmlFor="signup-password">Password</Label>
                                    <Input
                                        id="signup-password"
                                        type="password"
                                        value={password}
                                        onChange={lambda e: any -> None { password = e.target.value; }}
                                    />
                                </div>
                                {error and isSignup ? (
                                    <div className="text-sm text-red-600">{error}</div>
                                ) if error and isSignup else None}
                                <Button 
                                    onClick={handleSignup} 
                                    className="w-full"
                                    disabled={loading}
                                >
                                    {"Creating Account..." if loading else "Sign Up"}
                                </Button>
                            </TabsContent>
                        </Tabs>

                        <div className="mt-4">
                            <div className="relative">
                                <div className="absolute inset-0 flex items-center">
                                    <span className="w-full border-t" />
                                </div>
                                <div className="relative flex justify-center text-xs uppercase">
                                    <span className="bg-white px-2 text-gray-500">Or</span>
                                </div>
                            </div>

                            <Button
                                variant="outline"
                                onClick={handleContinueAsGuest}
                                className="w-full mt-4"
                            >
                                Continue as Guest
                            </Button>
                        </div>
                    </CardContent>
                </Card>
            </div>
        </div>;
}
