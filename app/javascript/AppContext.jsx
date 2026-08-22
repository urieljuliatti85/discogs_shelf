import React, { createContext, useCallback, useContext, useState } from "react";
import { useProfile } from "./hooks/useProfile";
import { useSync } from "./hooks/useSync";

const AppContext = createContext(null);

export function AppProvider({ children }) {
  // Bumped whenever a sync finishes so every mounted list refetches itself.
  const [dataVersion, setDataVersion] = useState(0);
  const { profile, loading, error, reload: reloadProfile } = useProfile();

  const onSyncFinished = useCallback(() => {
    setDataVersion((version) => version + 1);
    reloadProfile();
  }, [reloadProfile]);

  const sync = useSync(onSyncFinished);

  return (
    <AppContext.Provider value={{ profile, loading, error, reloadProfile, sync, dataVersion }}>
      {children}
    </AppContext.Provider>
  );
}

export function useApp() {
  const context = useContext(AppContext);
  if (!context) throw new Error("useApp precisa estar dentro de <AppProvider>");
  return context;
}
