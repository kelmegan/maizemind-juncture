"""Main entry point for maizemind-juncture."""

# Client-side imports (useState is auto-injected when using `has` variables)
cl import from frontend { app as ClientApp }

# Client-side component
cl {
    def:pub app -> JsxElement {
        return
            <ClientApp />;
    }
}
