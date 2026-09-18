# Catálogo de Recetas de Agentes IA

**Una biblioteca de Entrenamientos publicada por una cuenta proveedora, que cualquier
cuenta puede revisar e importar — adaptándola a lo que ella tiene, no copiándola**

| | |
|---|---|
| **Rama de trabajo** | por crear, sale de `feat/motor_agentes_ia` |
| **Estado** | solo plan — no hay código escrito |
| **Depende de** | el Asistente de Agentes IA (F0–F7, ya implementado) |
| **Ubicación en la app** | `/app/accounts/:id/tracking-dashboard/assistant` · pestaña nueva |
| **Fecha** | 10/09/2026 |
| **Documento base** | `asistente_agentes_ia_plan.md` |

---

## Índice

| # | Sección | Para qué |
|---|---|---|
| 1 | [El problema, medido](#1-el-problema-medido) | por qué hace falta y qué NO se puede afirmar |
| 2 | [Qué se construye](#2-qué-se-construye) | el alcance en una imagen |
| 3 | [La decisión central: recetas, no copias](#3-la-decisión-central-recetas-no-copias) | lo que hace viable el catálogo |
| 4 | [Publicar](#4-publicar) | quién, cómo y con qué condiciones |
| 5 | [Importar](#5-importar) | el circuito completo, paso a paso |
| 6 | [Frescura: revalidar al mostrar](#6-frescura-revalidar-al-mostrar) | por qué el catálogo no envejece en silencio |
| 7 | [El frontend](#7-el-frontend) | pantallas |
| 8 | [Modelo de datos](#8-modelo-de-datos) | una tabla |
| 9 | [API](#9-api) | endpoints |
| 10 | [Fases](#10-fases) | roadmap |
| 11 | [Riesgos y lo que no resuelve](#11-riesgos-y-lo-que-no-resuelve) | lo que queda afuera a conciencia |

---

## 1. El problema, medido

Todo lo de esta sección se midió el 10/09/2026 contra la base real. No son estimaciones.

### 1.1 Cada cuenta arma sus agentes desde cero

```
  Cuenta 2 — 29 Agentes IA
  ┌────────────────────┬────┬──────────────────────────────────────────┐
  │ con temas (routed) │  8 │ el motor lee sus @ruta y consulta fuentes │
  │ conversacional     │ 11 │ sin ramas: contesta solo con el modelo    │
  │ no ejecuta (roto)  │  9 │ tiene defectos bloqueantes                │
  │ sin Entrenamiento  │  1 │ inerte                                    │
  └────────────────────┴────┴──────────────────────────────────────────┘
```

Nueve de veintinueve no ejecutan lo que su nombre promete. No porque falte capacidad,
sino porque **cada quien descubre solo la gramática del motor**, incluido el `:` que
falta después del paréntesis — la falla que abrió el módulo del Asistente.

### 1.2 Lo que NO se puede afirmar hoy, y por qué importa

La idea original era marcar "los prompts que sí funcionan". Los datos dicen que hoy eso
no se puede saber:

```
   7 seguimientos EN TOTAL en la cuenta            todos con outcome = nil
   4 agentes usados alguna vez, de 29
   El motor NO registra qué rama eligió en cada turno   ← lo decisivo
```

`ContactTracking` guarda `status`, `last_intent` y `outcome`; **no guarda la rama**. Sin
eso, "funciona" solo puede significar "se lee bien" — y ese es exactamente el error que
este módulo vino a eliminar: el generador viejo producía texto impecable que ejecutaba
cero.

> **Por eso el catálogo NO afirma que sus recetas funcionan en producción.** Afirma algo
> más chico y verificable: *son ejemplos correctos, ejecutables, curados por el
> proveedor*. La diferencia no es retórica — decide qué se le promete a quien importa.

### 1.3 Un Entrenamiento sano NO es portable

El hallazgo que define todo el diseño. Se tomó un agente **con 0 defectos** de la cuenta
2 y se lo validó contra la cuenta 1:

```
  «DEMO — Soporte CONTPAQi (API remota)» · 2 temas · 0 defectos en su cuenta
                              ↓ validado contra la cuenta 1
  ¿se puede guardar?  NO
  ✗ source_not_found   la fuente "CONTPAQi" no existe en esta cuenta
  ⚠ label_not_found ×2

  Cuenta 2:  9 fuentes · 7 tipos de caso · 2 etiquetas
  Cuenta 1:  2 fuentes · 0 tipos de caso · 0 etiquetas
```

Que falle ruidoso está bien: es el comprobador haciendo su trabajo. Pero significa que
**copiar y pegar no es una opción**, y de ahí sale la sección 3.

---

## 2. Qué se construye

```
  ╔═══════════════════════════════════════════════════════════════════════╗
  ║  CATÁLOGO DE RECETAS                                                  ║
  ╠═══════════════════════════════════════════════════════════════════════╣
  ║                                                                       ║
  ║   CUENTA PROVEEDORA              │   CUALQUIER CUENTA                 ║
  ║   (con el flag)                  │                                    ║
  ║                                  │                                    ║
  ║   publica una receta:            │   ve el catálogo, revalidado       ║
  ║   · el Entrenamiento             │   contra SU propia cuenta          ║
  ║   · qué requiere                 │            ↓                       ║
  ║   · para qué sirve               │   importa → el Asistente adapta    ║
  ║                                  │            ↓                       ║
  ║        ── una tabla compartida ──┤   prueba en seco                   ║
  ║                                  │            ↓                       ║
  ║                                  │   guarda con el flujo de siempre   ║
  ╚═══════════════════════════════════════════════════════════════════════╝
```

**Todas las cuentas viven en la misma instancia y la misma base**, así que no hace falta
API entre instalaciones: una tabla, lectura para todos, escritura para la proveedora.

---

## 3. La decisión central: recetas, no copias

Una receta **no trae nombres ajenos**: declara qué necesita, y el destino lo resuelve
con lo que tiene.

```
  ┌─ RECETA ─────────────────────────────────────────────────────────────┐
  │  Soporte con foro y escalamiento por rama                            │
  │                                                                      │
  │  "El cliente reporta una falla; se busca en el foro y si no          │
  │   resuelve, se abre un caso."                                        │
  ├─ ENTRENAMIENTO ──────────────────────────────────────────────────────┤
  │  @ruta(soporte #‹ETIQUETA›: no puedo entrar, me da error,            │
  │        no abre el sistema): @buscar_foro(‹FUENTE_FORO›)              │
  │        -> @crear_ticket(tipo=‹TIPO_SOPORTE›)                         │
  │  @ruta_por_defecto: soporte                                          │
  │                                                                      │
  │  [ROL] … [ESTILO] … [FIDELIDAD] … [ETIQUETAS] … [PROHIBIDO] …        │
  ├─ REQUIERE ───────────────────────────────────────────────────────────┤
  │  ‹FUENTE_FORO›     una fuente de foro                                │
  │  ‹TIPO_SOPORTE›    un tipo de caso                                   │
  │  ‹ETIQUETA›        una etiqueta de cierre                            │
  └──────────────────────────────────────────────────────────────────────┘
```

### 3.1 Por qué esto es barato: ya está casi todo

El catálogo **no construye maquinaria nueva**. Se apoya entero en piezas que el
Asistente ya tiene:

| Pieza que ya existe | Qué aporta al catálogo |
|---|---|
| `Assistant::InventoryService` | qué fuentes, tipos y etiquetas tiene la cuenta destino |
| `Assistant::ValidatorService` | si la receta quedó ejecutable **en destino** |
| `Assistant::Contract` | ya sabe dejar `<PENDIENTE: …>` cuando falta un dato |
| `Assistant::DryRunService` (F6) | probar sin enviar nada, antes de guardar |
| `Assistant::SaveService` | guardar con su comprobación y su copia de respaldo |
| `config/features.yml` | marcar la cuenta proveedora, como `google_calendar` |

### 3.2 Por qué NO son embeddings

Se evaluó y se descartó, con razones:

```
  ESCALA          19 recetas candidatas, no 19.000. Los embeddings resuelven
                  la aguja en el pajar; acá entran TODAS en el prompt o se
                  filtran con un WHERE.

  UNIDAD          un Entrenamiento va de 46 a 645 líneas (medido). Vectorizarlo
                  entero da el promedio de todo, que no significa nada;
                  trocearlo destruye la estructura, que es lo valioso.

  NATURALEZA      lo que hace buena a una receta es ESTRUCTURAL —cuántos temas,
                  si la fuente existe, si escala por rama— y eso ya se mide con
                  el comprobador. Es una consulta, no un parecido.
```

**Dónde sí servirían, más adelante:** emparejar por el *objetivo* del agente
("soporte técnico de software contable" ≈ "ayuda con sistema de nómina"). Eso es un
párrafo corto y sí es buena unidad de embedding. Fase 2, no fase 1.

---

## 4. Publicar

### 4.1 Quién

Una sola cuenta, marcada con un **feature flag por cuenta** — el mecanismo nativo de
Chatwoot, el mismo con el que se gatean `google_calendar` y `erp_connection` (hay 60
flags en `config/features.yml`):

```ruby
account.feature_enabled?('assistant_catalog_publisher')
```

Sin el flag no se ve la pantalla de publicar ni existen sus endpoints. Todas las cuentas
leen el catálogo; una sola escribe.

### 4.2 Tres condiciones para publicar

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │ 1  DECLARA SUS REQUISITOS                                            │
  │    Cada ‹PLACEHOLDER› del texto tiene que estar declarado, con su    │
  │    tipo. Sin esto, quien importa recibe algo que no puede ejecutar.  │
  ├──────────────────────────────────────────────────────────────────────┤
  │ 2  ES EJECUTABLE "DESDE CERO"                                        │
  │    Con los placeholders resueltos, la receta pasa el comprobador.    │
  │    Es la misma regla de siempre: que el motor diga que sí ANTES de   │
  │    que alguien lo sufra.                                             │
  ├──────────────────────────────────────────────────────────────────────┤
  │ 3  NO LLEVA AFIRMACIONES DE NEGOCIO                                  │
  │    La prosa de una receta termina en un agente que le habla a los    │
  │    clientes finales de OTRA empresa. Un plazo, una política o un     │
  │    precio se los va a decir como ciertos.                            │
  │    Mismo principio que ya rige `ai_context` en el modal de guardado, │
  │    salvo que acá el daño cruza de una empresa a otra.                │
  └──────────────────────────────────────────────────────────────────────┘
```

La condición 2 se comprueba con código: `ValidatorService` sobre el texto con los
placeholders sustituidos por valores de ejemplo. La 3 es editorial y va escrita en la
pantalla de publicar, no automatizada — un comprobador no distingue una política
inventada de una redacción neutra.

---

## 5. Importar

El circuito completo. **Ningún paso es nuevo salvo el primero.**

```
   ┌─────────────────────────────────────────────────────────────────────┐
   │ 1  ELEGIR                                                           │
   │    El catálogo ya se muestra revalidado contra TU cuenta: antes de  │
   │    importar ves qué te va a faltar.                                 │
   └───────────────────────────────┬─────────────────────────────────────┘
                                   ↓
   ┌─────────────────────────────────────────────────────────────────────┐
   │ 2  RESOLVER LOS REQUISITOS         ← lo único que se construye      │
   │                                                                     │
   │    ‹FUENTE_FORO›    1 candidata  → se mapea sola                    │
   │    ‹TIPO_SOPORTE›   3 candidatas → te pregunta cuál                 │
   │    ‹ETIQUETA›       0 candidatas → queda <PENDIENTE> y te lo dice   │
   └───────────────────────────────┬─────────────────────────────────────┘
                                   ↓
   ┌─────────────────────────────────────────────────────────────────────┐
   │ 3  AL ASISTENTE, como borrador                                      │
   │    NO crea el agente. Entra al panel del Entrenamiento, con el      │
   │    comprobador corriendo en cada tecla, y se adapta conversando.    │
   └───────────────────────────────┬─────────────────────────────────────┘
                                   ↓
   ┌─────────────────────────────────────────────────────────────────────┐
   │ 4  PROBAR EN SECO                                        ← F6       │
   │    Obligatorio en el flujo, no opcional. Ver 5.1.                   │
   └───────────────────────────────┬─────────────────────────────────────┘
                                   ↓
   ┌─────────────────────────────────────────────────────────────────────┐
   │ 5  GUARDAR con el flujo de siempre                                  │
   └─────────────────────────────────────────────────────────────────────┘
```

### 5.1 Por qué el paso 4 no es opcional

Un placeholder resuelto **mal** produce un Entrenamiento *válido pero equivocado*:

```
  La cuenta tiene 3 foros. Se elige el que no era.
      ↓
  El comprobador dice que está bien — la fuente existe.
      ↓
  El agente busca en el corpus equivocado. Para siempre. Sin avisar.
```

Es exactamente la clase de falla para la que se construyó F6. Por eso la importación
**desemboca en la prueba en seco** en vez de terminar en "guardar". No hay mecanismo
nuevo: es cablear el flujo que ya está.

### 5.2 Lo que NO hace

No existe un botón "instalar" que cree agentes a ciegas. Un agente que aparece
configurado sin que nadie haya visto qué ejecuta es el problema del generador viejo,
otra vez.

---

## 6. Frescura: revalidar al mostrar

Una receta es una **foto**: no se versiona, no se rastrea quién la importó. Eso tiene un
problema y una respuesta barata.

### 6.1 El problema: la receta se pudre sola

```
  El comprobador tiene 13 reglas hoy. Una se agregó HOY.
  El catálogo de fuentes reconoce 6. Va a reconocer 7 cuando entre WordPress.

  Receta publicada ayer, sin tocar una letra, revisada con el motor de hoy:
      ⚠ calendar_not_configured      ← regla que ayer no existía

  El texto no cambió. Cambió el motor.
```

Con "solo una foto", una receta puede volverse inválida **sin que nadie la toque**.

### 6.2 La respuesta: revalidar al leer, no al publicar

La pantalla del catálogo pasa cada receta por el comprobador **en el momento de
mostrarla** — con el motor de hoy y contra la cuenta que está mirando.

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │  Soporte con foro y escalamiento                        3 temas      │
  │  ⚠ En tu cuenta falta: una etiqueta de cierre                        │
  ├──────────────────────────────────────────────────────────────────────┤
  │  Coordinador multi-tema                                 5 temas      │
  │  ✓ Todo lo que necesita existe en tu cuenta                          │
  ├──────────────────────────────────────────────────────────────────────┤
  │  Agenda de citas                                        1 tema       │
  │  ✗ Esta receta dejó de ser válida con el motor actual                │
  └──────────────────────────────────────────────────────────────────────┘
```

Dos cosas de una: la receta podrida se ve podrida, y **antes de importar ya sabés qué te
va a faltar**. Es código que ya existe, corriendo en otro momento.

### 6.3 Un contador, no una relación

Sin ningún rastro, el proveedor cura a ciegas: no sabe qué recetas usa alguien. Se guarda
un **número** —`veces_importada`— y nada más: ni quién, ni cuándo, ni en qué cuenta.

```
  veces_importada: 14        ← señal de curaduría
  (no se guarda quién, ni cuándo, ni desde qué cuenta)
```

No arrastra el versionado ni ningún tema de privacidad, y es la única señal disponible
para decidir qué recetas mejorar o retirar.

---

## 7. El frontend

### 7.1 Catálogo — pestaña nueva del Asistente

```
  ┌────────────────────────────────────────────────────────────────────┐
  │ Asistente │ Conversaciones │ Agentes IA │ Recursos │ Catálogo      │
  ├────────────────────────────────────────────────────────────────────┤
  │  Recetas publicadas por el proveedor. Se importan como borrador:   │
  │  se adaptan a lo que tenés y se prueban antes de guardar.          │
  │                                                                    │
  │  Estado ▾   Receta              Temas  Requiere        Importada   │
  │  ───────────────────────────────────────────────────────────────   │
  │  ✓ lista    Soporte con foro      3    foro·tipo·etiq      14      │
  │  ⚠ falta 1  Coordinador           5    2 fuentes·3 tipos    8      │
  │  ✗ vencida  Agenda de citas       1    calendario           2      │
  └────────────────────────────────────────────────────────────────────┘
```

Tabla ordenable y paginada, con las piezas que ya se construyeron para Conversaciones y
Agentes IA (`SortableTh`, `tableSort`, `TableFooter`).

### 7.2 Resolver los requisitos, al importar

```
  ┌────────────────────────────────────────────────────────────────────┐
  │  Importar «Soporte con foro y escalamiento»                   [×]  │
  ├────────────────────────────────────────────────────────────────────┤
  │  ‹FUENTE_FORO›     [ Foro Kontrolya                          ▾ ]   │
  │                    la única de tipo foro en tu cuenta              │
  │                                                                    │
  │  ‹TIPO_SOPORTE›    [ Elegí uno…                              ▾ ]   │
  │                    Soporte · Incidente del sistema · Comercial     │
  │                                                                    │
  │  ‹ETIQUETA›        no tenés ninguna etiqueta creada                │
  │                    va a quedar como <PENDIENTE: etiqueta>          │
  ├────────────────────────────────────────────────────────────────────┤
  │                          [ Cancelar ]  [ Llevar al Asistente → ]   │
  └────────────────────────────────────────────────────────────────────┘
```

### 7.3 Publicar — solo con el flag

```
  ┌────────────────────────────────────────────────────────────────────┐
  │  Publicar receta                                                   │
  ├────────────────────────────────────────────────────────────────────┤
  │  Nombre     [ Soporte con foro y escalamiento por rama         ]   │
  │  Para qué   [ El cliente reporta una falla; se busca en el     ]   │
  │             [ foro y si no resuelve, se abre un caso.          ]   │
  │                                                                    │
  │  Entrenamiento (con ‹PLACEHOLDERS› donde van los nombres)          │
  │  ┌──────────────────────────────────────────────────────────────┐  │
  │  │ @ruta(soporte #‹ETIQUETA›: no puedo entrar, me da error):    │  │
  │  │   @buscar_foro(‹FUENTE_FORO›) -> @crear_ticket(tipo=‹TIPO›)  │  │
  │  └──────────────────────────────────────────────────────────────┘  │
  │                                                                    │
  │  Requisitos detectados: ‹ETIQUETA› ‹FUENTE_FORO› ‹TIPO›            │
  │  ✓ Con los placeholders resueltos, el comprobador la acepta        │
  │                                                                    │
  │  ⚠ Recordá: sin precios, plazos ni políticas. Esta prosa la va a   │
  │    decir un agente a los clientes de otra empresa.                 │
  └────────────────────────────────────────────────────────────────────┘
```

Los requisitos se **detectan** del texto (`‹...›`) en vez de escribirse a mano: así no
puede publicarse una receta con un placeholder sin declarar.

---

## 8. Modelo de datos

### 8.1 Una tabla

```
   assistant_recipes
   ├── id
   ├── account_id        FK — la cuenta PROVEEDORA que la publicó
   ├── user_id           FK — quién la publicó
   ├── name              string, único
   ├── purpose           text — "para qué sirve", una o dos frases
   ├── body              text — el Entrenamiento con sus ‹PLACEHOLDERS›
   ├── requirements      jsonb — [{ key: 'FUENTE_FORO', kind: 'source',
   │                                source_type: 'discourse' }, …]
   ├── published         boolean, default false
   ├── imports_count     integer, default 0   ← un número, no una relación
   └── timestamps
```

**No hay tabla de importaciones, a propósito.** Es la decisión de "solo una foto": sin
relación no hay versionado que mantener, ni rastro de qué cuenta usa qué.

### 8.2 Lo que NO se guarda

```
  ✗ quién importó cada receta        (decisión: foto, sin rastreo)
  ✗ el resultado de la revalidación  (se recalcula al mostrar — sec. 6.2)
  ✗ embeddings                       (ver 3.2)
```

Guardar la revalidación sería volver a tener una foto que envejece: exactamente el
problema que la sección 6 resuelve.

---

## 9. API

```
  GET    /api/v1/accounts/:id/contact_trackings/recipes
         El catálogo, YA revalidado contra la cuenta que pregunta.
         Cualquier cuenta.

  GET    /api/v1/accounts/:id/contact_trackings/recipes/:id/preview
         La receta con los requisitos resueltos contra el inventario de
         esta cuenta: qué se mapea solo, qué hay que elegir, qué falta.

  POST   /api/v1/accounts/:id/contact_trackings/recipes/:id/import
         Devuelve el BORRADOR adaptado. No crea ningún agente.
         Incrementa imports_count.

  POST   /api/v1/accounts/:id/contact_trackings/recipes          ← con flag
  PATCH  /api/v1/accounts/:id/contact_trackings/recipes/:id      ← con flag
  DELETE /api/v1/accounts/:id/contact_trackings/recipes/:id      ← con flag
```

Los tres últimos exigen `feature_enabled?('assistant_catalog_publisher')`. Como en el
resto del Asistente, el gate va en un `before_action` sin `only:` sobre las acciones de
escritura, y un spec recorre **todos** los endpoints exigiendo el rechazo — el mismo
patrón que ya cubre los diez del Asistente.

---

## 10. Fases

```
  C1 ███       La tabla, el modelo y la detección de requisitos
  C2 ████      Publicar: pantalla y endpoints, tras el flag
  C3 ████      El catálogo revalidado contra la cuenta que mira
  C4 █████     Importar: resolver requisitos → borrador → Asistente
  C5 ██        Cablear la prueba en seco al final del circuito
  C6 ██        Sembrar el catálogo con recetas reales
```

| Fase | Qué entrega | Días |
|---|---|---|
| **C1** | `assistant_recipes`, detección de `‹PLACEHOLDERS›`, specs | 2 |
| **C2** | Publicar con las tres condiciones; el flag | 2 |
| **C3** | Listado revalidado contra la cuenta que pregunta | 2 |
| **C4** | Resolver requisitos e importar como borrador | 3 |
| **C5** | La importación desemboca en F6 | 1 |
| **C6** | Recetas reales, escritas y curadas | 2 |

**Primer entregable demostrable: C3.** Con el catálogo visible y revalidado —aunque
todavía no se pueda importar— ya se ve qué recetas sirven en una cuenta y cuáles no.

---

## 11. Riesgos y lo que no resuelve

| Riesgo | Qué se hace |
|---|---|
| **Una receta con un defecto sutil se propaga y no hay a quién avisar** | Se acepta, con los ojos abiertos. El comprobador del destino caza los defectos *estructurales* al importar; los "válido pero equivocado" viajan. Es el costo de no rastrear, y es la decisión tomada |
| **La receta envejece con el motor** | Revalidar al mostrar (sec. 6) |
| **Placeholder resuelto mal** | La importación desemboca en la prueba en seco (sec. 5.1) |
| **Una receta con contenido de negocio se dice como cierto a clientes ajenos** | Regla editorial en la pantalla de publicar. NO automatizable: un comprobador no distingue una política inventada de prosa neutra |
| **El catálogo crece y buscar se vuelve difícil** | Hoy no es un problema (19 candidatos). Cuando lo sea, embeddings sobre el *objetivo* — sec. 3.2 |

### 11.1 Lo que este plan NO resuelve

```
  ✗ No dice qué prompts FUNCIONAN en producción.
    Eso exige telemetría que hoy no existe: el motor no registra qué rama
    eligió en cada turno (sec. 1.2). Es un módulo aparte y vale la pena,
    pero no es este.

  ✗ No mejora los 9 agentes rotos de la cuenta por sí solo.
    Para eso está "Arreglarlo acá", que ya existe.

  ✗ No destila reglas nuevas del comprobador a partir del corpus.
    Es el uso más valioso del catálogo a largo plazo —qué hacen los buenos
    que los rotos no— y necesita un corpus que todavía no existe.
```

### 11.2 La condición que hace honesto al catálogo

Se repite acá porque es lo que más fácil se pierde de vista:

> El catálogo **no promete** que sus recetas funcionan. Promete que son **ejemplos
> correctos y ejecutables, curados por el proveedor**, y que antes de guardarlas vas a
> haber visto —con el comprobador y con una pregunta real— qué hacen en TU cuenta.
