"""Session graph schema"""

node Session {
    has id: str,
        date: str,
        title: str,
        initialScore: int,
        finalScore: int,
        notes: str = "";
}