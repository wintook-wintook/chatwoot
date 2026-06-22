---
titulo: Plan — Modo simple (osTicket) por defecto · ITIL opcional
tipo: plan
tags: [tickets, osticket, itil, modo-simple, plan]
fecha: 2026-06-22
estado: propuesta
---

# 🎚️ Plan — Modo simple (osTicket) por defecto

> **Decisión (2026-06-22):** osTicket NO tiene ITIL. El ITIL de MGCI es un
> **superset opcional**, no parte de la paridad osTicket. NO se quita (ya está
> construido, es opcional en datos, es el diferenciador). Se **atenúa** con un
> **Modo simple por defecto** que oculta lo ITIL en la UI; un toggle por cuenta
> activa el **Modo ITIL**. Norte: [[Referencia-osTicket]].

---

## 1. La idea

```
   MODO SIMPLE (default, se siente 100% osTicket)     MODO ITIL (toggle por cuenta)
   ───────────────────────────────────────────       ─────────────────────────────
   Estados: Nuevo · En progreso · Esperando ·         los 13 estados ITIL completos
            Resuelto · Cerrado · Cancelado            (classified, assigned,
   Prioridad: dropdown directo                         in_diagnosis, validating,
   OCULTO: naturaleza ITIL, impacto/urgencia,          escalado, waiting_on_*…)
           aprobación de cambios, problema/cambio      Impacto×Urgencia, naturaleza,
                                                       problema/cambio, aprobaciones

   ⚠️ Los DATOS y la LÓGICA ITIL siguen intactos por debajo. El modo simple es
      una CAPA DE PRESENTACIÓN (UI), no borra ni mutila nada.
```

**Principio rector:** backend permisivo + UI filtrada. Nada se elimina del modelo;
el modo solo decide *qué se muestra y qué transiciones ofrece la UI*.

---

## 2. Backend — un interruptor por cuenta

| Pieza | Propuesta |
|-------|-----------|
| Almacén del modo | Tabla `case_settings` (has_one por cuenta), columna `itil_enabled` boolean **default `false`** (= simple). Migración al final. |
| API | `GET`/`PATCH` `case_settings` (admin). El front lo lee al cargar el módulo. |
| Lectura global | Exponer `itil_enabled` en el bootstrap del módulo (igual que se hace con otras configs por cuenta) para que las vistas lo consulten sin pedirlo en cada una. |

> ❌ **No usar feature flag** (`config/features.yml`) para esto: el bitfield FlagShihTzu
> es global/super-admin y frágil (ver [[Trampas]] #11). Queremos un toggle self-service
> en el admin del módulo → tabla propia.
>
> ✅ El backend **sigue permitiendo** todas las transiciones y campos ITIL. El modo
> simple NO restringe la API (para no romper reglas/IA ni datos existentes).

---

## 3. Frontend — render condicional según el modo

Leer `itilEnabled` del store y envolver lo ITIL en `v-if="itilEnabled"`.

| Vista / componente | En MODO SIMPLE |
|--------------------|----------------|
| `CaseTicketModal` (crear normal) | ocultar Naturaleza ITIL + fila Impacto·Urgencia (dejar solo Prioridad directa) |
| `CaseTicketInternalModal` (interno) | idem |
| Form del **portal** (`new.html.erb`) | ya es simple; nada que ocultar (no expone ITIL) |
| `TicketDetail` | ocultar tarjetas Problema/Cambio (2F), Impacto/Urgencia, aprobación, badge de naturaleza |
| Dropdown de estados | ofrecer solo los 5–6 estados simples (ver §4) |
| `Kanban` | columnas = estados simples |
| `Metrics` | ocultar KPIs ITIL (problemas/cambios) *(opcional)* |
| `TicketRules` (builder) | ocultar campos ITIL del selector *(opcional, baja prioridad)* |
| Admin | toggle "Modo ITIL avanzado" en una pantalla de ajustes del módulo |

> La IA (3A-3F) tiene su **propio** toggle (`AiConfig`), independiente de ITIL → no se toca.

---

## 4. Mapeo de estados simple ↔ ITIL (el detalle clave)

Los 13 estados reales y cómo se presentan/operan en modo simple:

```
ESTADO REAL (DB)            MODO SIMPLE — se MUESTRA como    Acción del dropdown simple → estado real
─────────────────          ────────────────────────────     ─────────────────────────────────────────
open                       Nuevo                            "Nuevo"
classified                 En progreso  (colapsado)
assigned                   En progreso  (colapsado)
in_diagnosis               En progreso  (colapsado)
in_progress                En progreso                      "En progreso"   → in_progress
escalated                  En progreso  (colapsado)
waiting_on_customer        Esperando                        "Esperando"     → waiting_on_customer
waiting_on_third_party     Esperando    (colapsado)
waiting_on_internal        Esperando    (colapsado)
resolved                   Resuelto                         "Resuelto"      → resolved
validating                 Resuelto     (colapsado)
closed                     Cerrado                          "Cerrado"       → closed
cancelled                  Cancelado                        "Cancelado"     → cancelled
```

- **Mostrar:** una tabla `SIMPLE_STATUS_MAP` (estado real → etiqueta simple) para
  badges y columnas Kanban.
- **Operar:** el dropdown simple solo ofrece transiciones a `in_progress`,
  `waiting_on_customer`, `resolved`, `closed`, `cancelled` (las que `VALID_TRANSITIONS`
  permita desde el estado actual). Los estados "colapsados" se siguen viendo bien
  porque se mapean a su etiqueta simple, pero el agente no los elige a mano.

---

## 5. Puntos abiertos (decidir antes de implementar)

1. **¿Reglas/IA pueden poner estados ITIL en modo simple?**
   - (a) Sí (backend permisivo); la UI los colapsa al mostrar. *(recomendado: menos invasivo)*
   - (b) En modo simple, suprimir auto-transiciones a estados ITIL-only.
2. **Métricas ITIL en simple:** ¿ocultar las tarjetas de problemas/cambios o dejarlas en 0?
3. **Tickets ya existentes en estado ITIL** al activar/desactivar el modo: se muestran
   con su etiqueta simple (no hay migración de datos). ¿OK?
4. **Granularidad del toggle:** ¿un solo `itil_enabled`, o sub-toggles
   (estados / matriz impacto-urgencia / problema-cambio) por separado? *(recomiendo
   uno solo para empezar; sub-toggles después si se piden)*.
5. **¿Dónde vive el toggle en el admin?** ¿pantalla nueva "Ajustes del módulo" o
   dentro de una existente (ej. junto a Folio/IA)?

---

## 6. Fases sugeridas

```
Fase S1 — Interruptor + lo más visible
  └─ case_settings + API + toggle admin (default simple)
  └─ Modales de creación (normal/interno): ocultar naturaleza + impacto/urgencia
  └─ Dropdown de estados simple + SIMPLE_STATUS_MAP (badges)

Fase S2 — Resto de la UI
  └─ TicketDetail (ocultar tarjetas ITIL)
  └─ Kanban (columnas simples)

Fase S3 — Pulido (opcional)
  └─ Métricas ITIL ocultas · builder de reglas filtrado
```

**MVP = Fase S1:** con el toggle + modales + estados simples ya "se siente osTicket".

---

## 🔗 Relacionado
- [[Referencia-osTicket]] · [[Conciliacion-osTicket-MGCI]] · [[Plan-User-Portal]]
- [[Modelo-de-datos]] (enums status/ticket_kind/impact/urgency) · [[Trampas]] (#11 feature flags)
- [[Historial-de-implementacion]] · [[Pendiente]]
