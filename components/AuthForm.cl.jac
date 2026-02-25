"""Authentication form component."""

import from .Button { Button }

def:pub AuthForm(props: any) -> JsxElement {
    isSignup = props.isSignup;
    name = props.name;
    email = props.email;
    password = props.password;
    error = props.error;
    loading = props.loading;
    onNameChange = props.onNameChange;
    onEmailChange = props.onEmailChange;
    onPasswordChange = props.onPasswordChange;
    onSubmit = props.onSubmit;
    onToggleMode = props.onToggleMode;
    return (
        <div className="entry-page">
            <div className="branding-section">
                <h1>
                    Juncture
                </h1>
                <p className="tagline">
                    Your paper & presentation copilot
                </p>
                <div className="feature-list">
                    <div className="feature-item">
                        <div className="feature-icon">
                            🧠
                        </div>
                        <div className="feature-content">
                            <h3>
                                Paste your messy notes
                            </h3>
                            <p>
                                Transform scattered thoughts into structured arguments
                            </p>
                        </div>
                    </div>
                    <div className="feature-item">
                        <div className="feature-icon">
                            💡
                        </div>
                        <div className="feature-content">
                            <h3>
                                Get instant critique
                            </h3>
                            <p>
                                See exactly what to fix with AI-powered analysis
                            </p>
                        </div>
                    </div>
                    <div className="feature-item">
                        <div className="feature-icon">
                            📈
                        </div>
                        <div className="feature-content">
                            <h3>
                                Watch your score improve
                            </h3>
                            <p>
                                Track reasoning quality and export polished outlines
                            </p>
                        </div>
                    </div>
                </div>
            </div>
            <div className="auth-container">
                <div className="auth-card">
                    <div className="auth-header">
                        <h4>
                            Get Started
                        </h4>
                        <p>
                            Sign in to save your work or continue as guest
                        </p>
                    </div>
                    <div className="auth-content">
                        {(
                            <div className="auth-error">
                                {error}
                            </div>
                        )
                        if error
                        else None}
                        <div className="toggle-buttons">
                            <Button
                                label="Login"
                                onClick={lambda -> None { onToggleMode(False);}}
                                variant={"secondary" if isSignup else "primary"}
                                toggle={True}
                            />
                            <Button
                                label="Sign Up"
                                onClick={lambda -> None { onToggleMode(True);}}
                                variant={"primary" if isSignup else "secondary"}
                                toggle={True}
                            />
                        </div>
                        <form onSubmit={onSubmit}>
                            {(
                                <div className="form-field">
                                    <label className="form-label">
                                        Name
                                    </label>
                                    <input
                                        type="text"
                                        value={name}
                                        onChange={onNameChange}
                                        placeholder="Enter name"
                                        className="auth-input"
                                    />
                                </div>
                            )
                            if isSignup
                            else None}
                            <div className="form-field">
                                <label className="form-label">
                                    Email
                                </label>
                                <input
                                    type="text"
                                    value={email}
                                    onChange={onEmailChange}
                                    placeholder="Enter email"
                                    className="auth-input"
                                />
                            </div>
                            <div className="form-field">
                                <label className="form-label">
                                    Password
                                </label>
                                <input
                                    type="password"
                                    value={password}
                                    onChange={onPasswordChange}
                                    placeholder="Enter password"
                                    className="auth-input"
                                />
                            </div>
                            <button
                                type="submit"
                                className="submit-button"
                                disabled={loading}
                            >
                                {(
                                    "Processing..."
                                    if loading
                                    else ("Create Account" if isSignup else "Login")
                                )}
                            </button>
                        </form>
                        <div className="divider">
                            OR
                        </div>
                        <div className="auth-toggle">
                            <Button
                                label="Continue as Guest"
                                onClick={lambda -> None { print(
                                    "this dont work right now"
                                );}}
                                variant={"primary"}
                            />
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}
