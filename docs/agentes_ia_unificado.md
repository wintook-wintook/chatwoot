# Agentes IA unificado — el Asistente dentro de cada agente

**Rama:** `feat/agentes_ia_unificado` (sobre `feat/configurar_siempre`, que sale de `develop` @ `4fc45d91`)
**Fecha:** 2026-10-21
**Estado:** implementado; pruebas automáticas en verde; **sin probar en navegador**

---

## Punto de retorno

| Qué | Cómo volver |
|---|---|
| Código | tag **`estable-2026-10-21-antes-agentes-unificados`** (= `develop` @ `4fc45d91`, en GitHub). `git checkout develop` basta mientras esta rama no se mergee |
| Datos (dev) | respaldo `tmp/respaldos/2026-10-21-antes-agentes-unificados.sql.gz` (tracking_templates, tracking_assistant_sessions, tracking_template_versions, categorías, adjuntos; solo datos) |
| Migración de datos | `bin/rails db:migrate:down VERSION=20261021200000` borra las v1 «Estado inicial» que no tengan versiones posteriores |
| «Configurar siempre» | va aparte en `feat/configurar_siempre` (`dc398c10`); se puede tomar sin el rediseño |

La tabla `tracking_template_versions` ya existía en `chatwoot_dev` (del F4 revertido en agosto) y estaba vacía: la migración `20260812120000` figura como corrida, no se volvió a ejecutar.

---

## Antes y después

```
 ANTES                                              AHORA
 Menú: Agentes IA · Asistente                       Menú: Agentes IA
 Agentes IA ─► lista ─► ficha                       Agentes IA ─► lista
            └► «Mejorar con Asistente» ─┐             [Agentes] [En construcción] [Recursos]   [+ Nuevo agente ▾]
 Asistente ─► Asistente · En construcción ·          │ clic en un agente
              Agentes IA (otra lista) · Recursos      ▼
            └► «Guardar» ─► te saca a la lista      Espacio del agente
 Versiones: sueltas por conversación;                 ├ Entrenamiento  (el Asistente; borrador → «Publicar cambios»)
 la ficha no dejaba ninguna                           ├ Ficha          (contexto, reglas, agendas, archivos)
                                                      └ Versiones      (historial con origen, diff, restaurar)
```

## Qué se hizo

| Pieza | Archivos |
|---|---|
| Versiones por agente con su origen | `TrackingTemplateVersion`, `TrackingTemplate#record_version`, `TrackingTemplates::VersionDiff`, `TrackingTemplates::VersionsController` (index · show `?compare_with=` · restore) |
| Origen de cada versión | `create` alta · `manual` ficha · `assistant` Asistente · `configured` «Configurar» · `gallery` Galería (título y versión en la nota) · `restore` · `baseline` |
| El Asistente hereda el origen | `SaveService#version_origin`: lo cambiado en la conversación desde que se cargó; todo de «Configurar» → `configured`, si no `assistant`; la nota junta lo que declaró el Asistente |
| Conversación ligada al agente | `TrackingAssistantSession#link_template` desde el primer autoguardado o turno de chat (antes: recién al publicar) |
| v1 para los agentes existentes | migración `20261021200000` (23 en dev) |
| Espacio del agente | `views/contactTrackings/AgentWorkspace.vue`, ruta `contact_trackings_agent` (`/tracking-dashboard/agents/:id\|new`, `?seccion=` `?session=` `?galeria=1`) |
| Versiones (pantalla) | `agents/AgentVersions.vue` (reusa `diffHunks` del Asistente) |
| Lista | `Index.vue`: pestañas, «+ Nuevo agente ▾», columna «Revisión», clic = abrir; `agents/SessionsPanel.vue`, `agents/InventoryPanel.vue` |
| Asistente embebido | `Assistant.vue` sin pestañas (≈2 660 → 1 975 líneas); props `templateId`, `initialSessionId`, `openGallery`; emite `saved`, `installed`, `session`; botón «Publicar cambios» / «Crear el Agente IA» |
| Ficha en el espacio | `EditTemplate.vue` prop `hideTraining`: para admin no muestra ni manda el Entrenamiento (no pisa lo publicado desde el Asistente) |
| Rutas y menú | `/assistant` y Ajustes › Agentes IA redirigen; «Asistente» sale del menú; lista y espacio con los permisos que tenía Ajustes |

## Cómo funciona

```
 Abrir un agente (admin) ─► Entrenamiento
     ¿tiene conversación abierta? ── sí ─► se retoma (borrador sin publicar)
                                  └─ no ─► se carga el agente publicado
     editar / chat / «Configurar» ─► se guarda solo en la conversación (ligada al agente)
     «Publicar cambios» ─► SaveService (comprobador) ─► agente actualizado
                           └► after_save ─► versión N+1 { source, note, autor }
                           └► se queda en el mismo agente

 Ficha ─► Guardar ─► versión { source: manual }
 Versiones ─► Restaurar vK ─► versión N+1 { source: restore, note: «Restaurado desde la versión K» }
```

## Decisiones tomadas sin preguntar (revisables)

1. **Borrador vs. en vivo:** borrador solo para el Entrenamiento (ya existía: la conversación del Asistente); la ficha guarda directo, con versión.
2. **«Agente IA | Agente seguimiento»** de la ficha: sin cambios.
3. **Agentes sin rol admin:** ven Ficha y Versiones; Entrenamiento con Asistente es de admin (igual que antes).
4. **Ajustes › Agentes IA** sigue en el menú de Ajustes pero lleva a la misma lista (quitarlo podía dejar sin acceso a roles personalizados).
5. **Archivar y detector de copias** del F4 original: no se trajeron.

## Pila de pruebas

- Servidor: 40 nuevas/ajustadas (modelo, controlador de versiones, diff, `SaveService` con origen, ligado de la conversación). Conjunto ampliado: 634 ejemplos, solo las 3 fallas previas de publicaciones de la Galería (cuentan la publicación real de `chatwoot_dev`; fallan igual sin estos cambios).
- Navegador (vitest): 164 en verde, 10 nuevas (`AgentWorkspace.spec.js`, `AgentVersions.spec.js`).
- webpack: «Compiled successfully».
- **Pendiente: probar en develop.wintook.com.** Recorrido sugerido:
  1. Agentes IA → abrir un agente → Entrenamiento: editar una línea, salir, volver → el cambio sigue (borrador).
  2. «Publicar cambios» → se queda en el agente; encabezado «v2 activa»; Versiones muestra v2 «Asistente».
  3. Ficha → cambiar el objetivo → Guardar → Versiones: v3 «A mano (ficha)».
  4. Versiones → Restaurar v1 → v4 «Restaurada»; el Entrenamiento muestra el texto restaurado.
  5. «+ Nuevo agente ▾» → Bajar de la Galería → al bajar, la ruta pasa a ese agente con «Configurar» abierto.
  6. Pestaña «En construcción» → retomar una conversación → abre en su agente.
  7. Entrar con un usuario agente: solo Ficha y Versiones.
