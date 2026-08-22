import React from "react";
import { Route, Routes } from "react-router-dom";
import { AppProvider } from "./AppContext";
import Layout from "./components/Layout";
import ItemsPage from "./pages/ItemsPage";
import ReleasePage from "./pages/ReleasePage";
import StatsPage from "./pages/StatsPage";
import NotFoundPage from "./pages/NotFoundPage";

export default function App() {
  return (
    <AppProvider>
      <Routes>
        <Route element={<Layout />}>
          <Route
            index
            element={
              <ItemsPage
                key="collection"
                list="collection"
                title="Minha coleção"
                subtitle="Tudo que já está na prateleira."
              />
            }
          />
          <Route
            path="wantlist"
            element={
              <ItemsPage
                key="wantlist"
                list="wantlist"
                title="Lista de desejos"
                subtitle="Os discos que ainda faltam."
              />
            }
          />
          <Route path="release/:id" element={<ReleasePage />} />
          <Route path="stats" element={<StatsPage />} />
          <Route path="*" element={<NotFoundPage />} />
        </Route>
      </Routes>
    </AppProvider>
  );
}
