"""Juncture - Client-Side UI."""

import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }
# import json;
import "./styles.css";

import from .components.AuthForm { AuthForm }

def:pub app -> JsxElement {
    has isLoggedIn: bool = False,
        checkingAuth: bool = True,
        isSignup: bool = False,
        name: str = "",
        email: str = "",
        password: str = "",
        error: str = "",
        loading: bool = False,
        cards: dict = {},
        cardsLoading: bool = True;

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    can with [isLoggedIn] entry {
        if isLoggedIn {
            fetchProfileAndCards();
        }
    }

    def fetchProfileAndCards -> None {
        print("fetched");
        # Outline of what to do for this where ListTodos is a walker implementation
        cardsLoading = True;
        # result = root spawn ListTodos();
        # cards = result.reports[0] if result.reports else [];
        mock = "{\r\n    \"user\": {\r\n        \"id\": \"user_1234\",\r\n        \"type\": \"student | researcher | business | other\",\r\n        \"goals\": [\r\n            \"persuasive essay\",\r\n            \"research paper\"\r\n        ],\r\n        \"accessibility_mode\": false\r\n    },\r\n    \"graph\": {\r\n        \"nodes\": [\r\n            {\r\n                \"id\": \"node_1\",\r\n                \"type\": \"claim | evidence | counterargument\",\r\n                \"text\": \"Low carbon dioxide levels are needed for an ice age\",\r\n                \"parent_id\": null,\r\n                \"confidence\": 0.6,\r\n                \"support_score\": 0.5,\r\n                \"premise_coverage\": 0.4,\r\n                \"consistency_flag\": true,\r\n                \"status\": \"weak | strong | unsupported | contradictory\"\r\n            }\r\n        ],\r\n        \"edges\": [\r\n            {\r\n                \"from\": \"node_2\",\r\n                \"to\": \"node_1\",\r\n                \"type\": \"supports | contradicts | depends_on\",\r\n                \"weight\": 0.7\r\n            }\r\n        ]\r\n    },\r\n    \"graph_summary\": \"Really focuses on ice and not life during that time. Struggles with counterarguments.\"\r\n}";
        # cards = json.loads(mock);
        cardsLoading = False;
    }

    def toggleLogin(isSign: bool) -> None {
        isSignup = isSign;
        error = "";
    }

    async def handleLogin() -> None {
        error = "";
        if not email.trim() or not password {
            error = "Please fill in all fields";
            return;
        }
        loading = True;
        success = await jacLogin(email, password);
        loading = False;
        if success {
            isLoggedIn = True;
            email = "";
            password = "";
        } else {
            error = "Invalid email or password";
        }
    }

    async def handleSignup() -> None {
        error = "";
        if not email.trim() or not password {
            error = "Please fill in all fields";
            return;
        }
        if password.length < 4 {
            error = "Password must be at least 4 characters";
            return;
        }
        loading = True;
        result = await jacSignup(email, password);
        loading = False;
        if result["success"] {
            isLoggedIn = True;
            email = "";
            password = "";
        } else {
            error = result["error"] if result["error"] else "Signup failed";
        }
    }

    def handleLogout() -> None {
        jacLogout();
        isLoggedIn = False;
    }

    async def handleSubmit(e: any) -> None {
        e.preventDefault();
        if isSignup {
            await handleSignup();
        } else {
            await handleLogin();
        }
    }

    if checkingAuth {
        return (
            <div className="loading-content">
                Loading...
            </div>
        );
    }

    return
        <div className="auth-form-container">
            <AuthForm
                isSignup={isSignup}
                name={name}
                email={email}
                password={password}
                error={error}
                loading={loading}
                onNameChange={lambda e: any  -> None { name = e.target.value;}}
                onEmailChange={lambda e: any  -> None { email = e.target.value;}}
                onPasswordChange={lambda e: any  -> None { password = e.target.value;}}
                onSubmit={handleSubmit}
                onToggleMode={toggleLogin}
            />
        </div>;
}
