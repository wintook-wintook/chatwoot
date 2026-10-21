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

---

## Ajuste visual a los componentes nativos (21/10/2026)

Referencia: Ajustes › Respuestas predefinidas, Registros de auditoría y la configuración de un inbox.

| Fase | Pantallas | Qué cambió | Commit |
|---|---|---|---|
| A | Lista, «En construcción», «Recursos» | contenedor de `SettingsWrapper` (`p-6 sm:py-8 lg:px-16`, `max-w-8xl`, `font-inter`), `BaseSettingsHeader` con «+ Nuevo agente» en `actions`, `woot-tabs`, tablas nativas (`divide-y`, `py-4 pr-4`, sin tarjeta), `TableFooter` con su clase nativa, `woot-loading-state`, `woot-label` para estados, botones de fila `tiny` | `fa66206a` |
| B | Espacio del agente, Versiones | `BackButton` (con `back-url` a la lista: sin él haría `router.go(-1)`) + `BaseSettingsHeader` (objetivo como descripción, bandeja y versión activa como `woot-label`), `woot-tabs` horizontales en lugar del menú lateral, Versiones como tabla nativa con el diff bajo la fila | ver `git log` |
| C | Ficha (`EditTemplate.vue`) | campos sin clases propias (estilo global de `_base.scss`; textareas con `!h-auto`), títulos de campo con la tipografía del `<label>` nativo, errores con `.error`, título solo en el alta. Línea base de eslint 169 → 153 | `7c87d9d1` |
| D | Asistente por dentro | títulos de los 12 modales con la tipografía de `woot-modal-header` (sin cambiar su estructura), títulos de sección sin mayúsculas (`text-sm font-semibold`), comprobador y origen de versión con `woot-label`, 29 párrafos de ayuda a `text-sm` slate-600 (help-text nativo). Datos chicos (contadores, fechas) siguen en `text-xs`; el editor no cambia | ver `git log` |

---

## Arreglos de seguridad del flujo (21/10/2026)

| # | Problema | Arreglo |
|---|---|---|
| 2 | Publicar desde el Asistente pisaba en silencio un cambio hecho después (otro admin, restaurar, la ficha) | La conversación guarda `base_version` (de qué versión del agente partió, al ligarse). Al publicar, si el Entrenamiento cambió desde esa versión, `SaveService` responde `stale_draft` con la versión, autor y fecha; el Asistente pregunta y «Publicar de todos modos» reenvía con `force`. Conversaciones anteriores (sin base) publican como antes |
| 3 | Al abrir un agente se retomaba el borrador de cualquier admin | Solo el propio (`mine`); los de otros se retoman a propósito desde «En construcción» |
| 4 | Cualquier usuario podía restaurar versiones | `restore` exige administrador (401 si no) y el botón solo aparece para admin |

Migración: `20261021210000_add_base_version_to_tracking_assistant_sessions`.
Pruebas: servidor 737 ejemplos (solo las 3 fallas previas de la Galería); navegador 165.

---

## Pendiente: un agente con varias bandejas (anotado 21/10/2026)

Hoy cada agente tiene una sola bandeja (`inbox_id`) y en la práctica **1 agente = 1 canal**: la Ficha exige bandeja, y las automatizaciones y la asignación desde la conversación solo ofrecen los agentes de esa bandeja (los que no tienen bandeja no aparecen). Para usar un agente en otro canal hay que duplicarlo.

Propuesta: `inbox_ids` (lista) con migración que copia la bandeja actual; `inbox_id` se queda sincronizada un tiempo.

| Dónde | Cambio |
|---|---|
| Automatización: elegir agente (`useAutomation.js`) | agentes con **alguna** de las bandejas de la condición |
| Automatización: al ejecutarse (`action_service.rb`) | la bandeja de la conversación si está en la lista; si no, no asigna |
| Asignar desde la conversación (`ContactTrackingModal.vue`) | filtra por «la lista incluye esta bandeja» |
| Masiva, campañas continuas, importar, `/sigue` | elegir la bandeja al asignar (con una sola, automática) |
| Ficha: plantillas de WhatsApp por intento | **decisión abierta**: A) por bandeja (recomendada) · B) solo misma WABA · C) mismas por nombre |
| Asistente, lista, versiones | probar con cualquiera; varias etiquetas; versionar la lista |

Fases propuestas: 1 datos · 2 automatizaciones y conversación · 3 masiva/campañas/importar/`/sigue` · 4 Ficha · 5 Asistente/lista/versiones. Antes: plan con diagramas.
