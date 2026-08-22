import React from "react";
import { Link } from "react-router-dom";
import EmptyState from "../components/EmptyState";

export default function NotFoundPage() {
  return (
    <EmptyState
      title="Página não encontrada"
      description="O endereço que você abriu não existe por aqui."
      action={
        <Link to="/" className="rounded-lg bg-wax-500 px-4 py-2 text-sm font-semibold text-ink-950 hover:bg-wax-400">
          Ir para a coleção
        </Link>
      }
    />
  );
}
