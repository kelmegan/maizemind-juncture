"""Juncture - Profile Screen for user settings, history, and statistics."""

# Import UI components
import from .components.ui.button { Button }
import from .components.ui.input { Input }
import from .components.ui.label { Label }
import from .components.ui.card { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from .components.ui.badge { Badge }
import from .components.ui.switch { Switch }
import from .components.ui.select { Select, SelectContent, SelectItem, SelectTrigger, SelectValue }
import from .components.ui.tabs { Tabs, TabsContent, TabsList, TabsTrigger }
import from .components.ui.scroll-area { ScrollArea }

# Import icons
import from .components.icons { 
    ArrowLeft, User, History, Target, TrendingUp, 
    Award, Settings 
}

# Import node types
import from .WelcomeScreen { User as UserNode, Session }
import from .ExportScreen { GetUserSessions }

# Walker to update user profile
walker UpdateUserProfile {
    has userId: str,
        name: str = None,
        userType: str = None,
        goals: list[str] = None,
        theme: str = None,
        accessibilityMode: bool = None;
    
    can update_profile with `root entry {
        # Find user node
        user_node = None;
        for user in -->`root[?UserNode] {
            if user.id == self.userId {
                user_node = user;
                break;
            }
        }
        
        if not user_node {
            report {"error": "User not found"};
            return;
        }
        
        # Update fields if provided
        if self.name is not None {
            user_node.name = self.name;
        }
        if self.userType is not None {
            user_node.userType = self.userType;
        }
        if self.goals is not None {
            user_node.goals = self.goals;
        }
        if self.theme is not None {
            user_node.theme = self.theme;
        }
        if self.accessibilityMode is not None {
            user_node.accessibilityMode = self.accessibilityMode;
        }
        
        report {"success": True, "user": user_node};
    }
}

# Walker to get user profile
walker GetUserProfile {
    has userId: str;
    
    can get_profile with `root entry {
        # Find user node
        user_node = None;
        for user in -->`root[?UserNode] {
            if user.id == self.userId {
                user_node = user;
                break;
            }
        }
        
        if not user_node {
            report {"error": "User not found"};
            return;
        }
        
        report user_node;
    }
}

# Walker to calculate user statistics
walker CalculateUserStats {
    has userId: str;
    
    can calculate_stats with `root entry {
        # Get user sessions
        sessions_result = visit --> GetUserSessions(userId=self.userId);
        sessions = sessions_result.reports[0] if sessions_result.reports else [];
        
        total_sessions = len(sessions);
        
        if total_sessions == 0 {
            report {
                "totalSessions": 0,
                "averageScore": 0,
                "averageImprovement": 0
            };
            return;
        }
        
        # Calculate average score
        total_score = sum([s.finalScore for s in sessions]);
        average_score = int(total_score / total_sessions);
        
        # Calculate average improvement
        total_improvement = sum([s.finalScore - s.initialScore for s in sessions]);
        average_improvement = int(total_improvement / total_sessions);
        
        report {
            "totalSessions": total_sessions,
            "averageScore": average_score,
            "averageImprovement": average_improvement
        };
    }
}

# Client-side component
def:pub ProfileScreen -> JsxElement {
    has userId: str = "",
        isGuest: bool = False,
        name: str = "",
        userType: str = "student",
        goals: list[str] = [],
        theme: str = "system",
        accessibilityMode: bool = False,
        sessions: list = [],
        stats: dict = None,
        activeTab: str = "profile";
    
    # TODO: Get user info from context when implemented
    can with entry {
        # userId = getCurrentUser().id;
        # isGuest = getCurrentUser().isGuest;
        
        # Fetch user profile
        # walker_result = root spawn GetUserProfile(userId=userId);
        # user_data = walker_result.reports[0];
        
        # Fetch sessions
        # sessions_result = root spawn GetUserSessions(userId=userId);
        # sessions = sessions_result.reports[0];
        
        # Calculate stats
        # stats_result = root spawn CalculateUserStats(userId=userId);
        # stats = stats_result.reports[0];
        
        # Mock data for now
        userId = "user_123";
        isGuest = False;
        name = "John Doe";
        userType = "student";
        goals = ["Improve argument structure", "Add more evidence"];
        theme = "system";
        accessibilityMode = False;
        
        sessions = [
            {
                "id": "session_1",
                "title": "Remote work increases productivity",
                "date": "2024-03-08T10:30:00",
                "initialScore": 55,
                "finalScore": 75
            }
        ];
        
        stats = {
            "totalSessions": 1,
            "averageScore": 75,
            "averageImprovement": 20
        };
    }
    
    def handleSaveProfile() -> None {
        # TODO: Replace with actual walker call when backend is integrated
        # walker_result = root spawn UpdateUserProfile(
        #     userId=userId,
        #     name=name,
        #     userType=userType,
        #     goals=goals,
        #     theme=theme,
        #     accessibilityMode=accessibilityMode
        # );
        
        print("Profile saved");
        # TODO: Show success toast
    }
    
    def toggleGoal(goal: str) -> None {
        if goal in goals {
            goals = [g for g in goals if g != goal];
        } else {
            goals = goals + [goal];
        }
    }
    
    def navigateBack() -> None {
        # TODO: Navigate back to generate screen
        # navigate("/generate");
        print("Navigate back to generate");
    }
    
    def navigateToGenerate() -> None {
        # TODO: Navigate to generate screen
        # navigate("/generate");
        print("Navigate to generate");
    }
    
    available_goals = [
        "Improve argument structure",
        "Add more evidence",
        "Address counterarguments",
        "Clarify thesis statements",
        "Strengthen logical connections"
    ];
    
    total_sessions = stats["totalSessions"] if stats else 0;
    average_score = stats["averageScore"] if stats else 0;
    average_improvement = stats["averageImprovement"] if stats else 0;
    
    return (
        <div className="min-h-screen bg-gray-50">
            <header className="bg-white border-b px-4 py-3">
                <div className="max-w-6xl mx-auto flex items-center gap-4">
                    <Button variant="ghost" size="sm" onClick={navigateBack}>
                        <ArrowLeft className="h-4 w-4 mr-2" />
                        Back
                    </Button>
                    <h1 className="text-xl font-bold">Profile</h1>
                </div>
            </header>

            <div className="max-w-6xl mx-auto p-6">
                <Tabs value={activeTab} onValueChange={lambda v -> None { activeTab = v; }} className="space-y-6">
                    <TabsList className="grid w-full grid-cols-3 max-w-md">
                        <TabsTrigger value="profile">
                            <User className="h-4 w-4 mr-2" />
                            Profile
                        </TabsTrigger>
                        <TabsTrigger value="history">
                            <History className="h-4 w-4 mr-2" />
                            History
                        </TabsTrigger>
                        <TabsTrigger value="stats">
                            <TrendingUp className="h-4 w-4 mr-2" />
                            Stats
                        </TabsTrigger>
                    </TabsList>

                    <TabsContent value="profile" className="space-y-6">
                        <div className="grid md:grid-cols-2 gap-6">
                            <Card>
                                <CardHeader>
                                    <CardTitle className="flex items-center gap-2">
                                        <User className="h-5 w-5" />
                                        Basic Information
                                    </CardTitle>
                                    <CardDescription>
                                        {"Sign up to save your profile permanently" 
                                            if isGuest else
                                            "Your account details"}
                                    </CardDescription>
                                </CardHeader>
                                <CardContent className="space-y-4">
                                    <div className="space-y-2">
                                        <Label htmlFor="name">Name</Label>
                                        <Input
                                            id="name"
                                            value={name}
                                            onChange={lambda e: any -> None { name = e.target.value; }}
                                            placeholder="Your name"
                                            disabled={isGuest}
                                        />
                                    </div>

                                    <div className="space-y-2">
                                        <Label htmlFor="user-type">User Type</Label>
                                        <Select 
                                            value={userType} 
                                            onValueChange={lambda v: str -> None { userType = v; }}
                                        >
                                            <SelectTrigger id="user-type">
                                                <SelectValue />
                                            </SelectTrigger>
                                            <SelectContent>
                                                <SelectItem value="student">Student</SelectItem>
                                                <SelectItem value="business">Business</SelectItem>
                                                <SelectItem value="researcher">Researcher</SelectItem>
                                                <SelectItem value="other">Other</SelectItem>
                                            </SelectContent>
                                        </Select>
                                    </div>

                                    {(
                                        <div className="p-3 bg-amber-50 border border-amber-200 rounded-lg text-sm">
                                            <p className="font-medium text-amber-900">Guest Mode</p>
                                            <p className="text-amber-700 text-xs mt-1">
                                                Sign up to save your profile and access it across devices
                                            </p>
                                        </div>
                                    ) if isGuest else None}

                                    {(
                                        <Button onClick={handleSaveProfile} className="w-full">
                                            Save Changes
                                        </Button>
                                    ) if isGuest else None}
                                </CardContent>
                            </Card>

                            <Card>
                                <CardHeader>
                                    <CardTitle className="flex items-center gap-2">
                                        <Target className="h-5 w-5" />
                                        Your Goals
                                    </CardTitle>
                                    <CardDescription>
                                        What do you want to improve?
                                    </CardDescription>
                                </CardHeader>
                                <CardContent className="space-y-3">
                                    {available_goals.map(lambda goal -> any {
                                        is_selected = goal in goals;
                                        return <div
                                            key={goal}
                                            className={
                                                "p-3 border rounded-lg cursor-pointer transition-colors " +
                                                ("bg-indigo-50 border-indigo-300" if is_selected else "hover:bg-gray-50")
                                            }
                                            onClick={lambda -> None { toggleGoal(goal); }}
                                        >
                                            <div className="flex items-center gap-2">
                                                <div
                                                    className={
                                                        "w-4 h-4 rounded border-2 flex items-center justify-center " +
                                                        ("bg-indigo-600 border-indigo-600" if is_selected else "border-gray-300")
                                                    }
                                                >
                                                    {(
                                                        <svg className="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                                                        </svg>
                                                    ) if is_selected else None}
                                                </div>
                                                <span className="text-sm">{goal}</span>
                                            </div>
                                        </div>;
                                    })}
                                </CardContent>
                            </Card>

                            <Card className="md:col-span-2">
                                <CardHeader>
                                    <CardTitle className="flex items-center gap-2">
                                        <Settings className="h-5 w-5" />
                                        Preferences
                                    </CardTitle>
                                </CardHeader>
                                <CardContent className="space-y-4">
                                    <div className="flex items-center justify-between">
                                        <div className="space-y-0.5">
                                            <Label>Theme</Label>
                                            <p className="text-sm text-gray-500">
                                                Choose your preferred color scheme
                                            </p>
                                        </div>
                                        <Select 
                                            value={theme}
                                            onValueChange={lambda v: str -> None { theme = v; }}
                                        >
                                            <SelectTrigger className="w-32">
                                                <SelectValue />
                                            </SelectTrigger>
                                            <SelectContent>
                                                <SelectItem value="light">Light</SelectItem>
                                                <SelectItem value="dark">Dark</SelectItem>
                                                <SelectItem value="system">System</SelectItem>
                                            </SelectContent>
                                        </Select>
                                    </div>

                                    <div className="flex items-center justify-between">
                                        <div className="space-y-0.5">
                                            <Label>Accessibility Mode</Label>
                                            <p className="text-sm text-gray-500">
                                                Enhanced contrast and larger text
                                            </p>
                                        </div>
                                        <Switch
                                            checked={accessibilityMode}
                                            onCheckedChange={lambda v: bool -> None { accessibilityMode = v; }}
                                        />
                                    </div>
                                </CardContent>
                            </Card>
                        </div>
                    </TabsContent>

                    <TabsContent value="history">
                        <Card>
                            <CardHeader>
                                <CardTitle>Session History</CardTitle>
                                <CardDescription>
                                    Your past argument maps and scores
                                </CardDescription>
                            </CardHeader>
                            <CardContent>
                                {(
                                    <div className="text-center py-12">
                                        <History className="h-12 w-12 mx-auto text-gray-300 mb-4" />
                                        <p className="text-gray-500">No sessions yet</p>
                                        <p className="text-sm text-gray-400 mt-1">
                                            Create your first argument map to get started
                                        </p>
                                        <Button
                                            variant="outline"
                                            onClick={navigateToGenerate}
                                            className="mt-4"
                                        >
                                            Create New Argument
                                        </Button>
                                    </div>
                                ) if len(sessions) == 0 else (
                                    <ScrollArea className="h-[500px]">
                                        <div className="space-y-3">
                                            {sessions.map(lambda session -> any {
                                                # Format date
                                                date_obj = datetime.fromisoformat(session["date"]);
                                                formatted_date = date_obj.strftime("%B %d, %Y at %I:%M %p");
                                                
                                                return <div
                                                    key={session["id"]}
                                                    className="p-4 border rounded-lg hover:bg-gray-50 cursor-pointer"
                                                >
                                                    <div className="flex items-start justify-between gap-4">
                                                        <div className="flex-1">
                                                            <h4 className="font-medium">{session["title"]}</h4>
                                                            <p className="text-sm text-gray-500 mt-1">
                                                                {formatted_date}
                                                            </p>
                                                        </div>
                                                        <div className="flex items-center gap-2">
                                                            <Badge variant="outline">
                                                                Score: {session["finalScore"]}
                                                            </Badge>
                                                            {(
                                                                <Badge className="bg-green-100 text-green-700">
                                                                    +{session["finalScore"] - session["initialScore"]}
                                                                </Badge>
                                                            ) if session["finalScore"] > session["initialScore"] else None}
                                                        </div>
                                                    </div>
                                                </div>;
                                            })}
                                        </div>
                                    </ScrollArea>
                                )}
                            </CardContent>
                        </Card>
                    </TabsContent>

                    <TabsContent value="stats">
                        <div className="grid md:grid-cols-3 gap-6">
                            <Card>
                                <CardHeader>
                                    <CardTitle className="text-sm text-gray-600">
                                        Total Sessions
                                    </CardTitle>
                                </CardHeader>
                                <CardContent>
                                    <div className="text-4xl font-bold">{total_sessions}</div>
                                    <p className="text-sm text-gray-500 mt-1">
                                        Argument maps created
                                    </p>
                                </CardContent>
                            </Card>

                            <Card>
                                <CardHeader>
                                    <CardTitle className="text-sm text-gray-600">
                                        Average Score
                                    </CardTitle>
                                </CardHeader>
                                <CardContent>
                                    <div className="text-4xl font-bold text-indigo-600">
                                        {average_score}
                                    </div>
                                    <p className="text-sm text-gray-500 mt-1">Out of 100</p>
                                </CardContent>
                            </Card>

                            <Card>
                                <CardHeader>
                                    <CardTitle className="text-sm text-gray-600">
                                        Avg. Improvement
                                    </CardTitle>
                                </CardHeader>
                                <CardContent>
                                    <div className="text-4xl font-bold text-green-600">
                                        +{average_improvement}
                                    </div>
                                    <p className="text-sm text-gray-500 mt-1">Per session</p>
                                </CardContent>
                            </Card>

                            <Card className="md:col-span-3">
                                <CardHeader>
                                    <CardTitle className="flex items-center gap-2">
                                        <Award className="h-5 w-5" />
                                        Achievements
                                    </CardTitle>
                                    <CardDescription>
                                        Milestones you've unlocked
                                    </CardDescription>
                                </CardHeader>
                                <CardContent>
                                    <div className="grid md:grid-cols-2 gap-3">
                                        <div
                                            className={
                                                "p-4 border rounded-lg " +
                                                ("bg-gradient-to-br from-yellow-50 to-yellow-100 border-yellow-300"
                                                    if total_sessions >= 1 else
                                                    "bg-gray-50 border-gray-200 opacity-50")
                                            }
                                        >
                                            <div className="text-2xl mb-2">🎯</div>
                                            <h4 className="font-semibold">First Steps</h4>
                                            <p className="text-sm text-gray-600">
                                                Create your first argument map
                                            </p>
                                        </div>

                                        <div
                                            className={
                                                "p-4 border rounded-lg " +
                                                ("bg-gradient-to-br from-green-50 to-green-100 border-green-300"
                                                    if average_score >= 75 else
                                                    "bg-gray-50 border-gray-200 opacity-50")
                                            }
                                        >
                                            <div className="text-2xl mb-2">⭐</div>
                                            <h4 className="font-semibold">Strong Reasoner</h4>
                                            <p className="text-sm text-gray-600">
                                                Achieve an average score of 75+
                                            </p>
                                        </div>

                                        <div
                                            className={
                                                "p-4 border rounded-lg " +
                                                ("bg-gradient-to-br from-blue-50 to-blue-100 border-blue-300"
                                                    if total_sessions >= 5 else
                                                    "bg-gray-50 border-gray-200 opacity-50")
                                            }
                                        >
                                            <div className="text-2xl mb-2">📚</div>
                                            <h4 className="font-semibold">Dedicated</h4>
                                            <p className="text-sm text-gray-600">
                                                Create 5 argument maps
                                            </p>
                                        </div>

                                        <div
                                            className={
                                                "p-4 border rounded-lg " +
                                                ("bg-gradient-to-br from-purple-50 to-purple-100 border-purple-300"
                                                    if average_improvement >= 20 else
                                                    "bg-gray-50 border-gray-200 opacity-50")
                                            }
                                        >
                                            <div className="text-2xl mb-2">🚀</div>
                                            <h4 className="font-semibold">Growth Mindset</h4>
                                            <p className="text-sm text-gray-600">
                                                Average +20 score improvement
                                            </p>
                                        </div>
                                    </div>
                                </CardContent>
                            </Card>
                        </div>
                    </TabsContent>
                </Tabs>
            </div>
        </div>
    );
}
