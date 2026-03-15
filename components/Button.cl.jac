"""Button component for the Jac client application."""

def:pub Button(
    label: str,
    onClick: any,
    variant: str = "primary",
    disabled: bool = False,
    toggle: bool = False,
    className: str = ""
) -> JsxElement {
    resolvedVariant = variant if variant else "primary";
    resolvedClassName = "button button-" + resolvedVariant;
    if (toggle) {
        resolvedClassName += " button-toggle";
    }
    if (className) {
        resolvedClassName += " " + className;
    }
    return
        <button className={resolvedClassName} onClick={onClick} disabled={disabled}>
            {label}
        </button>;
}
