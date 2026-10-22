---
titulo: Índice — Gestor de Tickets (MGCI)
tipo: indice
tags: [tickets, indice, moc]
---

# 🎫 Gestor de Tickets (MGCI) — Bóveda de conocimiento

Base de conocimiento del módulo de tickets ITIL de **Kontrolya / Wintook**
(rama `feat/tickets`). Cada nota es atómica y enlazada con `[[wikilinks]]`.
Esta bóveda es la versión **navegable** del skill `@tickets_cases`; el skill
en `~/.claude/commands/tickets_cases.md` quedó como índice delgado que apunta
aquí (para que Claude cargue solo lo relevante y ahorre contexto).

> **Convención del módulo:** tablas/columnas/enums y código en **inglés**;
> etiquetas de UI en **español**. Migraciones siempre al final. Todo cambio
> relevante genera evento en `case_events`. Flag `case_management`.
> UI Tailwind + `dark:` + iconos Fluent. i18n es/en. Borrados con `woot-delete-modal`.

---

## 🧭 Empezar aquí (al retomar)

0. [[Referencia-osTicket]] — ⭐ norte del proyecto: MGCI se hace lo más parecido a osTicket
1. [[Vision-y-convenciones]] — qué es, para qué, reglas del módulo
2. [[case_type-tabla-configurable]] — ⭐ cambio arquitectónico que rompe el diseño original
3. [[Trampas]] — ⚠️ leer SIEMPRE antes de tocar nada
4. [[Historial-de-implementacion]] — qué ya está hecho (changelog)
5. [[Pruebas-en-browser]] — login, Puppeteer, cómo verificar

---

## 📐 Diseño (especificación original)

- [[Vision-y-convenciones]] — propósito, capas, estado por fase, qué NO se toca
- [[Modelo-de-datos]] — `CaseTicket` / `CaseEvent` / `CaseRule`, enums, columnas, transiciones
- [[Servicios-Directiva-Integracion]] — servicios, jobs, `@crear_ticket`, hook en el bot
- [[UI-y-API]] — puntos de entrada en el dashboard + endpoints REST
- [[Archivos-y-fases]] — archivos a crear + plan de fases original
- [[Fase-0-Migraciones-Modelos]] — detalle de migraciones y modelos
- [[Flujos-y-notas]] — flujos de referencia A–E + notas importantes

## 🛠️ Implementación (estado real)

- [[case_type-tabla-configurable]] — ⭐ `case_type` es tabla, NO enum
- [[Archivos-reales]] — rutas exactas backend + frontend construidas
- [[Vistas-guardadas]] — 🔖 filtros de la cola guardados con nombre, personales o compartidos
- [[Rutas-Metricas-Builder]] — rutas frontend, endpoint de métricas, builder de reglas
- [[Trampas]] — ⚠️ decisiones técnicas y gotchas (numeradas 1–20)
- [[Feature-flag-case_management]] — activar el módulo por cuenta
- [[Pruebas-en-browser]] — credenciales, Chrome, Puppeteer
- [[Pendiente]] — lo que falta
- [[Plan-asignacion-contacto-internos]] — plan: asignación manual · ticket desde contacto · tickets internos
- [[Plan-User-Portal]] — 🌐 plan: superficie del cliente estilo osTicket (Open/Check/KB)
- [[Plan-Modo-Simple]] — 🎚️ plan: modo simple (osTicket) por defecto, ITIL opcional vía toggle
- [[Plan-Practicidad-osTicket]] — ⚡ plan: ficha accionable inline · conversación al frente · cola tabla (P1 hecho)
- [[Plan-Notas-Internas]] — 📄 plan: bitácora de notas internas en el ticket (enum ya existe, falta UI/endpoint)
- [[Plan-Widget-Embebible]] — 🔌 plan: launcher + iframe para capturar tickets desde la web del cliente
- [[Plan-Ticket-Cerrado]] — 🔒 plan: reglas del ticket cerrado (reabrir con motivo, congelar edición, reapertura por respuesta del cliente)
- [[Plan-Clase-Comercial]] — 💼 plan: Clase de caso (Soporte/Comercial/…) + oportunidades (F0–F5 hechas)
- [[Plan-Clase-Proyecto]] — 📐 plan: clase Proyecto (P1 hecha; hijos, hitos, línea de tiempo y métricas pendientes)
- [[Plan-Clase-Orden-de-Trabajo]] — 🛠️ plan: clase Orden de trabajo y capacidades por clase (F1 hecha)
- [[Plan-Metricas-Comercial]] — 📊 plan: Métricas de Comercial en 4 pestañas (¿Cómo vamos? · Dinero en juego · Mes a mes · ¿Por qué perdemos?) — M1–M4 hechas
- [[Plan-Resumen-Negocio]] — «Resumen del negocio» para el dueño: todas las clases en una pantalla, acceso por casilla, IA «Explícame la semana»
- [[Plan-Empresa-Un-Solo-Hombre]] — 🧭 plan ABIERTO (en pausa): empresa de un solo hombre, todo ligado y automatizado (agentes hacen todo, el humano solo las excepciones) · base: docs/kontrolya_operacion_autonoma_analisis.md
- [[Plan-Delegar-Agente-Caso]] — 🤖 plan (sin programar): delegar un caso a un agente IA; la Automatización es el eje, catálogo único de acciones y cada agente con sus automatizaciones · motor del plan de un solo hombre
- [[Plan-Plantilla-Tareas-Etapa]] — ✅ hecho (T1–T4): plantilla, tareas al entrar, avance y «Documenta…», qué mueve cada etapa: plantilla de tareas por etapa en cada tipo de caso; se crean al entrar a la etapa, avance «sugerir» al terminar las obligatorias, nunca avanza sin documentar
- [[Plan-Inicio-Mi-Resumen]] — ✅ hecho: Inicio «Mi resumen» donde aterriza cada usuario (avisos, Mi día, agenda, conversaciones, casos, semana) y preferencia «Al iniciar sesión, ir a»
- [[Cambiar-Clase-Tipo]] — ✅ hecho: cambiar de clase un tipo; con casos se crea el tipo nuevo y el de antes queda retirado con sus casos tal cual
- [[Plan-Bandeja-Prioridad]] — 🎯 plan: «Mi día» en la bandeja de tareas, orden por puntaje de urgencia, pesos configurables y plan con IA (F1–F4 hechas)
- [[Plan-Casos-Hoja-de-ruta]] — 🧭 hoja de ruta: menú por clase (E1 hecho), clase fija, Comercial y Soporte completos
- [[Historial-de-implementacion]] — changelog de todo lo resuelto

---

## 🔎 Vista por estado (Dataview)

> Requiere el plugin **Dataview** instalado en Obsidian.

```dataview
TABLE tipo, fase, tags
FROM "vault-tickets"
WHERE tipo != "indice"
SORT tipo ASC, titulo ASC
```

## 🗺️ Mapa de fases ITIL

```
 FASE 1 — BASE          FASE 2 — ITIL OPERATIVO        FASE 3 — IA
 ✔ Listado + filtros    2A Estados (13)  2G Cierre     3A Infra IA
 ✔ Detalle + timeline   2B Clasificación 2H KB         3B Clasificación
 ✔ Tipos/Reglas/Folio   2C Kanban        2I SLA av.    3C Respuesta sugerida
 ✔ SLA monitor          2D Escalamiento  2J Métricas   3D Detección repetidos
                        2E Relaciones    2K Campos      3E Resumen+causa raíz
                        2F Problema/Cambio 2L Avance    3F Seguimiento
```
Todas implementadas y verificadas en navegador → ver [[Historial-de-implementacion]].
