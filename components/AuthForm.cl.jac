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
                    <Button
                        label="Login"
                        onClick={lambda -> None { onToggleMode(False); }}
                        variant={"secondary" if isSignup else "primary"}
                        toggle={True}
                    />
                    <Button
                        label="Sign Up"
                        onClick={lambda -> None { onToggleMode(True); }}
                        variant={"primary" if isSignup else "secondary"}
                        toggle={True}
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
                <div>OR</div>
                <hr/>
                <div className="auth-toggle">
                    <Button
                        label="Continue as Guest"
                        onClick={lambda -> None { print("this dont work right now"); }}
                        variant={"primary"}
                    />
                </div>
            </div>
        </div>
    );
}