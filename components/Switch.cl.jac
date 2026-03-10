"""Switch component"""

def:pub Switch(props: any) -> JsxElement {
    checked = props.checked if props.checked else False;
    onCheckedChange = props.onCheckedChange if props.onCheckedChange else None;
    disabled = props.disabled if props.disabled else False;
    className = props.className if props.className else "";

    track_class = "relative inline-flex h-[1.15rem] w-8 shrink-0 items-center rounded-full border border-transparent transition-all outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:border-ring disabled:cursor-not-allowed disabled:opacity-50 ";
    track_class += "bg-primary " if checked else "bg-switch-background ";
    track_class += className;

    thumb_class = "pointer-events-none block size-4 rounded-full bg-card ring-0 transition-transform ";
    thumb_class += "translate-x-[calc(100%-2px)] " if checked else "translate-x-0 ";

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