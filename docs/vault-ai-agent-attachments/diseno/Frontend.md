---
titulo: Frontend — tab "📎 Archivos" + autocompletado @adjunto:
tipo: diseno
tags: [ai-agent-attachments, frontend, autocomplete]
---

# Frontend — tab "📎 Archivos" + autocompletado

## Dónde

`app/javascript/dashboard/routes/dashboard/settings/trackingTemplates/EditTemplate.vue`
— el bloque `woot-tabs` "Contexto IA" (≈ línea 546). Tabs actuales:

| idx | Tab | Campo |
|----|-----|-------|
| 0 | 🧠 Contexto IA | `ai_context` |
| 1 | 💡 Entrenamiento | `complementary_prompt` ← directivas + autocompletado |
| 2 | 📱 Plantillas WhatsApp (solo WA) | `whatsapp_templates` |
| 3 | 📋 Reglas | `keyword_actions` |
| 4 | 📅 Agendas | `calendar_integration_ids` |
| **5** | **📎 Archivos (NUEVO)** | **adjuntos del Agente IA** |

> ⚠️ Los índices de tab son **dinámicos**: el tab "📱 Plantillas WhatsApp" solo aparece
> si `selectedInboxIsWhatsApp`. El componente ya recalcula índices
> (`attemptTabs`, `reglasTabIndex`, `agendasTabIndex`). El nuevo tab Archivos debe
> calcular su índice como `agendasTabIndex + 1` y respetar ese desplazamiento.

## Tab "📎 Archivos" — qué hace

1. **Subir** uno o varios archivos (input file / drag&drop) → POST a la API de adjuntos
   del Agente IA (ver [[API-y-rutas]]).
2. **Listar** los adjuntos existentes: `nombre`, filename, tamaño, tipo, fecha.
3. **Editar `nombre`** (la clave que usará `@adjunto:nombre`). Forzar slug
   (`[a-zA-Z0-9_-]`, sin espacios) para que la directiva quede inequívoca.
4. **Borrar** un adjunto.
5. **Pista de uso:** mostrar, junto a cada archivo, el snippet copiable
   `@adjunto:nombre` para pegar en el tab "Entrenamiento".

## ⭐ Autocompletado `@adjunto:` en el prompt complementario

Al escribir **`@adjunto:`** en el textarea del tab "Entrenamiento", desplegar un dropdown
con los archivos de ESE agente y, al elegir, insertar `@adjunto:nombre`.

### Reutilizar lo que ya existe en Chatwoot

- **`app/javascript/dashboard/components/widgets/mentions/MentionBox.vue`** — dropdown
  navegable que ya usan menciones (`@`) y respuestas predefinidas (`/`). Recibe `items`,
  navega con ↑/↓/Enter y emite `mentionSelect`.
- **`useKeyboardNavigableList`** (composable) — navegación de teclado del listado.

### Lógica a añadir (el textarea hoy es plano, `v-model="form.complementary_prompt"`)

```
1. En @input / @keyup, leer el texto ANTES del cursor (selectionStart).
2. Detectar el patrón abierto:  /@adjunto:([a-zA-Z0-9_-]*)$/
   - si NO matchea → ocultar dropdown.
   - si matchea → query = grupo capturado (lo escrito tras los dos puntos).
3. Filtrar la lista de adjuntos del agente por `name` que incluya `query`.
4. Mostrar <MentionBox :items="filtrados"> posicionado bajo el cursor.
5. @mentionSelect(item):
   - reemplazar el fragmento "@adjunto:<query>" por "@adjunto:<item.name> ".
   - reposicionar el cursor tras el token, ocultar dropdown.
```

> Posicionamiento del popover sobre un `<textarea>` plano: calcular coordenadas del
> cursor (mirror div o util existente). Alternativa más simple si complica: botón
> "Insertar archivo" que abre el mismo `MentionBox` y pega el token en el cursor.

## i18n

Claves bajo `TRACKING_TEMPLATES.FORM.ATTACHMENTS.*` en `es` y `en`
(`app/javascript/dashboard/i18n/locale/{es,en}/...`). Etiquetas UI en español.
