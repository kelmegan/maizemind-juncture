"""Tabs components"""


def:pub Tabs(props: any) -> JsxElement {
    value = props.value if props.value else "";
    children = props.children if props.children else None;
    className = props.className if props.className else "";

    return (
        <div data-slot="tabs" className={"flex flex-col gap-2 " + className}>
            {children}
        </div>
    );
}


def:pub TabsList(props: any) -> JsxElement {
    children = props.children if props.children else None;
    className = props.className if props.className else "";

    return (
        <div data-slot="tabs-list" className={"bg-muted text-muted-foreground inline-flex h-9 w-fit items-center justify-center rounded-xl p-[3px] flex " + className}>
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
    base_class = "inline-flex h-[calc(100%-1px)] flex-1 items-center justify-center gap-1.5 rounded-xl border border-transparent px-2 py-1 text-sm font-medium whitespace-nowrap transition-[color,box-shadow] disabled:pointer-events-none disabled:opacity-50 ";
    active_class = "bg-card text-foreground " if is_active else "text-muted-foreground ";

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
            className={base_class + active_class + className}
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
        <div data-slot="tabs-content" className={"flex-1 outline-none " + className}>
            {children}
        </div>
    );
}