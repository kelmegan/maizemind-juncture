"""Implementations for the Todo App frontend component."""

impl app.handleLogin -> None {
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

impl app.handleSignup -> None {
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

impl app.handleLogout -> None {
    jacLogout();
    isLoggedIn = False;
}

impl app.handleSubmit(e: any) -> None {
    e.preventDefault();
    if isSignup {
        await handleSignup();
    } else {
        await handleLogin();
    }
}

impl app.toggleLogin -> None {
    isSignup = not isSignup;
}