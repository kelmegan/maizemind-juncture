"""Alert component"""

def:pub Alert(props: any) -> JsxElement {
    title = props.title if props.title else None;
    description = props.description if props.description else None;
    children = props.children if props.children else None;
    variant = props.variant if props.variant else "default";
    className = props.className if props.className else "";

    base_class = "relative w-full rounded-lg border px-4 py-3 text-sm grid has-[>svg]:grid-cols-[calc(var(--spacing)*4)_1fr] grid-cols-[0_1fr] has-[>svg]:gap-x-3 gap-y-0.5 items-start [&>svg]:size-4 [&>svg]:translate-y-0.5 [&>svg]:text-current ";
    variant_class = "text-destructive bg-card [&>svg]:text-current " if variant == "destructive" else "bg-card text-card-foreground ";

    return (
        <div data-slot="alert" role="alert" className={base_class + variant_class + className}>
            {(<div className="col-start-2 font-medium tracking-tight">{title}</div>) if title else None}
            {(<div className="text-muted-foreground col-start-2 grid justify-items-start gap-1 text-sm [&_p]:leading-relaxed">{description}</div>) if description else None}
            {children}
        </div>
    );
}