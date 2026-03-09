# """Main entry point for maizemind-juncture."""

# # Client-side imports (useState is auto-injected when using `has` variables)
# cl import from frontend { app as ClientApp }

# # Client-side component
# cl {
#     def:pub app -> JsxElement {
#         return
#             <ClientApp />;
#     }
# }
"""Main entry point for Juncture."""

# Import all screens
cl import from .WelcomeScreen { WelcomeScreen }
cl import from .GenerateScreen { GenerateScreen }
cl import from .ReviewScreen { ReviewScreen }
cl import from .ReviseScreen { ReviseScreen }
cl import from .ExportScreen { ExportScreen }
cl import from .ProfileScreen { ProfileScreen }

cl {
    def:pub app -> JsxElement {
        has currentScreen: str = "welcome",
            isLoggedIn: bool = False;

        # Check auth status
        can with entry {
            isLoggedIn = jacIsLoggedIn();
            if isLoggedIn {
                currentScreen = "generate";
            }
        }

        # Screen router
        if currentScreen == "welcome" {
            return
                <WelcomeScreen/>;
        } elif currentScreen == "generate" {
            return
                <GenerateScreen/>;
        } elif currentScreen == "review" {
            return
                <ReviewScreen/>;
        } elif currentScreen == "revise" {
            return
                <ReviseScreen/>;
        } elif currentScreen == "export" {
            return
                <ExportScreen/>;
        } elif currentScreen == "profile" {
            return
                <ProfileScreen/>;
        }

        return
            <WelcomeScreen/>;
    }
}
