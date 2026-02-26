import { useState, useEffect } from "react";
import { useNavigate } from "react-router";
import { useApp } from "../store/AppContext";
import { Button } from "../components/ui/button";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../components/ui/card";
import { Badge } from "../components/ui/badge";
import { Switch } from "../components/ui/switch";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../components/ui/tabs";
import { ArrowLeft, User, History, Target, TrendingUp, Award, Settings } from "lucide-react";
import { ScrollArea } from "../components/ui/scroll-area";

export function ProfileScreen() {
  const navigate = useNavigate();
  const { user, setUser, sessions, isGuest } = useApp();

  const [name, setName] = useState(user?.name || "");
  const [userType, setUserType] = useState<string>(user?.userType || "student");
  const [goals, setGoals] = useState<string[]>(user?.goals || []);
  const [theme, setTheme] = useState<string>(user?.theme || "system");
  const [accessibilityMode, setAccessibilityMode] = useState(
    user?.accessibilityMode || false
  );

  useEffect(() => {
    if (user) {
      setName(user.name);
      setUserType(user.userType);
      setGoals(user.goals);
      setTheme(user.theme);
      setAccessibilityMode(user.accessibilityMode);
    }
  }, [user]);

  const handleSaveProfile = () => {
    setUser({
      name,
      userType: userType as any,
      goals,
      strengths: user?.strengths || [],
      weaknesses: user?.weaknesses || [],
      theme: theme as any,
      accessibilityMode,
    });
  };

  const toggleGoal = (goal: string) => {
    setGoals((prev) =>
      prev.includes(goal) ? prev.filter((g) => g !== goal) : [...prev, goal]
    );
  };

  const availableGoals = [
    "Improve argument structure",
    "Add more evidence",
    "Address counterarguments",
    "Clarify thesis statements",
    "Strengthen logical connections",
  ];

  const totalSessions = sessions.length;
  const averageScore =
    totalSessions > 0
      ? Math.round(
          sessions.reduce((sum, s) => sum + s.finalScore, 0) / totalSessions
        )
      : 0;
  const averageImprovement =
    totalSessions > 0
      ? Math.round(
          sessions.reduce((sum, s) => sum + (s.finalScore - s.initialScore), 0) /
            totalSessions
        )
      : 0;

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b px-4 py-3">
        <div className="max-w-6xl mx-auto flex items-center gap-4">
          <Button variant="ghost" size="sm" onClick={() => navigate("/generate")}>
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back
          </Button>
          <h1 className="text-xl font-bold">Profile</h1>
        </div>
      </header>

      <div className="max-w-6xl mx-auto p-6">
        <Tabs defaultValue="profile" className="space-y-6">
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

          {/* Profile Tab */}
          <TabsContent value="profile" className="space-y-6">
            <div className="grid md:grid-cols-2 gap-6">
              {/* Basic Info */}
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <User className="h-5 w-5" />
                    Basic Information
                  </CardTitle>
                  <CardDescription>
                    {isGuest
                      ? "Sign up to save your profile permanently"
                      : "Your account details"}
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="name">Name</Label>
                    <Input
                      id="name"
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      placeholder="Your name"
                      disabled={isGuest}
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="user-type">User Type</Label>
                    <Select value={userType} onValueChange={setUserType}>
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

                  {isGuest && (
                    <div className="p-3 bg-amber-50 border border-amber-200 rounded-lg text-sm">
                      <p className="font-medium text-amber-900">Guest Mode</p>
                      <p className="text-amber-700 text-xs mt-1">
                        Sign up to save your profile and access it across devices
                      </p>
                    </div>
                  )}

                  {!isGuest && (
                    <Button onClick={handleSaveProfile} className="w-full">
                      Save Changes
                    </Button>
                  )}
                </CardContent>
              </Card>

              {/* Goals */}
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
                  {availableGoals.map((goal) => (
                    <div
                      key={goal}
                      className={`
                        p-3 border rounded-lg cursor-pointer transition-colors
                        ${
                          goals.includes(goal)
                            ? "bg-indigo-50 border-indigo-300"
                            : "hover:bg-gray-50"
                        }
                      `}
                      onClick={() => toggleGoal(goal)}
                    >
                      <div className="flex items-center gap-2">
                        <div
                          className={`
                          w-4 h-4 rounded border-2 flex items-center justify-center
                          ${
                            goals.includes(goal)
                              ? "bg-indigo-600 border-indigo-600"
                              : "border-gray-300"
                          }
                        `}
                        >
                          {goals.includes(goal) && (
                            <svg
                              className="w-3 h-3 text-white"
                              fill="none"
                              viewBox="0 0 24 24"
                              stroke="currentColor"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={3}
                                d="M5 13l4 4L19 7"
                              />
                            </svg>
                          )}
                        </div>
                        <span className="text-sm">{goal}</span>
                      </div>
                    </div>
                  ))}
                </CardContent>
              </Card>

              {/* Preferences */}
              <Card className="md:col-span-2">
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Settings className="h-5 w-5" />
                    Preferences
                  </CardTitle>
                  <CardDescription>
                    Customize your experience
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="flex items-center justify-between">
                    <div className="space-y-0.5">
                      <Label htmlFor="theme">Theme</Label>
                      <p className="text-sm text-gray-500">
                        Choose your preferred color scheme
                      </p>
                    </div>
                    <Select value={theme} onValueChange={setTheme}>
                      <SelectTrigger className="w-[180px]" id="theme">
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
                      <Label htmlFor="accessibility">Accessibility Mode</Label>
                      <p className="text-sm text-gray-500">
                        Enhanced contrast and larger text
                      </p>
                    </div>
                    <Switch
                      id="accessibility"
                      checked={accessibilityMode}
                      onCheckedChange={setAccessibilityMode}
                    />
                  </div>
                </CardContent>
              </Card>
            </div>
          </TabsContent>

          {/* History Tab */}
          <TabsContent value="history">
            <Card>
              <CardHeader>
                <CardTitle>Session History</CardTitle>
                <CardDescription>
                  Your past argument maps and scores
                </CardDescription>
              </CardHeader>
              <CardContent>
                {sessions.length === 0 ? (
                  <div className="text-center py-12">
                    <History className="h-12 w-12 mx-auto text-gray-300 mb-4" />
                    <p className="text-gray-500">No sessions yet</p>
                    <p className="text-sm text-gray-400 mt-1">
                      Create your first argument map to get started
                    </p>
                    <Button
                      variant="outline"
                      onClick={() => navigate("/generate")}
                      className="mt-4"
                    >
                      Create New Argument
                    </Button>
                  </div>
                ) : (
                  <ScrollArea className="h-[500px]">
                    <div className="space-y-3">
                      {sessions.map((session) => (
                        <div
                          key={session.id}
                          className="p-4 border rounded-lg hover:bg-gray-50 cursor-pointer"
                        >
                          <div className="flex items-start justify-between gap-4">
                            <div className="flex-1">
                              <h4 className="font-medium">{session.title}</h4>
                              <p className="text-sm text-gray-500 mt-1">
                                {new Date(session.date).toLocaleDateString("en-US", {
                                  month: "long",
                                  day: "numeric",
                                  year: "numeric",
                                  hour: "numeric",
                                  minute: "2-digit",
                                })}
                              </p>
                            </div>
                            <div className="flex items-center gap-2">
                              <Badge variant="outline">
                                Score: {session.finalScore}
                              </Badge>
                              {session.finalScore > session.initialScore && (
                                <Badge className="bg-green-100 text-green-700">
                                  +{session.finalScore - session.initialScore}
                                </Badge>
                              )}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </ScrollArea>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          {/* Stats Tab */}
          <TabsContent value="stats">
            <div className="grid md:grid-cols-3 gap-6">
              <Card>
                <CardHeader>
                  <CardTitle className="text-sm text-gray-600">
                    Total Sessions
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="text-4xl font-bold">{totalSessions}</div>
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
                    {averageScore}
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
                    +{averageImprovement}
                  </div>
                  <p className="text-sm text-gray-500 mt-1">Per session</p>
                </CardContent>
              </Card>

              {/* Achievements */}
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
                      className={`
                      p-4 border rounded-lg
                      ${
                        totalSessions >= 1
                          ? "bg-gradient-to-br from-yellow-50 to-yellow-100 border-yellow-300"
                          : "bg-gray-50 border-gray-200 opacity-50"
                      }
                    `}
                    >
                      <div className="text-2xl mb-2">🎯</div>
                      <h4 className="font-semibold">First Steps</h4>
                      <p className="text-sm text-gray-600">
                        Create your first argument map
                      </p>
                    </div>

                    <div
                      className={`
                      p-4 border rounded-lg
                      ${
                        averageScore >= 75
                          ? "bg-gradient-to-br from-green-50 to-green-100 border-green-300"
                          : "bg-gray-50 border-gray-200 opacity-50"
                      }
                    `}
                    >
                      <div className="text-2xl mb-2">⭐</div>
                      <h4 className="font-semibold">Strong Reasoner</h4>
                      <p className="text-sm text-gray-600">
                        Achieve an average score of 75+
                      </p>
                    </div>

                    <div
                      className={`
                      p-4 border rounded-lg
                      ${
                        totalSessions >= 5
                          ? "bg-gradient-to-br from-blue-50 to-blue-100 border-blue-300"
                          : "bg-gray-50 border-gray-200 opacity-50"
                      }
                    `}
                    >
                      <div className="text-2xl mb-2">📚</div>
                      <h4 className="font-semibold">Dedicated</h4>
                      <p className="text-sm text-gray-600">
                        Create 5 argument maps
                      </p>
                    </div>

                    <div
                      className={`
                      p-4 border rounded-lg
                      ${
                        averageImprovement >= 20
                          ? "bg-gradient-to-br from-purple-50 to-purple-100 border-purple-300"
                          : "bg-gray-50 border-gray-200 opacity-50"
                      }
                    `}
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
