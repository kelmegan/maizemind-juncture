"""Card UI component"""

def:pub Card(props: any) -> JsxElement {
    title = props.title if props.title else None;
    description = props.description if props.description else None;
    footer = props.footer if props.footer else None;
    children = props.children if props.children else None;
    className = props.className if props.className else "";

    base_class = "bg-card text-card-foreground flex flex-col gap-6 rounded-xl border ";
    return (
        <div data-slot="card" className={base_class + className}>
            {(
                <div className="grid auto-rows-min items-start gap-1.5 px-6 pt-6">
                    {(<h4 className="leading-none">{title}</h4>) if title else None}
                    {(<p className="text-muted-foreground">{description}</p>) if description else None}
                </div>
            ) if title or description else None}
            {(<div className="px-6 pb-6">{children}</div>) if children else None}
            {(<div className="flex items-center px-6 pb-6">{footer}</div>) if footer else None}
        </div>
    );
}