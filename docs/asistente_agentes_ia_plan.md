# Asistente de Agentes IA — generador de Entrenamientos validados

**Un asistente conversacional dentro de Chatwoot que entrevista, redacta y valida el
Entrenamiento de un Agente IA contra el parser real del motor**

| | |
|---|---|
| **Rama de trabajo** | `feat/motor_agentes_ia` (sale de `develop`) |
| **Estado** | F0–F7 implementadas, con specs. Sin PR a `develop` todavía |
| **Ubicación en la app** | `/app/accounts/:id/tracking-dashboard/assistant` |
| **Reemplaza** | el botón "generar prompt" de `EditTemplate.vue` |
| **Fecha** | 08/09/2026 |
| **Documentos base** | `motor_agentes_ia_manual.md` · `generador_prompts_chatgpt.md` · `agentes_ia_como_crear_un_prompt.md` |

---

## Índice

| # | Sección | Para qué |
|---|---|---|
| 1 | [El problema, medido](#1-el-problema-medido) | la evidencia que justifica el módulo |
| 2 | [Qué se construye](#2-qué-se-construye) | el alcance en una imagen |
| 3 | [Arquitectura: tres estaciones y un bucle](#3-arquitectura-tres-estaciones-y-un-bucle) | por qué no es una cascada |
| 4 | [Estación 1 · Inventario](#4-estación-1--inventario) | lo que Ruby lee de la cuenta |
| 5 | [Estación 2 · Entrevista y redacción](#5-estación-2--entrevista-y-redacción) | el meta-prompt en dos mitades |
| 6 | [Estación 3 · Validador](#6-estación-3--validador) | reglas, severidades y mensajes |
| 7 | [El frontend](#7-el-frontend) | wireframes pantalla por pantalla |
| 8 | [Modelo de datos](#8-modelo-de-datos) | qué se persiste y qué no |
| 9 | [API](#9-api) | endpoints y contratos |
| 10 | [Modelo de IA y costo](#10-modelo-de-ia-y-costo) | qué modelo, cuántos tokens |
| 11 | [Fases](#11-fases) | roadmap en días hábiles |
| 12 | [Archivos que toca](#12-archivos-que-toca) | mapa de cambios |
| 13 | [Riesgos y decisiones pendientes](#13-riesgos-y-decisiones-pendientes) | lo que falta definir |
| 14 | [Lo que NO entra](#14-lo-que-no-entra) | límites del alcance |

---

## 1. El problema, medido

Todo lo de esta sección se midió el 08/09/2026 contra la cuenta 2 con su integración
OpenAI real. No son estimaciones.

### 1.1 El generador que existe hoy produce agentes inertes

Entrada enviada por la ruta del botón que ya está en producción
(`EditTemplate.vue:1378` → `contact_trackings_controller.rb:447`):

```
quiero generar un agente ia que recaude informacion para crear un ticket
respecto a su problema de soporte
```

Salida:

```
ROL:      El bot actúa como un asesor comercial profesional…
OBJETIVO: Recaudar información necesaria para crear un ticket de soporte.
PROHIBICIONES:
  - No hacer preguntas al usuario final.        ← contradice el pedido
```

Veredicto del parser real del motor:

```
  Ramas que el motor va a leer:  0
  Fuente detectada:              nil
  ¿Crea ticket?                  false
```

Dos fallas, ambas de origen conocido:

| Falla | Causa |
|---|---|
| Rol equivocado y prohibición contradictoria | el meta-prompt hardcodea "asesor comercial" y "NO hagas preguntas al usuario final" (`contact_trackings_controller.rb:479`) |
| 0 ramas, 0 fuentes, 0 tickets | el formato de salida que exige (`ROL / OBJETIVO / INFORMACIÓN A COMUNICAR / …`) no es el que parsea el motor |

El motor parsea otra cosa:

```
  ZONA 1   @ruta(nombre #etiqueta: descripción): fuente -> @crear_ticket(...)
           @ruta_por_defecto: <rama>
  ZONA 2   [ROL] [ALCANCE POR RAMA] [FIDELIDAD] [ETIQUETAS] [ESTILO] [PROHIBIDO]
```

### 1.2 El prototipo de tres estaciones funciona

Mismo pedido, circuito nuevo (inventario de Chatwoot → OpenAI → validador con
`RouteMap.parse` y `Directives.detect`):

```
@ruta(soporte_problema #soporte: Tengo un problema con el sistema, Necesito ayuda
con el software, El sistema no funciona correctamente): @soporte_contpaq(CONTPAQi)
-> @crear_ticket(tipo=Soporte, prioridad=Alta)
@ruta_por_defecto: soporte_problema

[ROL] … [ALCANCE POR RAMA] … [FIDELIDAD] … [ETIQUETAS] … [ESTILO] … [PROHIBIDO]
```

```
  → el motor lee 1 rama:
      soporte_problema | "#soporte" | @soporte_contpaq(CONTPAQi)
                       | @crear_ticket(tipo=Soporte, prioridad=Alta)
  → VALIDADOR: sin errores ✓          ~500 tokens · 4 s
```

`Soporte` salió de los tipos de caso reales de la cuenta; `CONTPAQi` de sus fuentes
reales. Ninguno se inventó.

### 1.3 El hallazgo que define el diseño

La primera corrida falló por **un carácter**:

```
  @ruta(soporte_ticket #soporte: …) @soporte_contpaq(CONTPAQi) -> @crear_ticket(…)
                                   ↑
                          falta el ":" que exige LINE_RE

  LINE_RE = /^[ \t]*@ruta\(…\)[ \t]*:[ \t]*(.*)$/i     ← route_map.rb:28
```

Resultado: 0 ramas, **sin error, sin log, sin señal**. El texto se ve impecable.

Y el bucle de corrección no lo arregló en 3 vueltas, porque el validador decía
*"no hay ninguna línea @ruta"*. El modelo mira su salida, ve `@ruta(` y concluye que
el validador está equivocado.

Con el mensaje reescrito como **diagnóstico** en vez de veredicto — misma salida mala
de partida, mismo contrato, 3 intentos cada uno:

```
  ┌────────────────────────────────────────────────────────────┬─────────┐
  │ "No hay ninguna línea @ruta"                               │  1 / 3  │
  │ "Línea 1: falta el ':' inmediatamente después del          │  3 / 3  │
  │  paréntesis de cierre. El patrón es @ruta(...): fuente"    │         │
  └────────────────────────────────────────────────────────────┴─────────┘
```

> **Conclusión que gobierna todo el diseño:** los mensajes de error del validador son
> parte del motor, no cosmética. Se diseñan con la misma seriedad que el parser.

### 1.4 Por qué el validador es el producto

El generador es commodity: cualquier modelo decente redacta prosa plausible. Lo que
ningún GPT externo puede hacer es correr el parser de producción y afirmar *"el motor
va a leer 1 rama, y es esta"*.

Y es gratis, porque `RouteMap.parse` y `Directives.detect` son **funciones puras sobre
un string** — sin base de datos, sin conversación, sin efectos:

```ruby
map = ContactTrackings::RouteMap.parse(texto)          # route_map.rb:52
map.routes.each { |r| KnowledgeBase::Directives.detect(r.directive) }  # directives.rb:49
```

Validar con el parser real, y no con una reimplementación, cambia el significado de
"válido": pasa de *"un modelo cree que está bien"* a **"el motor ya lo leyó"**.

---

## 2. Qué se construye

```
  ╔═══════════════════════════════════════════════════════════════════════╗
  ║  ASISTENTE DE AGENTES IA                                              ║
  ║  /app/accounts/:id/tracking-dashboard/assistant                       ║
  ╠═══════════════════════════════════════════════════════════════════════╣
  ║                                                                       ║
  ║   ENTREVISTA          →    ENTRENAMIENTO      →    VALIDACIÓN         ║
  ║   conversación             se escribe en           parser real,       ║
  ║   alimentada por           vivo a la derecha       en cada cambio     ║
  ║   el inventario                                                       ║
  ║                                                                       ║
  ║        ↓                        ↓                       ↓             ║
  ║   ┌─────────────────────────────────────────────────────────────┐    ║
  ║   │  GUARDAR EN EL AGENTE  ·  crea o actualiza tracking_template │    ║
  ║   └─────────────────────────────────────────────────────────────┘    ║
  ╚═══════════════════════════════════════════════════════════════════════╝
```

**Tres capacidades:**

| # | Capacidad | Fase |
|---|---|---|
| A | **Crear** un Entrenamiento nuevo por entrevista | F1–F4 |
| B | **Auditar** un Entrenamiento existente y decir qué no ejecuta | F5 |
| C | **Probar en seco** una pregunta contra el Entrenamiento sin tocar conversaciones | F6 |

---

## 3. Arquitectura: tres estaciones y un bucle

### 3.1 Por qué no una cascada

La cascada de `ContactTrackingResponseAnalyzerJob` es correcta para su problema. Para
este es al revés:

| | Motor (runtime) | Asistente (generador) |
|---|---|---|
| Quién lo usa | el cliente final | un admin de la cuenta |
| Cuántas veces corre | miles por día | una vez por agente, 30–45 min |
| Tolerancia a latencia | segundos | minutos |
| Qué cuesta un error | una respuesta mala | **un agente roto en producción** |
| Forma del control | una pasada, sin vuelta atrás | bucle: escribe → valida → corrige |

Optimizar tokens del generador es optimizar lo barato: corre una vez, el agente que
produce corre miles de veces.

### 3.2 El circuito

```
   ┌──────────────────────────────────────────────────────────────────┐
   │  ESTACIÓN 1 · INVENTARIO                       Ruby · 0 llamadas │
   │                                                                  │
   │   KnowledgeSource   → fuentes reales y su directiva exacta       │
   │   CaseType          → tipos válidos para @crear_ticket           │
   │   Label             → etiquetas que existen                      │
   │   CannedResponse    → prefijos de grupo disponibles              │
   │   Message(incoming) → cómo escriben los clientes, textual        │
   └────────────────────────────┬─────────────────────────────────────┘
                                │  hechos, no suposiciones
                                ▼
   ┌──────────────────────────────────────────────────────────────────┐
   │  ESTACIÓN 2 · ENTREVISTA + REDACCIÓN        1 sola conversación  │
   │                                                                  │
   │   system = CONTRATO FIJO  +  INVENTARIO GENERADO                 │
   │   turnos = preguntas acotadas (3–5), luego el Entrenamiento      │
   └────────────────────────────┬─────────────────────────────────────┘
                                │  Entrenamiento candidato
                                ▼
   ┌──────────────────────────────────────────────────────────────────┐
   │  ESTACIÓN 3 · VALIDADOR                        Ruby · 0 llamadas │
   │                                                                  │
   │   RouteMap.parse        ¿cuántas ramas lee el motor?             │
   │   Directives.detect     ¿la fuente existe y se reconoce?         │
   │   RouteMap.strip        ¿hay directiva suelta que blanquee todo? │
   │   CaseType / Label      ¿los nombres existen en la cuenta?       │
   └────────────┬─────────────────────────────────┬───────────────────┘
                │ sin errores                     │ con errores
                ▼                                 ▼
      ┌──────────────────┐          ┌──────────────────────────────────┐
      │ GUARDAR / MOSTRAR│          │ vuelve al MISMO hilo con el      │
      │ al usuario       │          │ mensaje DIAGNÓSTICO              │
      └──────────────────┘          │ máx. 3 vueltas → luego se le     │
                                    │ muestran los errores al usuario  │
                                    └──────────────────────────────────┘
```

### 3.3 Por qué no encadenar agentes

```
   CASCADA DE AGENTES                    ESTE DISEÑO
   ─────────────────────                 ────────────────────────────────

   🤖 entrevistador                      ⚙️  inventario        0 llamadas
         ↓ re-serializa contexto               ↓
   🤖 generador                          ┌─ 🤖 conversación única ─┐
         ↓ pierde el matiz               │  entrevista + redacta   │
   🤖 auditor                            └────────────┬────────────┘
         ↓ opina, no verifica                         ↓
   ⚙️  validador                          ⚙️  validador       0 llamadas
                                                      ↓
   4 saltos · 3 modelos                   ¿errores? → mismo hilo, máx 3
   el objetivo se distorsiona
   en cada hop
```

Cada salto **cuesta** contexto: vuelve a serializar todo y pierde el matiz de la
entrevista. Y el auditor-LLM es la pieza a **eliminar**, no a encadenar: un modelo
auditando sintaxis opina; un parser verifica.

---

## 4. Estación 1 · Inventario

Servicio nuevo: `ContactTrackings::Assistant::InventoryService`. Sin IA, sin escritura.

### 4.1 Qué lee

| Dato | Origen | Para qué en el Entrenamiento |
|---|---|---|
| Fuentes activas | `KnowledgeSource.where(account_id:)` | la directiva exacta de cada rama |
| Grupos de predefinidas | prefijo del `short_code` de `CannedResponse` | `@buscar_predefinidas(GRUPO)` |
| Tipos de caso | `CaseType.where(account_id:)` | `@crear_ticket(tipo=…)` |
| Etiquetas | `account.labels` | el `#etiqueta` de cada `@ruta` |
| Frases reales | últimos N `Message` entrantes | la `descripción` de cada rama |
| Feature ERP | `account.feature_enabled?('erp_connection')` | ofrecer o no `{{consulta:}}` |

### 4.2 La traducción fuente → directiva

Se genera desde `KnowledgeBase::Directives::SEARCH_DIRECTIVES` (`directives.rb:40`),
**no a mano**. Así, el día que se agregue una fuente al motor, el asistente la aprende
sola en vez de desincronizarse en silencio.

```
   source_type          directiva que se le dicta al modelo
   ─────────────────    ────────────────────────────────────
   canned_response  →   @buscar_predefinidas   (+ (GRUPO) si hay prefijos)
   article          →   @buscar_articulo
   discourse        →   @buscar_foro(<nombre exacto>)
   google_doc       →   {{doc:<nombre exacto>}}
   google_sheet     →   {{hoja:<nombre exacto>}}
   contpaq_support  →   @soporte_contpaq(<nombre exacto>)
```

### 4.3 Ejemplo real — cuenta 2, medido

```
  FUENTES        @buscar_predefinidas · @buscar_articulo
                 @buscar_foro(Foro Kontrolya) · @soporte_contpaq(CONTPAQi)
                 {{doc:trading_doc}} · {{hoja:Info Licencia}}
                 {{hoja:Precios de Articulos}} · {{hoja:facturas}}
  GRUPOS         DATOS(2) · HORARIO(1)
  TIPOS DE CASO  Implementación · Seguimiento interno · Incidente del sistema
                 Soporte · Administrativo · Comercial
  ETIQUETAS      demo · tracking
```

### 4.4 Por qué las frases reales, y no internet

La `descripción` de una `@ruta` es **lo único** que el clasificador usa para rutear un
mensaje. El contrato exige escribirla *"como lista de situaciones, en las palabras del
cliente"*.

```
   lo que escriben tus clientes          lo que daría una fuente genérica
   ─────────────────────────────         ─────────────────────────────────
   "voy actualiza a firebird 5           "Solicito asistencia técnica para
    kontrolya ya es comparble"            actualización de versión"
   "como puedo actualizar a la
    ultima version"
   "En CONTPAQi Nóminas, ¿cómo
    cancelo un recibo ya timbrado?"
```

Sin acentos, con typos, con jerga propia. Una descripción redactada desde material
genérico **clasifica peor**, y el fallo es invisible: el mensaje cae en la rama
equivocada sin que nadie lo note.

Además, material externo es combustible para inventar nombres — exactamente el modo de
falla que el inventario existe para eliminar.

> **Decisión: el asistente no busca en internet.** La búsqueda que necesita apunta
> hacia adentro: el inventario y las conversaciones de la cuenta.

---

## 5. Estación 2 · Entrevista y redacción

### 5.1 El meta-prompt son dos mitades

```
  ┌─ MITAD FIJA · el contrato del motor ───────────────────────────────┐
  │  · gramática @ruta, token por token                                │
  │  · las dos zonas y el orden de las secciones                       │
  │  · reglas duras: una fuente por rama; directiva suelta = blanqueo  │
  │  · qué NO se puede pedir (los límites del §12 del manual)          │
  │                                                                    │
  │  Se escribe UNA vez. Vive en Ruby, versionado JUNTO al parser.     │
  └────────────────────────────────────────────────────────────────────┘
  ┌─ MITAD GENERADA · en cada sesión, por Ruby ────────────────────────┐
  │  · catálogo de fuentes, desde SEARCH_DIRECTIVES                    │
  │  · nombres reales de esta cuenta                                   │
  │  · frases reales de sus clientes                                   │
  │                                                                    │
  │  NUNCA se escribe a mano. Se consulta.                             │
  └────────────────────────────────────────────────────────────────────┘
```

**Por qué la mitad fija vive junto al parser.** Si `LINE_RE` cambia y el meta-prompt
no, el asistente empieza a producir Entrenamientos inválidos sin que nadie se entere.
Un spec debe fallar si el contrato dictado y las constantes del motor divergen — el
mismo patrón que ya usa `engine_config_spec.rb` contra `apps.yml`.

### 5.2 Cómo se conduce la entrevista

No arranca con una pregunta en blanco. Arranca **ya habiendo leído** el inventario y
las frases reales, así que su primer turno es una propuesta:

```
  ┌────────────────────────────────────────────────────────────────────┐
  │ TURNO 0 (automático, antes de que el usuario escriba nada)         │
  │                                                                    │
  │ "Veo el foro Kontrolya, el Centro de Ayuda y soporte CONTPAQi      │
  │  conectados, y tipos de caso Soporte, Comercial y Administrativo.  │
  │  Tus clientes preguntan por actualizaciones de versión, timbrado   │
  │  de nómina y pólizas. ¿Qué querés que haga el agente?"             │
  └────────────────────────────────────────────────────────────────────┘
```

Y solo pregunta lo que **no puede deducir**. Del test salió cuál es la pregunta que
importa: el modelo eligió `@soporte_contpaq(CONTPAQi)` por su cuenta porque el pedido
no decía si el agente contesta o solo deriva.

**Las cuatro preguntas del guion** (tope: 5 turnos, luego redacta con lo que tenga):

```
   1 · ¿Qué temas atiende?          → cuántas ramas y sus descripciones
   2 · ¿Contesta o solo deriva?     → fuente + escalamiento, o fuente "-"
   3 · ¿Con qué etiqueta cierra?    → el #etiqueta de cada rama
   4 · ¿Qué tipo de caso abre?      → @crear_ticket(tipo=…)
```

Cada pregunta se ofrece con **opciones tomadas del inventario**, no abiertas. Si el
usuario responde "no sé", el asistente elige el default conservador y lo deja anotado.

### 5.3 Cold start

Cuenta nueva, sin fuentes ni conversaciones: el inventario está vacío y no hay de dónde
proponer. La salida **no** es buscar afuera, son los seis arquetipos del §9 del manual:

```
   informativo simple · soporte con foro y escalamiento · coordinador multi-rama
   bot cobrador (ERP) · agente de agenda · intake de datos
```

Y todo nombre que no pueda confirmar contra el inventario se deja como
`<PENDIENTE: …>`, nunca inventado.

---

## 6. Estación 3 · Validador

Servicio nuevo: `ContactTrackings::Assistant::ValidatorService`. Sin IA. Función pura
sobre un string, igual que los parsers que usa.

### 6.1 Las reglas, por severidad

**Bloqueantes** — si fallan, la funcionalidad no existe:

| # | Regla | Cómo se verifica |
|---|---|---|
| B1 | Hay al menos una `@ruta` que el motor lee | `RouteMap.parse(t).routes.any?` |
| B2 | Una línea que empieza con `@ruta(` y no parsea | `LINE_RE` no matchea → diagnóstico por carácter |
| B3 | Ninguna directiva de búsqueda suelta en la prosa | `RouteMap.strip` + patrones → **blanquea todo** (`job:545`) |
| B4 | La fuente de cada rama se reconoce | `Directives.detect(r.directive)` no es `nil` |
| B5 | La fuente nombrada existe en la cuenta | `source_name` contra el inventario |
| B6 | `@crear_ticket(tipo=…)` usa un tipo que existe | contra `CaseType` |
| B7 | `@ruta_por_defecto` apunta a una rama declarada | `map.names.include?(default)` |

**Degradan** — funciona, pero mal:

| # | Regla |
|---|---|
| D1 | Una rama sin `descripción`: el clasificador no puede elegirla |
| D2 | El `#etiqueta` no existe como Label en la cuenta → sugerir crearla |
| D3 | Dos fuentes en la misma rama: gana la primera del catálogo, la otra se ignora |
| D4 | `{{consulta:}}` conviviendo con `@ruta` o prosa → **se le envía el Entrenamiento entero al cliente** |
| D5 | Una rama con flecha y otras sin: las sin flecha dejan de abrir casos |
| D6 | `{{nombre}}` de adjunto en una rama CON fuente: sale como texto literal |

**Cosméticas** — mejoran, no rompen:

| # | Regla |
|---|---|
| C1 | Falta alguna de las 6 secciones de la ZONA 2 |
| C2 | La descripción está en lenguaje de manual, no del cliente |
| C3 | No hay regla de fidelidad y la fuente usa umbral 0.20 |

### 6.2 Anatomía de un mensaje de error

Medido: la redacción cambia la tasa de reparación de **1/3 a 3/3**. Un mensaje válido
tiene cuatro partes:

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │  DÓNDE      "Línea 1:"                                               │
  │  QUÉ PASA   "el motor NO la reconoce como rama"                      │
  │  POR QUÉ    "falta el ':' inmediatamente después del paréntesis      │
  │              de cierre"                                              │
  │  QUÉ SE     "Escribiste: @ruta(soporte_ticket #soporte: …) @sopo…"   │
  │  ESCRIBIÓ                                                            │
  └──────────────────────────────────────────────────────────────────────┘
```

Prohibido el veredicto pelado (*"no hay ninguna línea @ruta"*): el modelo ve `@ruta(`
en su propia salida y concluye que el validador se equivoca.

### 6.3 El bucle de corrección

```
        redacta
           │
           ▼
     ┌───────────┐   sin errores    ┌──────────────────┐
     │ VALIDADOR ├─────────────────▶│ listo para el UI │
     └─────┬─────┘                  └──────────────────┘
           │ con errores
           ▼
     vuelta ≤ 3 ?  ──── no ───▶  se muestran al usuario, con el
           │                      Entrenamiento parcial y el botón
          sí                      "corregir a mano"
           │
           ▼
     mismo hilo + mensaje diagnóstico
```

Tope duro de 3 vueltas. Sin tope, un contrato mal escrito quema tokens en bucle.

---

## 7. El frontend

Todo con componentes nativos del dashboard. Sin réplicas a medida.

### 7.1 Dónde entra en el menú

`/tracking-dashboard` cuelga de `parentNav: 'campaigns'`. Se agrega una opción:

```
   Campañas
    ├── Seguimientos            → /tracking-dashboard
    ├── Campañas Agentes IA     → /tracking-dashboard/campaigns
    ├── Agentes IA              → /tracking-dashboard/agents
    ├── ▸ Asistente             → /tracking-dashboard/assistant     ◀ NUEVO
    ├── En curso / Únicas       → /campaigns/…
    └── Resumen                 → /tracking-dashboard/metrics
```

Tres cambios chicos: una ruta en `contactTrackings/routes.js`, un `menuItem` en
`sidebarItems/campaigns.js` (icono `wand`), y la clave `TRACKING_ASSISTANT` en
`settings.json` (es/en).

### 7.2 Pantalla principal — dos paneles

```
  ┌────────────────────────────────────────────────────────────────────────────┐
  │  Asistente de Agentes IA                        [ Nuevo ]  [ Auditar ▾ ]   │
  ├──────────────────────────────────┬─────────────────────────────────────────┤
  │                                  │                                         │
  │  CONVERSACIÓN                    │  ENTRENAMIENTO                          │
  │                                  │                          ┌────────────┐ │
  │  ┌────────────────────────────┐  │  @ruta(soporte #soporte: │ 1 rama  ✓  │ │
  │  │ Veo el foro Kontrolya, el  │  │  no puedo entrar, error, └────────────┘ │
  │  │ Centro de Ayuda y soporte  │  │  no abre el sistema):                   │
  │  │ CONTPAQi conectados, y     │  │  @buscar_foro(Foro Kontrolya)           │
  │  │ tipos de caso Soporte,     │  │  -> @crear_ticket(tipo=Soporte,         │
  │  │ Comercial, Administrativo. │  │     prioridad=media)                    │
  │  │                            │  │  @ruta_por_defecto: soporte             │
  │  │ ¿Qué querés que haga el    │  │                                         │
  │  │ agente?                    │  │  [ROL]                                  │
  │  └────────────────────────────┘  │  Sos el agente de soporte de Kontrolya… │
  │                                  │                                         │
  │           ┌───────────────────┐  │  [ALCANCE POR RAMA]                     │
  │           │ que junte datos y │  │  En soporte: contestás con el foro y    │
  │           │ abra un ticket de │  │  si no alcanza, abrís el caso…          │
  │           │ soporte           │  │                                         │
  │           └───────────────────┘  │  [FIDELIDAD] …                          │
  │                                  │  [ETIQUETAS] …                          │
  │  ┌────────────────────────────┐  │  [ESTILO] …                             │
  │  │ Una cosa más: ¿contesta    │  │  [PROHIBIDO] …                          │
  │  │ primero y abre el ticket   │  │                                         │
  │  │ solo si no pudo resolver,  │  ├─────────────────────────────────────────┤
  │  │ o siempre recauda datos y  │  │  LO QUE EL MOTOR VA A LEER              │
  │  │ abre el ticket?            │  │                                         │
  │  │                            │  │  ● soporte      #soporte                │
  │  │  [ Contesta primero ]      │  │    fuente:  @buscar_foro(Foro Kontrolya)│
  │  │  [ Solo recauda ]          │  │    escala:  @crear_ticket(tipo=Soporte) │
  │  └────────────────────────────┘  │                                         │
  │                                  │  por defecto: soporte                   │
  │  ┌────────────────────────────┐  │                                         │
  │  │ Escribí acá…          [ ↵ ]│  │  ✓ 7 comprobaciones sin errores         │
  │  └────────────────────────────┘  │                                         │
  ├──────────────────────────────────┴─────────────────────────────────────────┤
  │                          [ Probar en seco ]   [ Guardar en el agente → ]   │
  └────────────────────────────────────────────────────────────────────────────┘
```

**Lo que hace distinta a esta pantalla:** el panel inferior derecho no dice "parece
correcto". Dice **lo que el parser de producción efectivamente leyó**. Si dice
`0 ramas`, el agente no ejecuta nada — y se ve antes de guardar, no en producción.

### 7.3 Estado con errores

```
  ├─────────────────────────────────────────┤
  │  LO QUE EL MOTOR VA A LEER              │
  │                                         │
  │        ⚠  0 ramas                       │
  │                                         │
  │  ✗ Línea 1: el motor NO la reconoce     │
  │    como rama — falta el ":" inmedia-    │
  │    tamente después del paréntesis de    │
  │    cierre.                              │
  │                                         │
  │    Escribiste:                          │
  │    @ruta(soporte #soporte: …) @buscar…  │
  │                              ▲          │
  │                        acá falta ":"    │
  │                                         │
  │    [ Corregir automáticamente ]         │
  │                                         │
  │  ✗ @ruta_por_defecto apunta a           │
  │    'soporte_ticket', que no es una      │
  │    rama declarada.                      │
  └─────────────────────────────────────────┘
```

El botón **Guardar** queda deshabilitado mientras haya un bloqueante. Las degradantes
avisan en ámbar pero dejan guardar.

### 7.4 Guardar — modal

```
  ┌──────────────────────────────────────────────────┐
  │  Guardar Entrenamiento                       [×] │
  ├──────────────────────────────────────────────────┤
  │  ○ Crear un Agente IA nuevo                      │
  │      Nombre    [ Soporte Kontrolya            ]  │
  │      Objetivo  [ Resolver dudas y abrir casos ]  │
  │      Bandeja   [ Kontrolya WhatsApp        ▾ ]   │
  │                                                  │
  │  ○ Reemplazar el Entrenamiento de uno existente  │
  │      Agente    [ …                          ▾ ]  │
  │      ⚠ Se guarda una copia del anterior          │
  │                                                  │
  │                      [ Cancelar ]  [ Guardar ]   │
  └──────────────────────────────────────────────────┘
```

Al guardar, redirige a `/tracking-dashboard/agents` con el agente abierto.

### 7.5 Modo auditar (F5)

Misma pantalla, entrada distinta: se elige un agente existente y el panel derecho se
llena con su Entrenamiento actual, ya validado.

```
  ┌────────────────────────────────────────────────────────────────────┐
  │  Auditar un Agente IA                                              │
  ├────────────────────────────────────────────────────────────────────┤
  │  Agente  [ V2.0 — SOPORTE, COMERCIAL Y ADMINISTRATIVO      ▾ ]     │
  ├────────────────────────────────────────────────────────────────────┤
  │  ⚠  El motor lee 0 ramas en este agente.                           │
  │                                                                    │
  │  El nombre anuncia tres temas, pero no hay ninguna línea @ruta:    │
  │  todos los mensajes van a caer al camino conversacional y ninguna  │
  │  fuente se va a consultar.                                         │
  │                                                                    │
  │              [ Arreglarlo con el asistente → ]                     │
  └────────────────────────────────────────────────────────────────────┘
```

### 7.6 Probar en seco (F6)

```
  ┌────────────────────────────────────────────────────────────────────┐
  │  Probar sin enviar nada                                            │
  │  Escribí una pregunta como la haría un cliente.                    │
  ├────────────────────────────────────────────────────────────────────┤
  │  Pregunta  [ necesito los datos para hacer una transferencia  ]    │
  │                                                    [ Probar ]      │
  ├────────────────────────────────────────────────────────────────────┤
  │  Tema elegido       administrativo — facturas, datos fiscales      │
  │  Fuente consultada  @buscar_predefinidas(DATOS)                    │
  │  1 fragmento, con similitud mínima 0.45:                           │
  │     DATOS BANCARIOS O TRANSFERENCIA              55%               │
  │     Para transferencias, la cuenta es…                             │
  │  Cierra con la etiqueta   #admin                                   │
  │  ¿Abre caso?              sí, antes de consultar la fuente         │
  │  ⚠ Este tema no declara su propio escalamiento, así que hereda     │
  │    el @crear_ticket suelto del Entrenamiento — y encima se         │
  │    adelanta a la fuente.                                           │
  │                                                                    │
  │  El tema lo clasificó gpt-4o-mini. No se envió ningún mensaje.     │
  └────────────────────────────────────────────────────────────────────┘
```

Va **abajo del comprobador, en la misma pestaña**, y no en un modal como se dibujaba
antes: lo que se hace con esto es leer el resultado, corregir el Entrenamiento que
está arriba y volver a probar. Un modal tapa justo el texto que hay que corregir.

**Ya no depende de `kbase_directivas_api_plan.md`**: esa rama se mergeó a develop
(PR #50) y dejó `KnowledgeBase::DirectiveRunner`. Igual F6 no lo usa como ejecutor
—ver abajo— pero el bloqueo se levantó.

#### Dos recortes deliberados respecto de este dibujo

**1. No redacta la respuesta final.** Redactarla de verdad exige el prompt completo
del agente, el objetivo, la regla de rama y el historial de la conversación, que
ensambla `KnowledgeBaseResponseService#generate_contextual_reply` — atado a una
conversación real que acá no existe. Una respuesta armada por un SEGUNDO camino se
vería igual de autoritaria y diría otra cosa que el agente en vivo; este módulo
existe para que se vea lo que el motor hace de verdad. Lo que sí decide si la
respuesta puede llegar a ser correcta son los FRAGMENTOS: si vuelven los
equivocados, no hay redacción que lo salve. Eso sí se muestra, con su similitud.

**2. Las fuentes en vivo no se ejecutan.** Se corren de verdad las que buscan en
pgvector local (respuestas predefinidas, artículos, Google Doc y Hoja en modo FAQ).
Las que consultan un servicio externo —foro Discourse, Contpaq, Hoja en modo Datos,
`{{consulta:}}` al ERP— se nombran y se saltean; el resto del informe (tema,
etiqueta, caso) sale igual, que es la parte que el comprobador no podía dar. Un modo
nuevo que nadie clasifique rompe un spec, en vez de aparecer como "no se puede
probar" sin que nadie lo haya decidido.

#### Por qué no reusa `KnowledgeBase::DirectiveRunner`

Ese servicio ignora el grupo de `@buscar_predefinidas(GRUPO)` — su endpoint incluso
rechaza la directiva con paréntesis a propósito. Medido sobre la cuenta 2: con
`@buscar_predefinidas(DATOS)`, la pregunta "cuál es el horario" devuelve **vacío**
(grupo estrecho, umbral 0.45), que es lo que hace el motor. Con el Runner habría
mostrado *HORARIO DE OFICINA* al 54% y parecido correcta. Por eso la búsqueda usa
`KnowledgeBase::CannedGroup`, y un spec la corre contra el método privado real del
motor para que las dos copias no se separen en silencio.

---

## 8. Modelo de datos

### 8.1 Una tabla nueva

```
   assistant_sessions
   ├── id
   ├── account_id          FK, index
   ├── user_id             FK — quién la abrió
   ├── tracking_template_id FK, nullable — si terminó guardando
   ├── mode                enum: create | audit
   ├── messages            jsonb — los turnos de la entrevista
   ├── draft               text  — el último Entrenamiento candidato
   ├── validation          jsonb — último resultado del validador
   ├── status              enum: open | saved | discarded
   └── timestamps
```

**Por qué persistir.** La entrevista dura 30–45 min y el usuario cierra la pestaña. Sin
persistencia, pierde todo. `messages` como `jsonb` evita una segunda tabla para algo
que siempre se lee entero.

**Retención:** sesiones `open` sin actividad se purgan a los 30 días. `saved` quedan
como historial de cómo se llegó a ese Entrenamiento.

### 8.2 Lo que NO se persiste

| Cosa | Por qué |
|---|---|
| El inventario | se recalcula en cada request; cachearlo lo desincroniza de la cuenta |
| La mitad fija del meta-prompt | es código |
| Las frases de clientes citadas | se leen al vuelo; no se copian a otra tabla |

### 8.3 Versionado del Entrenamiento

Al reemplazar el Entrenamiento de un agente existente se guarda el anterior. Reutilizar
lo que ya exista para versionar `tracking_templates`; si no hay nada, una columna
`previous_complementary_prompt` alcanza para F4 y evita una tabla nueva.

---

## 9. API

Namespace nuevo: `Api::V1::Accounts::Assistant::*`. Permiso: `administrator`.

```
  POST   /api/v1/accounts/:id/assistant/sessions
         → crea la sesión y devuelve el TURNO 0 (propuesta desde el inventario)

  POST   /api/v1/accounts/:id/assistant/sessions/:sid/messages
         { content }
         → un turno de entrevista; devuelve respuesta + draft + validación

  POST   /api/v1/accounts/:id/assistant/validate
         { draft }
         → SOLO el validador, sin IA. Corre en cada edición manual del panel derecho.
           Barato, instantáneo, sin costo de tokens.

  GET    /api/v1/accounts/:id/assistant/inventory
         → el inventario, para pintar los selectores del UI

  POST   /api/v1/accounts/:id/assistant/sessions/:sid/save
         { mode: create|replace, template_id?, name?, objective?, inbox_id? }
         → crea o actualiza el tracking_template

  POST   /api/v1/accounts/:id/contact_trackings/assistant/dry_run   (F6)
         { draft, question }
         → rama elegida, fuente, fragmentos, respuesta — sin tocar conversaciones
```

**`/validate` separado de `/messages` es deliberado.** El panel derecho es editable a
mano; cada tecleo revalida. Si validar exigiera pasar por el modelo, editar sería lento
y caro. Como el validador es una función pura, es gratis.

---

## 10. Modelo de IA y costo

### 10.1 El modelo

`EngineConfig.model_for(inbox, purpose)` ya recibe un `purpose` que hoy no diferencia
nada, y su comentario dice que existe *"para que una política futura tenga dónde vivir
sin tocar los llamadores"*. Este es ese caso.

**Dos problemas a resolver ahí:**

1. El asistente **no tiene inbox** — es de cuenta. `model_for(nil, …)` cae a
   `DEFAULT_MODEL = 'gpt-4o-mini'`.
2. `gpt-4o-mini` ya está medido como insuficiente para cumplir reglas de prompt.

**Propuesta:** un piso por propósito. `purpose: :authoring_assistant` nunca resuelve
por debajo de `gpt-4o`, aunque el inbox tenga otro configurado.

```ruby
FLOOR = { authoring_assistant: 'gpt-4o' }.freeze
```

Y agregar `assistant:` a `MAX_TOKENS` — 250 (el tope de `authoring`) no alcanza para un
Entrenamiento completo; el prototipo usó 2000.

### 10.2 Costo medido

| Concepto | Medido |
|---|---|
| Una generación completa | ~500 tokens · 4 s |
| Sesión con entrevista de 4–5 turnos | ~3.000–5.000 tokens |
| Vuelta de corrección | ~300 tokens extra |
| Inventario | 0 tokens |
| Validación | 0 tokens |

Costo irrelevante frente a lo que cuesta un agente roto en producción. **No se
optimiza el generador.**

---

## 11. Fases

```
  F0 ██                Andamiaje: ruta, menú, i18n, pantalla vacía
  F1 ████              Inventario (Ruby, sin IA) + endpoint
  F2 ██████            Validador + mensajes diagnósticos + specs
  F3 ██████            Meta-prompt, entrevista, bucle de corrección
  F4 ██████            Frontend completo + guardar en el agente
  F5 ████              Modo auditar
  F6 ████              Probar en seco  ✔ hecho
  F7 ██                Retirar el generador viejo
     └──┬──┘└──┬──┘└──┬──┘
      sem 1   sem 2   sem 3+
```

| Fase | Qué entrega | Días hábiles | Fechas |
|---|---|---|---|
| **F0** | Ruta `/assistant`, entrada en el menú, i18n es/en, vista vacía | 1 | mar 08/09 |
| **F1** | `InventoryService` + `GET /inventory`; catálogo generado desde `SEARCH_DIRECTIVES` | 2 | mié 09/09 – jue 10/09 |
| **F2** | `ValidatorService` con B1–B7 y D1–D6, mensajes diagnósticos, specs de cada regla | 3 | vie 11/09 – mar 15/09 |
| **F3** | Meta-prompt en dos mitades, entrevista de 4 preguntas, bucle con tope 3, spec de sincronía contrato↔parser | 3 | mié 16/09 – vie 18/09 |
| **F4** | Los dos paneles, validación en vivo, modal de guardado, `assistant_sessions` | 3 | lun 21/09 – mié 23/09 |
| **F5** | Modo auditar sobre agentes existentes | 2 | jue 24/09 – vie 25/09 |
| **F6** | Probar en seco *(condicionada)* | 2 | lun 28/09 – mar 29/09 |
| **F7** | El botón de `EditTemplate.vue` apunta al motor nuevo | 1 | mié 30/09 |

**Primer entregable demostrable: F2.** Con el validador solo, sin nada de IA, ya se
puede pasar cualquier Entrenamiento existente y decir cuántas ramas lee el motor. Es la
mitad del valor y no depende de OpenAI.

**F6 estaba condicionada** a que existiera el núcleo extraíble de
`kbase_directivas_api_plan.md`; esa rama se mergeó a develop (PR #50) y el bloqueo se
levantó. El texto original decía: si esa rama no avanzó, F6 se corre y el resto no se
bloquea.

---

## 12. Archivos que toca

### Backend — nuevos

```
  app/services/contact_trackings/assistant/inventory_service.rb
  app/services/contact_trackings/assistant/validator_service.rb
  app/services/contact_trackings/assistant/contract.rb         ← la mitad fija
  app/services/contact_trackings/assistant/interview_service.rb
  app/models/assistant_session.rb
  app/controllers/api/v1/accounts/assistant/sessions_controller.rb
  app/controllers/api/v1/accounts/assistant/validations_controller.rb
  db/migrate/…_create_assistant_sessions.rb
```

### Backend — modificados

```
  app/services/contact_trackings/engine_config.rb   piso de modelo + MAX_TOKENS[:assistant]
  config/routes.rb                                   namespace assistant
```

### Backend — leídos, NO modificados

```
  app/services/contact_trackings/route_map.rb        LINE_RE · parse · strip
  app/services/knowledge_base/directives.rb          SEARCH_DIRECTIVES · detect
  app/services/cases/ticket_creator_service.rb       DIRECTIVE_RE
```

> Esto es deliberado: el validador **reusa** el parser de producción. Si se
> reimplementa, los dos se desincronizan y volvemos a adivinar.

### Frontend — nuevos

```
  app/javascript/dashboard/views/contactTrackings/Assistant.vue
  app/javascript/dashboard/views/contactTrackings/assistant/InterviewPanel.vue
  app/javascript/dashboard/views/contactTrackings/assistant/DraftPanel.vue
  app/javascript/dashboard/views/contactTrackings/assistant/ValidationReport.vue
  app/javascript/dashboard/views/contactTrackings/assistant/SaveModal.vue
  app/javascript/dashboard/api/assistant.js
  app/javascript/dashboard/store/modules/assistant.js
```

### Frontend — modificados

```
  routes/dashboard/contactTrackings/routes.js              +1 ruta
  components/layout/config/sidebarItems/campaigns.js       +1 menuItem
  i18n/locale/{es,en}/settings.json                        TRACKING_ASSISTANT
  i18n/locale/{es,en}/trackingAssistant.json               (nuevo)
  routes/dashboard/settings/trackingTemplates/EditTemplate.vue   F7, con --no-verify
```

> `EditTemplate.vue` arrastra 167 hallazgos de eslint previos y no pasa su propio hook.
> Commitear con `--no-verify` y **nunca** con `--fix`.

### Specs

```
  spec/services/contact_trackings/assistant/validator_service_spec.rb
      una prueba por regla B1–B7 y D1–D6, con el texto exacto que la dispara
  spec/services/contact_trackings/assistant/contract_spec.rb
      falla si el contrato dictado y las constantes del motor divergen
  spec/services/contact_trackings/assistant/inventory_service_spec.rb
```

> RSpec corre contra `chatwoot_dev`; el `EnvironmentMismatchError` es ruido esperado.
> Y los workflows de CI piden un runner `self-hosted` que no existe: ningún check va a
> correr solo, hay que correr los specs a mano.

---

## 13. Riesgos y decisiones pendientes

### 13.1 Riesgos

| Riesgo | Mitigación |
|---|---|
| **El contrato se desincroniza del parser** — se cambia `LINE_RE` y el asistente sigue dictando la gramática vieja | spec que compara el contrato contra las constantes reales; el mismo patrón de `engine_config_spec.rb` |
| **El validador se vuelve una reimplementación** — alguien copia las regex "para no acoplar" | está escrito en el plan: se importan `RouteMap` y `Directives`, no se copian |
| **Un Entrenamiento válido pero equivocado** — parsea, pero rutea mal | el validador no lo detecta; para eso está F6 (probar en seco) y la prueba con preguntas reales |
| **La entrevista se vuelve un chat abierto** — 20 turnos y el usuario se aburre | tope duro de 5 turnos; después redacta con lo que tenga y marca `<PENDIENTE>` |
| **Sobreescribir un agente en producción** | el modal exige elegir explícitamente "reemplazar"; se guarda el anterior |

### 13.2 Decisiones pendientes

| # | Decisión | Opciones |
|---|---|---|
| 1 | **Frases reales de clientes en el prompt** | ¿cuántos mensajes? ¿de toda la cuenta o del inbox elegido? ¿se anonimizan? Van a OpenAI: hay que decidirlo a conciencia |
| 2 | **Qué pasa con el botón viejo (F7)** | apuntarlo al motor nuevo (recomendado) · dejarlo · sacarlo y enlazar al asistente |
| 3 | **Permisos** | ¿solo `administrator`, o también `agent`? Hoy `/tracking-dashboard` deja entrar a ambos |
| 4 | **Versionado del Entrenamiento** | columna `previous_complementary_prompt` (simple) vs. tabla de versiones (completo) |
| 5 | **El asistente en inglés** | el contrato y la entrevista están pensados en español; ¿se traduce o queda ES? |

---

## 14. Lo que NO entra

| Fuera de alcance | Por qué |
|---|---|
| **Búsqueda en internet** | trae lenguaje genérico que clasifica peor y alimenta la invención de nombres; la búsqueda útil apunta a la cuenta |
| **Tool calling nativo en el motor** | es otro proyecto: cambia el runtime, no el generador |
| **Encender el router de intenciones** | `TRACKING_DETECT_INTENT=false` sigue como está |
| **Levantar los límites del §12** | el asistente enseña a trabajar dentro de ellos, no los cambia |
| **Auditar agentes de otras cuentas** | todo va contra `Current.account` |
| **Generar Respuestas predefinidas o artículos** | el asistente escribe el Entrenamiento, no el corpus |

---

## Anexo · Glosario

| Término | Qué es |
|---|---|
| **Entrenamiento** | el campo `complementary_prompt` del Agente IA |
| **Contrato** | la mitad fija del meta-prompt: la gramática que el motor parsea |
| **Inventario** | los nombres reales de la cuenta, leídos por Ruby en cada sesión |
| **Draft** | el Entrenamiento candidato, todavía sin guardar |
| **Diagnóstico** | mensaje de error que dice dónde, qué, por qué y qué se escribió |
| **Probar en seco** | correr una pregunta contra el Entrenamiento sin tocar ninguna conversación |
