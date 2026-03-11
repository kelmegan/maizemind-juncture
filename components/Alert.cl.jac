"""Alert component"""

def:pub Alert(props: any) -> JsxElement {
    title = props.title if props.title else None;
    description = props.description if props.description else None;
    children = props.children if props.children else None;
    variant = props.variant if props.variant else "default";
    className = props.className if props.className else "";

    variant_class = "alert-destructive " if variant == "destructive" else "alert-default ";

    return (
        <div data-slot="alert" role="alert" className={"alert-container " + variant_class + className}>
            {(<div className="alert-title">{title}</div>) if title else None}
            {(<div className="alert-description">{description}</div>) if description else None}
            {children}
        </div>
    );
}
