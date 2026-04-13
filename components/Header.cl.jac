"""MaizeMind - Shared app header component."""

import from "@jac/runtime" { jacLogout, useNavigate, useLocation }
import from react { useContext }
import from "lucide-react" { ArrowLeft, User, LogOut, Download, ScrollText }
import from ..screens.AppContext { getAppContext }
import from ..components.Button { Button }
import from ..components.Modal { Modal }
import from ..components.EulaContent { getEulaContent }

def:pub Header(props: any) -> JsxElement {
    nav = useNavigate();
    location = useLocation();
    _AppCtx = getAppContext();
    ctx = useContext(_AppCtx);

    screen = props.screen if props.screen else "generate";
    title = props.title if props.title else None;
    backTo = props.backTo if props.backTo else None;
    onBack = props.onBack if props.onBack else None;
    isGuest = props.isGuest if props.isGuest else None;
    onLogout = props.onLogout if props.onLogout else None;
    onExport = props.onExport if props.onExport else None;

    has showEulaModal: bool = False;

    def openEula() -> None {
        showEulaModal = True;
    }

    def closeEula() -> None {
        showEulaModal = False;
    }

    def handleLogoClick() -> None {
        nav("/generate");
    }

    def handleBack() -> None {
        if onBack { onBack(); } else { nav(backTo); }
    }

    def handleProfile() -> None {
        nav("/profile", {"state": {"from": location.pathname}});
    }

    def handleLogout() -> None {
        if onLogout {
            onLogout();
        } else {
            try { jacLogout(); } except Exception as e { print(f"Logout error: {e}"); }
            ctx.logout();
            nav("/");
        }
    }

    def handleExport() -> None {
        if onExport {
            onExport();
        } else {
            nav("/export", {"state": {"graphId": ctx.cachedGraphId}});
        }
    }

    show_back    = backTo != None or onBack != None;
    show_profile = screen != "profile";
    show_logout  = screen == "profile" and isGuest != True;
    show_export  = screen == "review";

    return (
        <div>
            {(
                <Modal
                    title="End User License Agreement"
                    content={getEulaContent()}
                    primaryButton={{
                        "label": "Close",
                        "onClick": closeEula
                    }}
                    onClose={closeEula}
                    showClose={True}
                    closeable={True}
                />
            ) if showEulaModal else None}

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
                        <span className="app-header-logo" onClick={handleLogoClick}>MaizeMind</span>
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

                        <button
                            className="header-eula-btn"
                            onClick={openEula}
                            title="View End User License Agreement"
                            aria-label="View End User License Agreement"
                        >
                            <ScrollText className="header-eula-icon" />
                        </button>
                    </div>
                </div>
            </header>
        </div>
    );
}
