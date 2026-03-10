"""Juncture - Profile Screen for user settings, history, and statistics."""

import from "lucide-react" { ArrowLeft, User, History, Target, TrendingUp, Award, Settings }

import from ..components.Badge { Badge }
import from ..components.Button { Button }
import from ..components.Card { Card }
import from ..components.Switch { Switch }
import from ..components.Tabs { Tabs, TabsContent, TabsList, TabsTrigger }

def:pub ProfileScreen(props: any) -> JsxElement {
    navigate = props.navigate;

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

    async def loadContext() -> None {
        ctx = await root spawn GetContext();
        if ctx and ctx.currentUser {
            userId = ctx.currentUser.id;
            isGuest = ctx.currentUser.isGuest;
        }

        # Mock data for now - replace with walker calls when backend integrated
        # profile_result = await root spawn GetUserProfile(userId=userId);
        # sessions_result = await root spawn GetUserSessions(userId=userId);
        # stats_result = await root spawn CalculateUserStats(userId=userId);

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

    can with entry {
        loadContext();
    }

    async def handleSaveProfile() -> None {
        await root spawn UpdateUserProfile(
            userId=userId,
            name=name,
            userType=userType,
            goals=goals,
            theme=theme,
            accessibilityMode=accessibilityMode
        );
    }

    def toggleGoal(goal: str) -> None {
        if goal in goals {
            goals = [g for g in goals if g != goal];
        } else {
            goals = goals + [goal];
        }
    }

    def navigateToGenerate() -> None {
        navigate("generate");
    }

    def handleTabChange(v: str) -> None {
        activeTab = v;
    }

    def handleNameChange(e: any) -> None {
        name = e.target.value;
    }

    def handleUserTypeChange(e: any) -> None {
        userType = e.target.value;
    }

    def handleThemeChange(v: str) -> None {
        theme = v;
    }

    def handleAccessibilityChange(v: bool) -> None {
        accessibilityMode = v;
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
                    <Button label={(<><ArrowLeft className="h-4 w-4 mr-2" />Back</>)} variant="ghost" size="sm" onClick={navigateToGenerate} />
                    <h1 className="text-xl font-bold">Profile</h1>
                </div>
            </header>

            <div className="max-w-6xl mx-auto p-6">
                <Tabs value={activeTab} onValueChange={handleTabChange} className="space-y-6">
                    <TabsList className="grid w-full grid-cols-3 max-w-md">
                        <TabsTrigger value="profile" activeValue={activeTab} onValueChange={handleTabChange}>
                            <User className="h-4 w-4 mr-2" />Profile
                        </TabsTrigger>
                        <TabsTrigger value="history" activeValue={activeTab} onValueChange={handleTabChange}>
                            <History className="h-4 w-4 mr-2" />History
                        </TabsTrigger>
                        <TabsTrigger value="stats" activeValue={activeTab} onValueChange={handleTabChange}>
                            <TrendingUp className="h-4 w-4 mr-2" />Stats
                        </TabsTrigger>
                    </TabsList>

                    <TabsContent value="profile" activeValue={activeTab} className="space-y-6">
                        <div className="grid md:grid-cols-2 gap-6">
                            <Card
                                title={<><User className="h-5 w-5" />Basic Information</>}
                                description={"Sign up to save your profile permanently" if isGuest else "Your account details"}
                            >
                                <div className="space-y-4">
                                    <div className="space-y-2">
                                        <label>Name</label>
                                        <input
                                            id="name"
                                            value={name}
                                            onChange={handleNameChange}
                                            placeholder="Your name"
                                            disabled={isGuest}
                                        />
                                    </div>

                                    <div className="space-y-2">
                                        <label>User Type</label>
                                        <select
                                            value={userType}
                                            onChange={handleUserTypeChange}
                                            className="border-input flex h-9 w-full rounded-md border bg-input-background px-3 py-2 text-sm outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50"
                                        >
                                            <option value="student">Student</option>
                                            <option value="business">Business</option>
                                            <option value="researcher">Researcher</option>
                                            <option value="other">Other</option>
                                        </select>
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
                                        <Button label="Save Changes" onClick={handleSaveProfile} className="w-full" />
                                    ) if not isGuest else None}
                                </div>
                            </Card>

                            <Card
                                title={<><Target className="h-5 w-5" />Your Goals</>}
                                description="What do you want to improve?"
                            >
                                <div className="space-y-3">
                                    {available_goals.map(lambda goal -> any {
                                        is_selected = goal in goals;
                                        return <div
                                            key={goal}
                                            className={"p-3 border rounded-lg cursor-pointer transition-colors " + ("bg-indigo-50 border-indigo-300" if is_selected else "hover:bg-gray-50")}
                                            onClick={lambda -> None { toggleGoal(goal); }}
                                        >
                                            <div className="flex items-center gap-2">
                                                <div className={"w-4 h-4 rounded border-2 flex items-center justify-center " + ("bg-indigo-600 border-indigo-600" if is_selected else "border-gray-300")}>
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
                                </div>
                            </Card>

                            <Card title={<><Settings className="h-5 w-5" />Preferences</>} className="md:col-span-2">
                                <div className="space-y-4">
                                    <div className="flex items-center justify-between">
                                        <div className="space-y-0.5">
                                            <label>Theme</label>
                                            <p className="text-sm text-gray-500">Choose your preferred color scheme</p>
                                        </div>
                                        <select
                                            value={theme}
                                            onChange={handleThemeChange}
                                            className="border-input flex h-9 rounded-md border bg-input-background px-3 py-2 text-sm outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 w-32"
                                        >
                                            <option value="light">Light</option>
                                            <option value="dark">Dark</option>
                                            <option value="system">System</option>
                                        </select>
                                    </div>

                                    <div className="flex items-center justify-between">
                                        <div className="space-y-0.5">
                                            <label>Accessibility Mode</label>
                                            <p className="text-sm text-gray-500">Enhanced contrast and larger text</p>
                                        </div>
                                        <Switch checked={accessibilityMode} onCheckedChange={handleAccessibilityChange} />
                                    </div>
                                </div>
                            </Card>
                        </div>
                    </TabsContent>

                    <TabsContent value="history" activeValue={activeTab}>
                        <Card title="Session History" description="Your past argument maps and scores">
                            {(
                                <div className="text-center py-12">
                                    <History className="h-12 w-12 mx-auto text-gray-300 mb-4" />
                                    <p className="text-gray-500">No sessions yet</p>
                                    <p className="text-sm text-gray-400 mt-1">Create your first argument map to get started</p>
                                    <Button label="Create New Argument" variant="outline" onClick={navigateToGenerate} className="mt-4" />
                                </div>
                            ) if len(sessions) == 0 else (
                                <div className="h-[500px] overflow-y-auto">
                                    <div className="space-y-3">
                                        {sessions.map(lambda session -> any {
                                            formatted_date = session["date"].replace("T", " at ");
                                            return <div
                                                key={session["id"]}
                                                className="p-4 border rounded-lg hover:bg-gray-50 cursor-pointer"
                                            >
                                                <div className="flex items-start justify-between gap-4">
                                                    <div className="flex-1">
                                                        <h4 className="font-medium">{session["title"]}</h4>
                                                        <p className="text-sm text-gray-500 mt-1">{formatted_date}</p>
                                                    </div>
                                                    <div className="flex items-center gap-2">
                                                        <Badge variant="outline">Score: {session["finalScore"]}</Badge>
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
                                </div>
                            )}
                        </Card>
                    </TabsContent>

                    <TabsContent value="stats" activeValue={activeTab}>
                        <div className="grid md:grid-cols-3 gap-6">
                            <Card title={<span className="text-sm text-gray-600">Total Sessions</span>}>
                                <div className="text-4xl font-bold">{total_sessions}</div>
                                <p className="text-sm text-gray-500 mt-1">Argument maps created</p>
                            </Card>

                            <Card title={<span className="text-sm text-gray-600">Average Score</span>}>
                                <div className="text-4xl font-bold text-indigo-600">{average_score}</div>
                                <p className="text-sm text-gray-500 mt-1">Out of 100</p>
                            </Card>

                            <Card title={<span className="text-sm text-gray-600">Avg. Improvement</span>}>
                                <div className="text-4xl font-bold text-green-600">+{average_improvement}</div>
                                <p className="text-sm text-gray-500 mt-1">Per session</p>
                            </Card>

                            <Card
                                title={<><Award className="h-5 w-5" />Achievements</>}
                                description="Milestones you've unlocked"
                                className="md:col-span-3"
                            >
                                <div className="grid md:grid-cols-2 gap-3">
                                    <div className={"p-4 border rounded-lg " + ("bg-gradient-to-br from-yellow-50 to-yellow-100 border-yellow-300" if total_sessions >= 1 else "bg-gray-50 border-gray-200 opacity-50")}>
                                        <div className="text-2xl mb-2">🎯</div>
                                        <h4 className="font-semibold">First Steps</h4>
                                        <p className="text-sm text-gray-600">Create your first argument map</p>
                                    </div>

                                    <div className={"p-4 border rounded-lg " + ("bg-gradient-to-br from-green-50 to-green-100 border-green-300" if average_score >= 75 else "bg-gray-50 border-gray-200 opacity-50")}>
                                        <div className="text-2xl mb-2">⭐</div>
                                        <h4 className="font-semibold">Strong Reasoner</h4>
                                        <p className="text-sm text-gray-600">Achieve an average score of 75+</p>
                                    </div>

                                    <div className={"p-4 border rounded-lg " + ("bg-gradient-to-br from-blue-50 to-blue-100 border-blue-300" if total_sessions >= 5 else "bg-gray-50 border-gray-200 opacity-50")}>
                                        <div className="text-2xl mb-2">📚</div>
                                        <h4 className="font-semibold">Dedicated</h4>
                                        <p className="text-sm text-gray-600">Create 5 argument maps</p>
                                    </div>

                                    <div className={"p-4 border rounded-lg " + ("bg-gradient-to-br from-purple-50 to-purple-100 border-purple-300" if average_improvement >= 20 else "bg-gray-50 border-gray-200 opacity-50")}>
                                        <div className="text-2xl mb-2">🚀</div>
                                        <h4 className="font-semibold">Growth Mindset</h4>
                                        <p className="text-sm text-gray-600">Average +20 score improvement</p>
                                    </div>
                                </div>
                            </Card>
                        </div>
                    </TabsContent>
                </Tabs>
            </div>
        </div>
    );
}