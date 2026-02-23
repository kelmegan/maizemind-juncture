"""Main entry point for maizemind-juncture."""

# Client-side imports (useState is auto-injected when using `has` variables)
cl import from react { useEffect }

# Client-side component
cl {
    import from frontend { app as ClientApp }

    def:pub app -> any {
        return
            <ClientApp />;
    }
}
