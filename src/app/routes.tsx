import { createBrowserRouter } from "react-router";
import { WelcomeScreen } from "./screens/WelcomeScreen";
import { GenerateScreen } from "./screens/GenerateScreen";
import { ReviewScreen } from "./screens/ReviewScreen";
import { ReviseScreen } from "./screens/ReviseScreen";
import { ExportScreen } from "./screens/ExportScreen";
import { ProfileScreen } from "./screens/ProfileScreen";

export const router = createBrowserRouter([
  {
    path: "/",
    Component: WelcomeScreen,
  },
  {
    path: "/generate",
    Component: GenerateScreen,
  },
  {
    path: "/review",
    Component: ReviewScreen,
  },
  {
    path: "/revise/:nodeId",
    Component: ReviseScreen,
  },
  {
    path: "/export",
    Component: ExportScreen,
  },
  {
    path: "/profile",
    Component: ProfileScreen,
  },
]);
