"""Juncture - Profile Screen for user settings, history, and statistics."""

sv import from ...main { GetContext, GetUserSessions, CalculateUserStats, UpdateUserProfile, UpdateContext }
import from "lucide-react" { User, History, Target, TrendingUp, Award, Settings }

import from ..components.Badge { Badge }
import from ..components.Button { Button }
import from ..components.Card { Card }
import from ..components.Switch { Switch }
import from ..components.Tabs { Tabs, TabsContent, TabsList, TabsTrigger }
import from ..components.Header { Header }

def:pub ProfileScreen(props: any) -> JsxElement {
    navigate = props.navigate;
    screen_data = props.screenData if props.screenData else {};
    back_to = screen_data["from"] if "from" in screen_data else "generate";

    has userId: str = "",
        isGuest: bool = False,
        name: str = "",
        userType: str = "student",
        goals: list[str] = [],
        theme: str = "system",
        accessibilityMode: bool = False,
        sessions: list = [],
        stats: dict = None,
        activeTab: str = "profile",
        loading: bool = True;

    async def loadContext() -> None {
        loading = True;
        try {
            ctx = await root spawn GetContext();
            if ctx and ctx["currentUser"] and "id" in ctx["currentUser"] {
                userId = ctx["currentUser"]["id"];
                isGuest = ctx["currentUser"]["isGuest"] if "isGuest" in ctx["currentUser"] else False;
                name = ctx["currentUser"]["name"] if "name" in ctx["currentUser"] else "";
                userType = ctx["currentUser"]["userType"] if "userType" in ctx["currentUser"] else "student";
                goals = ctx["currentUser"]["goals"] if "goals" in ctx["currentUser"] else [];
                theme = ctx["currentUser"]["theme"] if "theme" in ctx["currentUser"] else "system";
                accessibilityMode = ctx["currentUser"]["accessibilityMode"] if "accessibilityMode" in ctx["currentUser"] else False;
            }

            if userId and not isGuest {
                try {
                    sess_result = await root spawn GetUserSessions(userId=userId);
                    raw_sessions = sess_result.reports[0] if sess_result.reports else [];
                    sessions = raw_sessions if raw_sessions else [];
                } except Exception as e {
                    print(f"Error loading sessions: {e}");
                }

                try {
                    stats_result = await root spawn CalculateUserStats(userId=userId);
                    raw_stats = stats_result.reports[0] if stats_result.reports else None;
                    stats = raw_stats if raw_stats else None;
                } except Exception as e {
                    print(f"Error loading stats: {e}");
                }
            }
        } except Exception {
            # Context not available
        }

        if not stats {
            stats = {
                "totalSessions": len(sessions),
                "averageScore": 0,
                "averageImprovement": 0
            };
        }

        loading = False;
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

        await root spawn UpdateContext(
            currentUser={
                "id": userId,
                "name": name,
                "email": "",
                "userType": userType,
                "goals": goals,
                "theme": theme,
                "accessibilityMode": accessibilityMode,
                "isGuest": isGuest
            }
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

    if isGuest {
        return (
            <div className="profile-page">
                <Header navigate={navigate} screen="profile" title="Profile" backTo={back_to} isGuest={isGuest} />
                <div className="guest-wall-outer">
                    <div className="guest-wall-card">
                        <div className="guest-wall-icon-ring">
                            <User className="guest-wall-icon" />
                        </div>
                        <h2 className="guest-wall-title">You're browsing as a guest</h2>
                        <p className="guest-wall-body">
                            Create a free account to save your argument maps, track your
                            progress over time, and unlock your full reasoning history.
                        </p>
                        <div className="guest-wall-actions">
                            <Button
                                label={(<><UserPlus className="guest-wall-btn-icon" />Create Account</>)}
                                onClick={lambda -> None { navigate("welcome", {"tab": "signup"}); }}
                                className="guest-wall-signup-btn"
                            />
                            <Button
                                label={(<><LogIn className="guest-wall-btn-icon" />Sign In</>)}
                                variant="outline"
                                onClick={lambda -> None { navigate("welcome", {"tab": "login"}); }}
                                className="guest-wall-login-btn"
                            />
                        </div>
                        <div className="guest-wall-perks">
                            <div className="guest-wall-perk">
                                <span className="guest-wall-perk-icon">📁</span>
                                <span>Save and revisit past argument maps</span>
                            </div>
                            <div className="guest-wall-perk">
                                <span className="guest-wall-perk-icon">📈</span>
                                <span>Track your reasoning score over time</span>
                            </div>
                            <div className="guest-wall-perk">
                                <span className="guest-wall-perk-icon">🏆</span>
                                <span>Earn achievements as you improve</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        );
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
        <div className="profile-page">
            <Header navigate={navigate} screen="profile" title="Profile" backTo={back_to} isGuest={isGuest}/>

            <div className="profile-content">
                <Tabs value={activeTab} onValueChange={handleTabChange} className="profile-tabs">
                    <TabsList className="profile-tabs-list">
                        <TabsTrigger value="profile" activeValue={activeTab} onValueChange={handleTabChange}>
                            <User className="profile-tab-icon" />Profile
                        </TabsTrigger>
                        <TabsTrigger value="history" activeValue={activeTab} onValueChange={handleTabChange}>
                            <History className="profile-tab-icon" />History
                        </TabsTrigger>
                        <TabsTrigger value="stats" activeValue={activeTab} onValueChange={handleTabChange}>
                            <TrendingUp className="profile-tab-icon" />Stats
                        </TabsTrigger>
                    </TabsList>

                    <TabsContent value="profile" activeValue={activeTab} className="profile-tab-content">
                        <div className="profile-grid">
                            <Card
                                title={(<span className="card-title-icon"><User />Basic Information</span>)}
                                description={"Sign up to save your profile permanently" if isGuest else "Your account details"}
                            >
                                <div className="profile-form">
                                    <div className="profile-field">
                                        <label className="profile-label">Name</label>
                                        <input
                                            className="profile-input"
                                            id="name"
                                            value={name}
                                            onChange={handleNameChange}
                                            placeholder="Your name"
                                            disabled={isGuest}
                                        />
                                    </div>

                                    <div className="profile-field">
                                        <label className="profile-label">User Type</label>
                                        <select
                                            className="profile-select"
                                            value={userType}
                                            onChange={handleUserTypeChange}
                                        >
                                            <option value="student">Student</option>
                                            <option value="business">Business</option>
                                            <option value="researcher">Researcher</option>
                                            <option value="other">Other</option>
                                        </select>
                                    </div>

                                    {(
                                        <div className="profile-guest-notice">
                                            <p className="profile-guest-title">Guest Mode</p>
                                            <p className="profile-guest-body">
                                                Sign up to save your profile and access it across devices
                                            </p>
                                        </div>
                                    ) if isGuest else None}

                                    {(
                                        <Button label="Save Changes" onClick={handleSaveProfile} className="profile-save-btn" />
                                    ) if not isGuest else None}
                                </div>
                            </Card>

                            <Card
                                title={(<span className="card-title-icon"><Target />Your Goals</span>)}
                                description="What do you want to improve?"
                            >
                                <div className="profile-goals-list">
                                    {available_goals.map(lambda goal -> any {
                                        is_selected = goal in goals;
                                        return <div
                                            key={goal}
                                            className={"profile-goal-item" + (" profile-goal-item-selected" if is_selected else "")}
                                            onClick={lambda -> None { toggleGoal(goal); }}
                                        >
                                            <div className="profile-goal-row">
                                                <div className={"profile-goal-checkbox" + (" profile-goal-checkbox-selected" if is_selected else "")}>
                                                    {(
                                                        <svg className="profile-goal-check-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                                                        </svg>
                                                    ) if is_selected else None}
                                                </div>
                                                <span className="profile-goal-label">{goal}</span>
                                            </div>
                                        </div>;
                                    })}
                                </div>
                            </Card>

                            <Card title={(<span className="card-title-icon"><Settings />Preferences</span>)} className="profile-prefs-card">
                                <div className="profile-prefs-list">
                                    <div className="profile-pref-row">
                                        <div className="profile-pref-info">
                                            <label className="profile-label">Theme</label>
                                            <p className="profile-pref-description">Choose your preferred color scheme</p>
                                        </div>
                                        <select
                                            className="profile-select-sm"
                                            value={theme}
                                            onChange={handleThemeChange}
                                        >
                                            <option value="light">Light</option>
                                            <option value="dark">Dark</option>
                                            <option value="system">System</option>
                                        </select>
                                    </div>

                                    <div className="profile-pref-row">
                                        <div className="profile-pref-info">
                                            <label className="profile-label">Accessibility Mode</label>
                                            <p className="profile-pref-description">Enhanced contrast and larger text</p>
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
                                <div className="profile-history-empty">
                                    <History className="profile-history-empty-icon" />
                                    <p className="profile-history-empty-title">No sessions yet</p>
                                    <p className="profile-history-empty-sub">Create your first argument map to get started</p>
                                    <Button label="Create New Argument" variant="outline" onClick={navigateToGenerate} className="profile-history-empty-btn" />
                                </div>
                            ) if len(sessions) == 0 else (
                                <div className="profile-history-list">
                                    <div className="profile-history-items">
                                        {sessions.map(lambda session -> any {
                                            formatted_date = str(session["date"] if "date" in session else "").replace("T", " at ");
                                            return <div
                                                key={session["id"] if "id" in session else ""}
                                                className="profile-session-item"
                                            >
                                                <div className="profile-session-inner">
                                                    <div className="profile-session-body">
                                                        <h4 className="profile-session-title">{session["title"] if "title" in session else "Untitled"}</h4>
                                                        <p className="profile-session-date">{formatted_date}</p>
                                                    </div>
                                                    <div className="profile-session-badges">
                                                        <Badge variant="outline">Score: {session["finalScore"] if "finalScore" in session else 0}</Badge>
                                                        {(
                                                            <Badge className="badge-improvement">
                                                                +{session["finalScore"] - session["initialScore"]}
                                                            </Badge>
                                                        ) if ("finalScore" in session and "initialScore" in session and session["finalScore"] > session["initialScore"]) else None}
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
                        <div className="profile-stats-grid">
                            <Card title={<span className="profile-stat-label">Total Sessions</span>}>
                                <div className="profile-stat-number">{total_sessions}</div>
                                <p className="profile-stat-sub">Argument maps created</p>
                            </Card>

                            <Card title={<span className="profile-stat-label">Average Score</span>}>
                                <div className="profile-stat-number profile-stat-number-accent">{average_score}</div>
                                <p className="profile-stat-sub">Out of 100</p>
                            </Card>

                            <Card title={<span className="profile-stat-label">Avg. Improvement</span>}>
                                <div className="profile-stat-number profile-stat-number-good">+{average_improvement}</div>
                                <p className="profile-stat-sub">Per session</p>
                            </Card>

                            <Card
                                title={(<span className="card-title-icon"><Award />Achievements</span>)}
                                description="Milestones you've unlocked"
                                className="profile-achievements-card"
                            >
                                <div className="profile-achievements-grid">
                                    <div className={"profile-achievement" + (" profile-achievement-gold" if total_sessions >= 1 else " profile-achievement-locked")}>
                                        <div className="profile-achievement-icon">🎯</div>
                                        <h4 className="profile-achievement-title">First Steps</h4>
                                        <p className="profile-achievement-desc">Create your first argument map</p>
                                    </div>

                                    <div className={"profile-achievement" + (" profile-achievement-green" if average_score >= 75 else " profile-achievement-locked")}>
                                        <div className="profile-achievement-icon">⭐</div>
                                        <h4 className="profile-achievement-title">Strong Reasoner</h4>
                                        <p className="profile-achievement-desc">Achieve an average score of 75+</p>
                                    </div>

                                    <div className={"profile-achievement" + (" profile-achievement-blue" if total_sessions >= 5 else " profile-achievement-locked")}>
                                        <div className="profile-achievement-icon">📚</div>
                                        <h4 className="profile-achievement-title">Dedicated</h4>
                                        <p className="profile-achievement-desc">Create 5 argument maps</p>
                                    </div>

                                    <div className={"profile-achievement" + (" profile-achievement-purple" if average_improvement >= 20 else " profile-achievement-locked")}>
                                        <div className="profile-achievement-icon">🚀</div>
                                        <h4 className="profile-achievement-title">Growth Mindset</h4>
                                        <p className="profile-achievement-desc">Average +20 score improvement</p>
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
