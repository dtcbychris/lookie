import React, { useEffect, useState } from "react";
import ReactDOM from "react-dom/client";
import { App } from "./App";
import { CanvasPage } from "./canvas/CanvasPage";
import "./index.css";

function getRoute(): string {
  return window.location.hash.replace(/^#\/?/, "") || "";
}

function Root() {
  const [route, setRoute] = useState<string>(() => getRoute());

  useEffect(() => {
    const onHash = () => setRoute(getRoute());
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);

  // Body theming: CanvasOS uses a light background; Builder Copilot is dark.
  useEffect(() => {
    const body = document.body;
    if (route === "canvas") {
      body.classList.remove("bg-ink-950", "text-ink-100");
      body.classList.add("bg-[#fafaf7]", "text-ink-900");
    } else {
      body.classList.remove("bg-[#fafaf7]", "text-ink-900");
      body.classList.add("bg-ink-950", "text-ink-100");
    }
  }, [route]);

  if (route === "canvas") return <CanvasPage />;
  return <App />;
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <Root />
  </React.StrictMode>,
);
