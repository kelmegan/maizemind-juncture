"""Authentication form component."""

cl import from .Button { Button }

def:pub AuthForm(
    isSignup: bool,
    name: str,
    email: str,
    password: str,
    error: str,
    loading: bool,
    onNameChange: any,
    onEmailChange: any,
    onPasswordChange: any,
    onSubmit: any,
    onToggleMode: any,
) -> any {
    return (
        <div className="auth-container">
            <div className="auth-card">
                <div className="auth-header">
                    <h1 className="auth-title">Get Started</h1>
                    <p className="auth-subtitle">
                        Sign in to save your work or continue as guest
                    </p>
                </div>
                {(
                    <div className="auth-error">{error}</div>
                ) if error else None}
                <div className="button-toggle">
                    # need to add toggle variant styling to button component
                    <Button
                        label="Login"
                        onClick={onToggleMode}
                        variant={"secondary" if isSignup else "primary"}
                    />
                    <Button
                        label="Sign Up"
                        onClick={onToggleMode}
                        variant={"primary" if isSignup else "secondary"}
                    />
                </div>
                <form onSubmit={onSubmit}>
                    {(
                        <div className="form-field">
                            <label className="form-label">Name</label>
                            <input
                                type="text"
                                value={name}
                                onChange={onNameChange}
                                placeholder="Enter name"
                                className="auth-input"
                            />
                        </div>
                    ) if isSignup else None}
                    <div className="form-field">
                        <label className="form-label">Email</label>
                        <input
                            type="text"
                            value={email}
                            onChange={onEmailChange}
                            placeholder="Enter email"
                            className="auth-input"
                        />
                    </div>
                    <div className="form-field-last">
                        <label className="form-label">Password</label>
                        <input
                            type="password"
                            value={password}
                            onChange={onPasswordChange}
                            placeholder="Enter password"
                            className="auth-input"
                        />
                    </div>
                    <button type="submit" disabled={loading} className="auth-submit">
                        {(
                            "Processing..."
                            if loading
                            else ("Create Account" if isSignup else "Login")
                        )}
                    </button>
                </form>
                <hr/>
                <div>"OR"</div>
                <hr/>
                <div className="auth-toggle">
                    <Button
                        label="Continue as Guest"
                        onClick={lambda -> None { isSignup = true; }}
                        variant="toggle"
                    />
                </div>
            </div>
        </div>
    );
}