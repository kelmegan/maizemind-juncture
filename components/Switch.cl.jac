"""Switch component"""

def:pub Switch(props: any) -> JsxElement {
    checked = props.checked if props.checked else False;
    onCheckedChange = props.onCheckedChange if props.onCheckedChange else None;
    disabled = props.disabled if props.disabled else False;
    className = props.className if props.className else "";

    track_class = "switch-track ";
    track_class += "switch-track-checked " if checked else "switch-track-unchecked ";
    track_class += className;

    thumb_class = "switch-thumb ";
    thumb_class += "switch-thumb-checked " if checked else "switch-thumb-unchecked ";

    def handleClick() -> None {
        if onCheckedChange and not disabled {
            onCheckedChange(False if checked else True);
        }
    }

    return (
        <button
            data-slot="switch"
            role="switch"
            aria-checked={checked}
            disabled={disabled}
            onClick={handleClick}
            className={track_class}
        >
            <span data-slot="switch-thumb" className={thumb_class} />
        </button>
    );
}