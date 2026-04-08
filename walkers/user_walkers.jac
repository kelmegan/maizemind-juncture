"""User walkers"""

import time;
import from graph.user_nodes { User }

walker:pub CreateUser {
    has name: str,
        email: str,
        userType: str = "student",
        isGuest: bool = False;

    can run with Root entry {
        for user in [-->](?:User) {
            if user.email == self.email {
                report {"error": "account_exists", "id": user.id};
                return;
            }
        }

        new_user = (root ++> User(
            id=f"user_{int(time.time())}",
            name=self.name,
            email=self.email,
            userType=self.userType,
            createdAt=str(int(time.time())),
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
            if user.id == self.userId or user.email == self.userId {
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
            if user.id == self.userId or user.email == self.userId {
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


walker:pub GetCurrentUser {
    has userId: str = "",
        email: str = "";

    can run with Root entry {
        try {
            user = None;

            if self.userId {
                for u in [-->](?:User) {
                    if u.id == self.userId or u.email == self.userId {
                        user = u;
                        break;
                    }
                }
            }
            if not user and self.email {
                for u in [-->](?:User) {
                    if u.email == self.email {
                        user = u;
                        break;
                    }
                }
            }
            if not user and not self.userId and not self.email {
                non_guest_users = [];
                for u in [-->](?:User) {
                    if not u.isGuest {
                        non_guest_users.append(u);
                    }
                }

                if len(non_guest_users) == 1 {
                    user = non_guest_users[0];
                } elif len(non_guest_users) > 1 {
                    print("GetCurrentUser warning: multiple non-guest users found without an explicit identifier");
                }
            }

            if not user {
                report {"authenticated": False, "isGuest": True};
                return;
            }

            report {
                "authenticated": True,
                "isGuest": False,
                "id": user.id,
                "name": user.name,
                "email": user.email,
                "userType": user.userType if user.userType else "student",
                "goals": user.goals if user.goals else [],
                "theme": user.theme if user.theme else "light",
                "accessibilityMode": user.accessibilityMode if user.accessibilityMode else False
            };
        } except Exception as e {
            print(f"GetCurrentUser error: {e}");
            report {"authenticated": False, "isGuest": True};
        }
    }
}
