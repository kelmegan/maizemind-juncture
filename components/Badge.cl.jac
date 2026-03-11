"""Badge component"""

def:pub Badge(props: any) -> JsxElement {
    children = props.children if props.children else None;
    variant = props.variant if props.variant else "default";
    className = props.className if props.className else "";

    variant_class = "badge-default";
    if variant == "secondary"    { variant_class = "badge-secondary"; }
    elif variant == "destructive" { variant_class = "badge-destructive"; }
    elif variant == "outline"     { variant_class = "badge-outline"; }

    return (
        <span className={"badge " + variant_class + " " + className}>
            {children}
        </span>
    );
}
