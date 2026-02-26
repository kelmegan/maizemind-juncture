import { RouterProvider } from "react-router";
import { router } from "./routes";
import { AppProvider } from "./store/AppContext";
import { Toaster } from "./components/ui/sonner";

export default function App() {
  return (
    <AppProvider>
      <RouterProvider router={router} />
      <Toaster />
    </AppProvider>
  );
}
