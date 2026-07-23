---
titulo: Plan — Practicidad osTicket (ficha accionable · conversación al frente · cola tabla)
tipo: plan
tags: [tickets, osticket, ux, practicidad, plan]
fecha: 2026-06-23
estado: EN CURSO — P1, P2 y P3 hechos; P4 pendiente
---

# ⚡ Plan — Practicidad estilo osTicket

> **Diagnóstico (2026-06-23):** a MGCI no le faltan *features*, le falta la
> **practicidad** de osTicket. La esencia de osTicket es que el agente resuelve
> **todo el ticket desde una sola pantalla, sin modales y sin cambiar de pestaña**,
> y trabaja el día desde una **cola tipo tabla** con acciones en lote.
> Hoy MGCI tiene todo, pero repartido en **modales, pestañas y tarjetas**.
> Norte: [[Referencia-osTicket]]. Relacionado: [[Plan-Modo-Simple]].

> ✅ **P1 hecho** (2026-06-26): barra de acciones inline en la cabecera del
> detalle — "Tomar" (claim), prioridad inline y estado. Ver [[Historial-de-implementacion]].

---

## 1. El principio

```
  osTicket = DENSIDAD + INLINE + UNA PANTALLA

  • La COLA es una mesa de trabajo (tabla, ordenar, lote, colas guardadas).
  • La FICHA se edita inline (dropdowns directos, sin modal).
  • El HILO de conversación es el protagonista (no una pestaña escondida).
  • Cada acción frecuente está a 1 clic (Tomar, Responder, Cambiar estado).
```

No se quita nada de lo construido. Esto es **UX/presentación**: reordenar y
hacer inline lo que hoy vive en modales y pestañas. Compatible con [[Plan-Modo-Simple]]
(en modo simple se ven menos opciones; en modo ITIL, todas).

---

## 2. Estado actual vs osTicket (resumen)

```
 ÁREA            osTicket (práctico)              MGCI hoy                  Gap
 ───────────────────────────────────────────────────────────────────────────
 Cola            tabla + columnas + lote +        ✅ P3: tabla + orden +    HECHO
                 colas guardadas                  lote + colas (tabs)
 Ficha           dropdowns inline, efecto         ✅ P1: barra inline      HECHO
                 inmediato                        (Tomar/Prioridad/Estado)
 Conversación    es la página (hilo central)      ✅ P2: hilo en el         HECHO
                                                  Resumen + sidebar
 Tomar (claim)   1 clic autoasignar               ✅ P1: botón "Tomar"     HECHO
 Vencimiento     visible en cola, rojo si vence   solo SLA dot             MEDIO
 Predefinidas    canned en la caja de respuesta   caja simple              MEDIO
 Colaboradores   CC en el ticket                  no existe                BAJO
 Imprimir        botón imprimir ficha             no existe                BAJO
```

---

## 3. Fase P1 — Ficha accionable inline  ⭐ ✅ HECHO

**Objetivo:** resolver el ticket sin abrir modales. Barra de acciones en la
cabecera con **Tomar** (autoasignar en 1 clic), **Prioridad** (dropdown con dots
de color) y **Estado** (dropdown de transiciones), efecto inmediato.

**Antes (modal):**

```
┌──────────────────────────────────────────────── [ Cambiar estado ▾ ] ┐  ← abre MODAL
│  SOP-00001 · Error en la aplicación                                   │
│  ESTADO  Cancelado (texto)   PRIORIDAD  Media (texto)                 │  ← no editable
│  Asignación: EQUIPO [—]  AGENTE [—]                                   │  ← otra zona
└───────────────────────────────────────────────────────────────────────┘
```

**Después (barra inline):**

```
┌───────────────────────────────────────────────────────────────────────┐
│ ‹ Volver   SOP-00001 · Error en la aplicación                          │
│   [✋ Tomar] [Prioridad: Media ▾] [Escalar] [Cambiar estado ▾]         │
│                                   ├ Baja   ●                            │
│                                   ├ Media  ● ✓                          │
│                                   ├ Alta   ●                            │
│                                   └ Urgente●                            │
└───────────────────────────────────────────────────────────────────────┘
   ▲ Tomar = assign(usuario actual) · Prioridad = update(priority) · Estado = transition
```

**Implementado:**
- **Tomar (claim)**: `claimTicket()` → `assign({assigneeId: currentUserID})`;
  visible solo si `canClaim` (no es ya mío y no está cerrado/cancelado).
- **Prioridad inline**: dropdown `showPriorityMenu` con dots de color + check en la
  actual → `updatePriority` → `case_tickets#update` extendido (permite `priority`,
  valida, registra evento `priority_changed`). Enum `CaseEvent.priority_changed=27`.
- **Estado**: el dropdown de transiciones que ya existía (respeta modo simple/ITIL).
- i18n `CASE_TICKETS.CLAIM/STATUS_QUICK/PRIORITY_QUICK` + `EVENT_TYPES.priority_changed`.
- Verificado en navegador (capturas `mockups/portal/p1-*.png`).

**Pendiente menor de P1 (futuro):** estado/prioridad editables también desde la
tarjeta "Información" (hoy solo desde la barra); cerrar menús con click-afuera.

---

## 4. Fase P2 — La conversación al frente  ✅ HECHO

**Objetivo:** que el agente vea el hilo al abrir el ticket, sin ir a una pestaña.
El hilo pasa a ser el **centro** del Resumen; Información/Tareas/Relacionados →
sidebar derecho colapsable.

```
 ┌─ ficha ─────────────────────────────────────────────────────────────┐
 │ barra de acciones (P1)                                               │
 │ ┌────────── HILO (centro, protagonista) ─────┐ ┌─ sidebar ─────────┐ │
 │ │  ◀ cliente: "No me carga la app"           │ │ Asignado  …       │ │
 │ │  ▶ agente:  "Hola, ¿desde qué disp…?"      │ │ Prioridad …       │ │
 │ │  · nota interna (amarilla)                 │ │ Tareas 1/2  ▸      │ │  ← colapsable
 │ │  [ Responder | Nota ]  [Predef ▾] [Enviar] │ │ Relacionados ▸     │ │
 │ └────────────────────────────────────────────┘ └───────────────────┘ │
 └──────────────────────────────────────────────────────────────────────┘
```

**Alcance:** mover `TicketConversation.vue` (hilo nativo `Message.vue`, U1) al
cuerpo del Resumen; Información/Asignación → sidebar; Tareas/Relacionados como
acordeones (resuelve "las tareas no son prácticas/llamativas").

---

## 5. Fase P3 — La cola como mesa de trabajo  ✅ HECHO

```
 Colas:  [ Míos ]  [ Sin asignar ]  [ Vencidos ]  [ Abiertos ]  [ Todos ]   🔎 [____]
 ┌──┬─────────┬───────────────────┬──────────┬────────┬─────────┬──────────┐
 │☑ │ Folio ▾ │ Asunto            │ Asignado │ Prior. │ Vence ▾ │ Últ. act.│
 ├──┼─────────┼───────────────────┼──────────┼────────┼─────────┼──────────┤
 │☑ │ SOP-001 │ Error en la app   │ Ana      │ Alta   │ 🔴 -2h  │ hace 5m  │
 │☐ │ SOP-002 │ No puedo entrar   │ —        │ Media  │ 2h      │ hace 1h  │
 └──┴─────────┴───────────────────┴──────────┴────────┴─────────┴──────────┘
  Seleccionados: 2  →  [✋ Tomar] [Asignar a ▾] [Cambiar estado ▾] [Cerrar]
```

**Alcance:** tabla (sustituye tarjetas en `Index.vue`); columnas ordenables;
selección múltiple + barra de lote (endpoint `bulk` nuevo o iterar); colas
guardadas = presets de `QUICK_FILTERS`. Responsive: móvil → tarjetas.

---

## 6. Fase P4 — Extras de practicidad (rápidos, PENDIENTE)

```
 ✋ Tomar (claim)      ✅ HECHO en P1 (falta en la fila de la cola → P3)
 📅 Vencimiento        columna "Vence" + edición inline; rojo si vencido
 💬 Predefinidas       dropdown de canned responses en la caja del hilo
 👥 Colaboradores/CC   añadir otros agentes/correos al ticket (modelo nuevo, BAJO)
 🖨️ Imprimir           vista imprimible de la ficha + hilo (BAJO)
```

---

## 7. Orden sugerido

```
 1) P1  Ficha accionable inline   ⭐ ✅ HECHO
 2) P2  Conversación al frente        ✅ HECHO
 3) P3  Cola tipo tabla + lote        ✅ HECHO
 4) P4  Extras (Vence/Predefinidas/CC/Imprimir)  ← siguiente recomendado
```

**Fuera de alcance / se quedan como están:** las Tareas (auxiliar menor; en P2
se vuelven acordeón en el sidebar). ITIL sigue siendo superset opcional
([[Plan-Modo-Simple]]).

---

## 8. Riesgos / notas

- **Inline + modo simple**: cada control inline respeta el filtro de
  estados/transiciones del modo activo (P1 ya lo hace vía `validTransitions`).
- **Bulk actions** (P3): definir endpoint `bulk` o iterar; cuidar SLA y
  eventos (`case_events`) por cada ticket afectado.
- **Tabla responsive** (P3): fallback a tarjetas en móvil.
- **Reutilizar lo nativo de Chatwoot** (canned responses ya existen en el ReplyBox
  nativo) — ver [[feedback_reuse_native_chatwoot_components]] en memoria.

---

## 🔗 Relacionado
- [[Referencia-osTicket]] · [[Plan-Modo-Simple]] · [[Plan-User-Portal]]
- [[Historial-de-implementacion]] · [[Pendiente]] · [[00-Indice]]
