"""User walkers"""

import from graph.user_nodes { User }

walker:pub CreateUser {
    has name: str,
        email: str,
        userType: str = "student",
        isGuest: bool = False;

    can run with Root entry {
        new_user = (root ++> User(
            id=f"user_{now()}",
            name=self.name,
            email=self.email,
            userType=self.userType,
            createdAt=str(now()),
            isGuest=self.isGuest
        ))[0];

        report new_user;
    }
}


walker:pub GetUserProfile {
    has userId: str;

    can run with Root entry {
        user_node = None;

        for user in [-->](?:User) {
            if user.id == self.userId {
                user_node = user;
                break;
            }
        }

        report user_node;
    }
}


walker:pub GetUserByEmail {
    has email: str;

    can run with Root entry {
        user_node = None;

        for user in [-->](?:User) {
            if user.email == self.email {
                user_node = user;
                break;
            }
        }

        report user_node;
    }
}


walker:pub UpdateUserProfile {
    has userId: str,
        name: str = None,
        userType: str = None,
        goals: list[str] = None,
        theme: str = None,
        accessibilityMode: bool = None;

    can run with Root entry {
        user_node = None;

        for user in [-->](?:User) {
            if user.id == self.userId {
                user_node = user;
                break;
            }
        }

        if not user_node {
            report {"error": "User not found"};
            return;
        }

        if self.name is not None { user_node.name = self.name; }
        if self.userType is not None { user_node.userType = self.userType; }
        if self.goals is not None { user_node.goals = self.goals; }
        if self.theme is not None { user_node.theme = self.theme; }
        if self.accessibilityMode is not None { user_node.accessibilityMode = self.accessibilityMode; }

        report {"success": True, "user": user_node};
    }
}
