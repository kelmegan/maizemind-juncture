"""Juncture - Shared app header component."""

import from "lucide-react" { ArrowLeft, User, LogOut, Download }

import from ..components.Button { Button }

def:pub Header(props: any) -> JsxElement {
    navigate = props.navigate;
    screen = props.screen if props.screen else "generate";
    title = props.title if props.title else None;
    backTo = props.backTo if props.backTo else None;

    def handleLogoClick() -> None {
        navigate("generate");
    }

    def handleBack() -> None {
        navigate(backTo);
    }

    def handleProfile() -> None {
        navigate("profile", {"from": screen});
    }

    def handleLogout() -> None {
        navigate("welcome");
    }

    def handleExport() -> None {
        navigate("export");
    }

    show_back = backTo != None;
    show_profile = screen != "profile";
    show_logout = screen == "profile";
    show_export = screen == "review";

    return (
        <header className="app-header">
            <div className="app-header-inner">
                <div className="app-header-left">
                    {(
                        <Button
                            label={(<ArrowLeft className="app-header-back-icon" />)}
                            variant="ghost"
                            onClick={handleBack}
                            className="app-header-back-btn"
                        />
                    ) if show_back else None}
                    <span className="app-header-logo" onClick={handleLogoClick}>Juncture</span>
                    {(
                        <>
                            <span className="app-header-dot">·</span>
                            <span className="app-header-title">{title}</span>
                        </>
                    ) if title else None}
                </div>
                <div className="app-header-right">
                    {(
                        <Button
                            label={(<><Download className="app-header-btn-icon" />Export</>)}
                            variant="ghost"
                            onClick={handleExport}
                        />
                    ) if show_export else None}
                    {(
                        <Button
                            label={(<><User className="app-header-btn-icon" />Profile</>)}
                            variant="ghost"
                            onClick={handleProfile}
                        />
                    ) if show_profile else None}
                    {(
                        <Button
                            label={(<><LogOut className="app-header-btn-icon" />Log Out</>)}
                            variant="ghost"
                            onClick={handleLogout}
                        />
                    ) if show_logout else None}
                </div>
            </div>
        </header>
    );
}
