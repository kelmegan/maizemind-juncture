import { useState } from "react";
import { useNavigate } from "react-router";
import { Button } from "../components/ui/button";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../components/ui/tabs";
import { useApp } from "../store/AppContext";
import { Brain, Lightbulb, TrendingUp } from "lucide-react";

export function WelcomeScreen() {
  const navigate = useNavigate();
  const { setUser, setIsGuest } = useApp();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");

  const handleSignUp = () => {
    // Mock sign up
    setUser({
      name,
      userType: "student",
      goals: [],
      strengths: [],
      weaknesses: [],
      theme: "system",
      accessibilityMode: false,
    });
    setIsGuest(false);
    navigate("/generate");
  };

  const handleLogin = () => {
    // Mock login
    setUser({
      name: email.split("@")[0],
      userType: "student",
      goals: [],
      strengths: [],
      weaknesses: [],
      theme: "system",
      accessibilityMode: false,
    });
    setIsGuest(false);
    navigate("/generate");
  };

  const handleContinueAsGuest = () => {
    setIsGuest(true);
    navigate("/generate");
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-white to-purple-50 flex items-center justify-center p-4">
      <div className="w-full max-w-5xl grid md:grid-cols-2 gap-8 items-center">
        {/* Left side - Branding */}
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

        {/* Right side - Auth */}
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
                    onChange={(e) => setEmail(e.target.value)}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="login-password">Password</Label>
                  <Input
                    id="login-password"
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                  />
                </div>
                <Button onClick={handleLogin} className="w-full">
                  Login
                </Button>
              </TabsContent>

              <TabsContent value="signup" className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="signup-name">Name</Label>
                  <Input
                    id="signup-name"
                    placeholder="Your name"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="signup-email">Email</Label>
                  <Input
                    id="signup-email"
                    type="email"
                    placeholder="you@example.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="signup-password">Password</Label>
                  <Input
                    id="signup-password"
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                  />
                </div>
                <Button onClick={handleSignUp} className="w-full">
                  Sign Up
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
    </div>
  );
}
