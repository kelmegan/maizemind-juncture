"""Button component for the Jac client application."""

def:pub Button(
    label: str,
    onClick: any,
    variant: str = "primary",
    disabled: bool = False,
    toggle: bool = False
) -> JsxElement {
    className = "button button-" + variant;
    if (toggle) {
        className += " button-toggle";
    }
    return
        <button className={className} onClick={onClick} disabled={disabled}>
            {label}
        </button>;
}
