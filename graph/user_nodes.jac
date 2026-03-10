"""User graph schema"""

node User {
    has id: str,
        name: str,
        email: str,
        createdAt: str,
        userType: str = "student",
        goals: list[str] = [],
        strengths: list[str] = [],
        weaknesses: list[str] = [],
        theme: str = "system",
        accessibilityMode: bool = False,
        isGuest: bool = False;
}