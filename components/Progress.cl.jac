"""Progress component"""

def:pub Progress(props: any) -> JsxElement {
    value = props.value if props.value else 0;
    className = props.className if props.className else "";

    return (
        <div
            data-slot="progress"
            className={"bg-primary/20 relative h-2 w-full overflow-hidden rounded-full " + className}
        >
            <div
                data-slot="progress-indicator"
                className="bg-primary h-full w-full flex-1 transition-all"
                style={{"transform": f"translateX(-{100 - value}%)"}}
            />
        </div>
    );
}