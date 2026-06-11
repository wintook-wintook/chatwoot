# Bóveda de conocimiento — Base de Conocimiento (KB)

Notas atómicas (Markdown + wikilinks `[[ ]]`) del módulo **Base de Conocimiento**:
sync de Discourse, embeddings con pgvector, búsqueda semántica y respuestas
automáticas del bot. Empieza por **[[00-Indice]]**.

```
vault-kbase/
├── 00-Indice.md            ← mapa de contenido (MOC), empieza aquí
├── diseno/                 ← arquitectura y flujos
└── implementacion/         ← estado real, archivos, pendientes
```

> ⚠️ Esta bóveda está **en construcción** (solo estructura + índice). El detalle se
> irá llenando. El conocimiento canónico hoy vive en las memorias del proyecto y en
> el código de la rama `feat/kbase_contact_tracking`.

## Ver el grafo de relaciones

- **En el navegador (code-server / Foam):** `Ctrl+Shift+P` → **Foam: Show Graph**.
- **En tu laptop (Obsidian):** abre `docs/vault-kbase` como vault en Obsidian →
  panel de **Graph view**.

En el servidor, esta bóveda y la de Tickets se ven **juntas** vía un workspace
multi-raíz (`docs/vaults.code-workspace`, fuera de git por ser config local del
servidor). Es lo que sirve `vaults.wintook.com`.
