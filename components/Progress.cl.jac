"""Progress component"""

def:pub Progress(props: any) -> JsxElement {
    value = props.value if props.value else 0;
    className = props.className if props.className else "";

    return (
        <div
            data-slot="progress"
            className={"progress-track " + className}
        >
            <div
                data-slot="progress-indicator"
                className="progress-indicator"
                style={{"transform": f"translateX(-{100 - value}%)"}}
            />
        </div>
    );
}