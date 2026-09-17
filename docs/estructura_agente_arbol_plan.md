# Estructura del Agente: el árbol

**Rama:** `feat/motor_agentes_ia` · **Pedido:** 17/09/2026 · **Estado:** plan, sin código
**Antecede:** `docs/formulario_entrenamiento_plan.md` (F0–F7: el formulario por secciones ya está
hecho y vive en el Asistente).

---

## 1. Qué se pide

La columna izquierda del Asistente se llama hoy **Secciones** y es un acordeón de tarjetas: cada
sección con su caja de texto abierta ahí mismo. Se pide cambiarla por un **árbol** llamado
**Estructura del Agente**, con tres ramas fijas, y que **todo se edite en un modal**:

```
Estructura del Agente
│
├── Definición del Agente        ← modal con caja de texto amplia
│   ├── Objetivo
│   └── Contexto
│
├── Ramas                        ← el modal de rama que ya existe (RouteModal)
│   ├── programacion_citas
│   └── cancelacion_citas
│
└── Secciones                    ← modal con caja de texto amplia
    ├── ROL
    ├── ALCANCE POR RAMA
    ├── REGLAS DE EVIDENCIA
    └── ESTILO
```

Lo que **no** cambia: la columna derecha (Entrenamiento en texto + Versiones + el informe del
comprobador), el backend entero (`TrainingStructure`, `TrainingRoutes`, `training_preview`) y la
invariante de que abrir un agente y guardarlo sin tocar nada no cambia ni un carácter.

---

## 2. Dónde se guarda cada nodo (la pregunta del pedido)

**No hay una tabla de ramas ni de secciones, y el plan no propone crearlas.** Hay dos lugares, según
si el agente todavía se está armando o ya se guardó:

```
   MIENTRAS SE ARMA                          AL DAR "GUARDAR EN UN AGENTE IA"
   tracking_assistant_sessions               tracking_templates
   ┌───────────────────────────┐             ┌────────────────────────────────────┐
   │ proposal   jsonb          │──nombre────▶│ name                    string    │
   │  { name, objective,       │──objetivo──▶│ objective               string    │
   │    ai_context }           │──contexto──▶│ ai_context              text      │
   │                           │             │                                    │
   │ draft      text  ─────────┼──el texto──▶│ complementary_prompt    text      │
   │  (ramas + secciones,      │   entero    │  (las ramas son sus líneas @ruta)  │
   │   un solo texto)          │             │                                    │
   │                           │             │ training_structure      jsonb     │
   │ validation jsonb          │             │  (el mismo texto en bloques:       │
   │ draft_versions jsonb      │             │   ramas con campos, secciones      │
   │ messages   jsonb          │             │   con su cuerpo) ← se regenera     │
   └───────────────────────────┘             └────────────────────────────────────┘
```

| Nodo del árbol | Dato real | Dónde vive mientras se arma | Dónde queda al guardar |
|---|---|---|---|
| Definición → Objetivo | una frase | `sessions.proposal['objective']` | `tracking_templates.objective` |
| Definición → Contexto | la "BASE DE CONOCIMIENTO" del agente | `sessions.proposal['ai_context']` | `tracking_templates.ai_context` |
| Ramas → cada rama | una línea `@ruta(...)` | dentro de `sessions.draft` | dentro de `complementary_prompt`, y en `training_structure` como campos |
| Ramas → rama por defecto | la línea `@ruta_por_defecto:` | ídem | ídem |
| Secciones → cada sección | un rótulo `[X]` y su cuerpo | ídem | ídem |

**Consecuencias que el árbol tiene que respetar:**

1. **El texto es la verdad.** `training_structure` es un espejo derivado: se regenera en cada
   guardado desde el texto. El árbol se dibuja sobre ese espejo, pero lo que se guarda sigue siendo
   el texto — por eso cada edición pasa por `training_preview`, igual que hoy.
2. **La Definición no está en el texto.** Objetivo y Contexto son columnas aparte, así que esos dos
   nodos **no** tocan el Entrenamiento ni el comprobador: se escriben en `proposal` y viajan al
   agente recién al guardar. Hoy solo se pueden escribir dentro del modal "Guardar en un Agente IA"
   (Contexto con una caja de 3 renglones); el árbol los saca a la vista, que es la mitad del pedido.
3. **Nada se escribe en el agente hasta Guardar.** Eso no cambia.

### ¿Convendría una tabla de ramas y secciones?

Se puede, y no hace falta para este árbol. El costo es que la verdad se duplica: el motor lee el
**texto** (`RouteMap` parsea `complementary_prompt` en cada turno), así que una tabla sería otro
espejo más que mantener sincronizado, con una fuente más de "se guardó pero el motor sigue leyendo
lo viejo". Tendría sentido el día que haga falta **consultar ramas entre agentes** (por ejemplo:
"qué agentes usan la hoja Precios", o métricas por rama). Queda como decisión abierta (§8), no como
parte de esto.

---

## 3. Qué tan grande es el árbol (medido, no supuesto)

Sobre los **28 agentes con Entrenamiento** del respaldo del 11/09/2026:

| | total | mediana | máximo | agentes en 0 |
|---|---|---|---|---|
| Ramas | 33 | 0 | **7** | 19 |
| Secciones | 275 | 7 | **31** | 8 |
| "Texto inicial" (antes de la primera sección) | 26 | 1 | 1 | 2 |
| Rama por defecto | 3 | 0 | 1 | 25 |
| Líneas del bloque de ramas que el parser no reconoce | **0** | 0 | 0 | 28 |

Objetivo: siempre escrito (mediana 88 caracteres, máximo 497).
Contexto: escrito en 27 de 29 (mediana 148, máximo 788; 6 pasan de 500).

**Lo que eso decide:**

- El peor caso son **31 secciones** (los tres "CONSULTOR JUNIOR") y **7 ramas** (el coordinador
  v6.x). Un árbol de 38 nodos no cabe sin **plegar**: los tres grupos arrancan abiertos, pero
  "Secciones" se pliega solo cuando pasa de 8 (el mismo criterio que ya usa el acordeón).
- **19 de 28 agentes no tienen ramas.** El grupo "Ramas" tiene que verse igual, vacío, con su
  "Agregar rama" — es la forma de que se note que se puede.
- El **"Texto inicial"** existe en 26 de 28: no es un caso raro, necesita su lugar en el árbol (§5).
- Ninguna línea suelta en el bloque de ramas hoy, pero la estructura las admite: el árbol no las
  puede esconder, porque esconderlas las borraría al guardar.
- El Contexto llega a 788 caracteres: la caja del modal va **amplia** (12 renglones), no de 3.

---

## 4. La pantalla

```
┌─ Asistente de Agentes IA ──────────────────────────────────────────────────────────┐
│ #2061 · conversación                          Canal del agente [kontrolyaBots ▾]   │
│ ✓ Entrevista › ✓ Borrador › ⚠ Comprobado 2 problema(s) › ● Probado                  │
├────────────────────────────────┬───────────────────────────────────────────────────┤
│ ESTRUCTURA DEL AGENTE          │ Entrenamiento │ Versiones                         │
│                                │                                                   │
│ ▾ Definición del Agente        │  @ruta(programacion_citas #citado: quiero...): -  │
│     Objetivo        ✎          │  @ruta(cancelacion_citas: quiero cancelar...): -  │
│     Contexto        ✎          │                                                   │
│                                │  [ROL]                                            │
│ ▾ Ramas                    (2) │  El agente es un asistente virtual que...         │
│     programacion_citas  ⚠ ✎ ✕  │                                                   │
│     cancelacion_citas     ✎ ✕  │  [ALCANCE POR RAMA]                               │
│     ＋ Agregar rama            │  programacion_citas: agenda citas...              │
│     por defecto: (ninguna) ▾   │                                                   │
│                                │  ...                                              │
│ ▾ Secciones                (6) │                                                   │
│     Texto inicial         ✎ ✕  ├───────────────────────────────────────────────────┤
│     ROL                   ✎ ✕  │ Lo que el motor va a leer      2 tema(s) · 2 ⚠    │
│     ALCANCE POR RAMA      ✎ ✕  │  • programacion_citas  #citado                    │
│     FIDELIDAD             ✎ ✕  │    consulta: no consulta nada                     │
│     ETIQUETAS             ✎ ✕  │  ✗ La etiqueta #citado no existe en la cuenta      │
│     ESTILO                ✎ ✕  │                                                   │
│     PROHIBIDO             ✎ ✕  │                                                   │
│     ＋ Agregar sección         │                                                   │
└────────────────────────────────┴───────────────────────────────────────────────────┘
```

- Cada nodo es una fila: nombre + lo que hace falta para saber si está bien (⚠ si el comprobador
  tiene algo que decir de ESE nodo) + editar (✎ o clic en la fila) + quitar (✕ con confirmación).
- Un grupo muestra **cuántos** hijos tiene. Plegar/desplegar por grupo.
- **Mover** una sección de lugar: las flechas ↑↓ aparecen en la fila al pasar el mouse (el orden
  del texto importa: el modelo lo lee en ese orden).
- El nodo activo queda marcado mientras el modal está abierto.

---

## 5. Los cuatro modales

| Nodo | Modal | Campos |
|---|---|---|
| Objetivo | **Definición** | una línea: para qué está el agente. Es lo que va a `objective` |
| Contexto | **Definición** | caja amplia (12 renglones): datos del negocio que el agente puede citar (`ai_context`) |
| una rama | **RouteModal** (ya existe) | nombre, etiqueta, frases del cliente, fuente, si no resuelve (+ tipo y prioridad) y su línea de ALCANCE POR RAMA |
| una sección | **Sección** | nombre (con las sugerencias del contrato y de la cuenta) + caja amplia con su contenido |

**Definición:** los dos nodos abren el mismo modal, con el foco puesto en el campo del nodo. Lleva
un aviso de una línea: *esto no es parte del Entrenamiento; se guarda en el agente al dar Guardar*.
Hoy el Contexto se escribe en una caja de 3 renglones dentro del modal de guardar, y hay agentes con
788 caracteres ahí: el modal nuevo es el lugar para escribirlo.

**RouteModal:** ya está construido y hace falta sumarle **modo editar** (hoy solo agrega): abre con
los valores de la rama, y al guardar reemplaza esa línea `@ruta` en vez de agregar otra. Y al
**quitar** una rama, ofrece quitar también su línea de ALCANCE POR RAMA (están vinculadas, es lo que
se decidió al hacer el modal).

**Sección:** es la caja que hoy vive en la tarjeta, movida al modal y más grande. El "Texto inicial"
(lo que va antes de la primera sección) usa el mismo modal sin el campo de nombre: es un bloque sin
rótulo, y si se le pone nombre deja de ser texto inicial.

**Qué pasa al guardar un modal:** exactamente lo que ya pasa al escribir en una tarjeta — la
estructura se manda a `training_preview`, el backend arma el texto, lo devuelve, y el texto que se
ve a la derecha y el comprobador se actualizan. La Definición es la excepción: no pasa por ahí.

---

## 6. Los hallazgos del comprobador, en el nodo

Hoy el informe de la derecha dice "la etiqueta #citado de la rama 'programacion_citas' no existe" y
hay que buscar a mano de qué rama habla. Cada hallazgo ya trae `line` y muchos traen el nombre de la
rama, así que se pueden colgar del nodo:

```
hallazgo del comprobador          →  nodo del árbol
─────────────────────────────────────────────────────────────
label_not_found (rama X)          →  Ramas › X                    ⚠
unknown_source (rama X)           →  Ramas › X                    ✗
route_not_self_chosen (rama X)    →  Ramas › X                    ⚠
pending_marker (línea N)          →  el nodo que contiene esa línea ✗
contract_label / contract_wrap    →  ídem, por línea              ✗
missing_prose_sections            →  el grupo Secciones           ·
```

Regla: **✗ bloqueante, ⚠ aviso**, y el grupo muestra el peor estado de sus hijos. Un hallazgo que no
se pueda ubicar queda en el informe de la derecha y no se pierde.

---

## 7. Fases

| Fase | Entrega | Cómo se verifica | Días hábiles |
|---|---|---|---|
| **F0** El árbol, solo mirar | `TrainingTree.vue` en la columna izquierda: tres grupos, nodos, contadores, plegado (Secciones se pliega sola desde 8) | Vitest del armado de nodos desde la estructura (incluido el agente de 31 secciones y el de 7 ramas) + navegador | 1,5 |
| **F1** Modal de sección | crear, editar, renombrar, quitar y mover; "Texto inicial" sin nombre | Vitest + navegador: el texto de la derecha cambia solo en esa sección | 1,5 |
| **F2** Ramas | RouteModal en modo editar; quitar una rama ofrece quitar su línea de alcance; elegir la rama por defecto desde el grupo | Vitest + navegador con un agente real de 7 ramas | 1,5 |
| **F3** Modal de Definición | Objetivo y Contexto editables desde el árbol, caja amplia, escriben en `proposal`; el modal de guardar los toma de ahí | Vitest + navegador: se edita, se guarda el agente y quedan en `objective` / `ai_context` | 1 |
| **F4** Hallazgos en el nodo | el mapeo de §6, con el peor estado por grupo | specs del mapeo con hallazgos reales del comprobador + navegador | 1 |
| **F5** Cierre | se retira el acordeón y lo que quede sin uso; i18n es/en completo; repaso de la invariante sobre los 28 prompts | suite entera + el script de ida y vuelta | 0,5 |

**Total: 7 días hábiles.** F0 ya deja algo que se puede mirar y decidir si el árbol va por buen
camino antes de gastar las otras fases.

---

## 8. Decisiones abiertas

1. **¿El árbol reemplaza al acordeón o conviven?** El plan asume que lo **reemplaza** (F5 lo retira):
   dos formas de editar lo mismo es lo que hay que evitar. Si preferís tenerlo un tiempo detrás de un
   conmutador, se cambia F5.
2. **¿"Definición del Agente" incluye el Nombre?** El pedido dice Objetivo y Contexto. El nombre hoy
   se elige al guardar (y se propone uno con versión: "v6.12 - ..."). Propuesta: mostrarlo en el
   árbol como tercer nodo, de solo lectura, y que se siga eligiendo al guardar.
3. **¿Una sección se puede arrastrar para reordenar?** El plan usa flechas ↑↓, que es lo que ya hay y
   no trae dependencias nuevas. Arrastrar es otra fase.
4. **Tabla de ramas y secciones** (§2): no hace falta para esto. Se decide el día que haya que
   consultar ramas entre agentes.
5. **El chat** sigue escondido detrás de `SHOW_CHAT` y este plan no lo toca.
