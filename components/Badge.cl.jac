"""Badge component"""

def:pub Badge(props: any) -> JsxElement {
    children = props.children if props.children else None;
    variant = props.variant if props.variant else "default";
    className = props.className if props.className else "";

    base_class = "inline-flex items-center rounded-md border px-2.5 py-0.5 text-xs font-semibold transition-colors ";

    variant_class = "default";
    if variant == "default" { variant_class = "border-transparent bg-primary text-primary-foreground "; }
    elif variant == "secondary" { variant_class = "border-transparent bg-secondary text-secondary-foreground "; }
    elif variant == "destructive" { variant_class = "border-transparent bg-destructive text-destructive-foreground "; }
    elif variant == "outline" { variant_class = "text-foreground "; }

    return (
        <span className={base_class + variant_class + className}>
            {children}
        </span>
    );
}