"""Tabs components"""


def:pub Tabs(props: any) -> JsxElement {
    value = props.value if props.value else "";
    children = props.children if props.children else None;
    className = props.className if props.className else "";

    return (
        <div data-slot="tabs" className={"tabs-container " + className}>
            {children}
        </div>
    );
}


def:pub TabsList(props: any) -> JsxElement {
    children = props.children if props.children else None;
    className = props.className if props.className else "";

    return (
        <div data-slot="tabs-list" className={"tabs-list " + className}>
            {children}
        </div>
    );
}


def:pub TabsTrigger(props: any) -> JsxElement {
    value = props.value if props.value else "";
    children = props.children if props.children else None;
    activeValue = props.activeValue if props.activeValue else "";
    onValueChange = props.onValueChange if props.onValueChange else None;
    className = props.className if props.className else "";

    is_active = value == activeValue;
    active_class = "tabs-trigger-active " if is_active else "tabs-trigger-inactive ";

    def handleClick() -> None {
        if onValueChange {
            onValueChange(value);
        }
    }

    return (
        <button
            data-slot="tabs-trigger"
            data-state={"active" if is_active else "inactive"}
            onClick={handleClick}
            className={"tabs-trigger " + active_class + className}
        >
            {children}
        </button>
    );
}


def:pub TabsContent(props: any) -> JsxElement {
    value = props.value if props.value else "";
    activeValue = props.activeValue if props.activeValue else "";
    children = props.children if props.children else None;
    className = props.className if props.className else "";

    if value != activeValue {
        return <></>;
    }
    return (
        <div data-slot="tabs-content" className={"tabs-content " + className}>
            {children}
        </div>
    );
}
