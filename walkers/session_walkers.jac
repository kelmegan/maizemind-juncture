"""Session walkers"""

import from graph.session_nodes { Session }
import from graph.argument_graph_nodes { ArgumentGraph }

walker:pub CreateSession {
    has userId: str,
        graphId: str,
        notes: str,
        score: dict;

    can run with `root entry {
        graph_node = None;
        for graph in [ArgumentGraph] {
            if graph.id == self.graphId {
                graph_node = graph;
                break;
            }
        }

        title = "Untitled Argument";
        if graph_node != None {
            for n in graph_node.nodes {
                if n["type"] == "THESIS" {
                    thesis_content = n["content"];
                    title = thesis_content[:50] + "..." if len(thesis_content) > 50 else thesis_content;
                    break;
                }
            }
        }

        new_session = (root ++> Session(
            id=f"session_{now()}",
            date=str(now()),
            userId=self.userId,
            title=title,
            initialScore=self.score["overall"],
            finalScore=self.score["overall"],
            notes=self.notes
        ))[0];

        if graph_node != None {
            new_session ++> graph_node;
        }

        report new_session;
    }
}


walker:pub GetUserSessions {
    has userId: str;

    can run with `root entry {
        sessions = [];

        for s in [Session] {
            if s.userId == self.userId {
                sessions.append(s);
            }
        }

        report sessions;
    }
}


walker:pub CalculateUserStats {
    has userId: str;

    can run with `root entry {
        sessions = [];

        for s in [Session] {
            if s.userId == self.userId {
                sessions.append(s);
            }
        }

        total_sessions = len(sessions);

        if total_sessions == 0 {
            report {
                "totalSessions": 0,
                "averageScore": 0,
                "averageImprovement": 0
            };
            return;
        }

        total_score = 0;
        total_improvement = 0;
        for s in sessions {
            total_score += s.finalScore;
            total_improvement += s.finalScore - s.initialScore;
        }

        report {
            "totalSessions": total_sessions,
            "averageScore": int(total_score / total_sessions),
            "averageImprovement": int(total_improvement / total_sessions)
        };
    }
}