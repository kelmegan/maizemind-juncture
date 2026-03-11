"""Card UI component"""

def:pub Card(props: any) -> JsxElement {
    title = props.title if props.title else None;
    description = props.description if props.description else None;
    footer = props.footer if props.footer else None;
    children = props.children if props.children else None;
    className = props.className if props.className else "";

    return (
        <div data-slot="card" className={"card " + className}>
            {(
                <div className="card-header">
                    {(<h4 className="card-title">{title}</h4>) if title else None}
                    {(<p className="card-description">{description}</p>) if description else None}
                </div>
            ) if title or description else None}
            {(<div className="card-content">{children}</div>) if children else None}
            {(<div className="card-footer">{footer}</div>) if footer else None}
        </div>
    );
}
