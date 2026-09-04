# Filtros guardados para Tickets — vistas por cuenta

> Rama `feat/tickets_filtros`, derivada de `develop`.
> Estado: **plan**. Nada implementado todavía.
>
> Objetivo: que un usuario arme un juego de filtros en el Gestor de Tickets, lo
> guarde con nombre, lo aplique desde una lista, y pueda editarlo o borrarlo.
> Las vistas pueden ser **personales** o **compartidas con la cuenta** (modelo
> híbrido, decidido el 2026-09-04).

---

## 1. El hallazgo que define el diseño

**No hay que construir el mecanismo: Chatwoot ya lo trae.** `CustomFilter` es el
modelo que hace funcionar las "carpetas" de Conversaciones, y viene con el ciclo
completo — tabla, API REST, store de Vuex y dos modales.

```
   YA EXISTE EN EL REPO                          LO QUE FALTA
   ─────────────────────                         ────────────
   tabla  custom_filters                         · valor case_ticket en el enum
     account_id · user_id · name                 · columna shared
     query jsonb · filter_type enum              · scope "mías + compartidas"
                                                 · serializar/aplicar los
   API    /api/v1/accounts/:id/custom_filters      filtros de Index.vue
     index · show · create · update · destroy    · selector de vistas en la barra
                                                 · pantalla de gestión
   store  store/modules/customViews.js
     getCustomViewsByFilterType(tipo)  ←── ya sabe separar por tipo

   UI     customviews/AddCustomViews.vue     (112 líneas)
          customviews/DeleteCustomViews.vue  (105 líneas)
```

Reusarlo cumple además la regla del proyecto: **la UI nueva del dashboard se
construye con los componentes nativos, nunca con réplicas a medida.**

El precio de reusar es aceptar el modelo de datos ajeno: `query` es un `jsonb`
libre, así que la forma de los filtros de tickets la definimos nosotros (§4) y
nadie la valida del otro lado.

---

## 2. El enum, y por qué es la trampa principal

`filter_type` es un enum **respaldado por enteros**, y el entero sale de la
posición:

```ruby
enum filter_type: { conversation: 0, contact: 1, report: 2 }
```

```
   CORRECTO — agregar al final              INCORRECTO — insertar en medio
   ────────────────────────────             ──────────────────────────────
   conversation: 0   ← intactas             conversation: 0
   contact:      1   ← intactas             case_ticket:  1   ⚠ las filas que
   report:       2   ← intactas             contact:      2     valían 1 ahora
   case_ticket:  3   ← nuevo                report:       3     son "contact"
                                                                y las de 2 son
                                                                "report"...
```

Insertar en medio le cambia el tipo a **todos los filtros guardados que ya
existen en la base**, en todas las cuentas, sin error ni aviso. Es exactamente
la misma clase de trampa que el bitfield de `config/features.yml` que documenta
el skill `@tickets_cases`.

> **Regla: `case_ticket: 3` va al final, y cualquier tipo futuro también.**

---

## 3. Personal vs compartida

El `index` nativo arranca desde el usuario, no desde la cuenta:

```ruby
@custom_filters = current_user.custom_filters.where(
  account_id: Current.account.id,
  filter_type: permitted_params[:filter_type] || DEFAULT_FILTER_TYPE
)
```

O sea: hoy **cada agente ve solo las suyas**. Para el modelo híbrido hace falta
una columna y un scope nuevo.

```
   ┌─────────────────────────────────────────────────────────────┐
   │  custom_filters                                             │
   │  ┌────┬──────────┬─────────┬──────────────┬────────┐        │
   │  │ id │ user_id  │ account │ filter_type  │ shared │        │
   │  ├────┼──────────┼─────────┼──────────────┼────────┤        │
   │  │ 12 │ 2 Andrés │    2    │ case_ticket  │ false  │ ──┐    │
   │  │ 13 │ 2 Andrés │    2    │ case_ticket  │ true   │ ──┼─┐  │
   │  │ 14 │ 58 Mario │    2    │ case_ticket  │ true   │ ──┼─┤  │
   │  │ 15 │ 58 Mario │    2    │ case_ticket  │ false  │   │ │  │
   │  │  7 │ 2 Andrés │    2    │ conversation │ false  │ ──┼─┼─ intactas
   │  └────┴──────────┴─────────┴──────────────┴────────┘   │ │  │
   └────────────────────────────────────────────────────────┼─┼──┘
                                                            │ │
        Andrés abre el Gestor de Tickets y ve:  ────────────┘ │
          MÍAS         12, 13                                 │
          COMPARTIDAS  14  ←── de Mario  ─────────────────────┘
```

**`shared` arranca en `false` para todas las filas existentes**, así que las
carpetas de Conversaciones, Contactos e Informes siguen comportándose igual que
siempre. Ese default es lo que hace que el cambio de scope sea seguro para los
otros tres tipos: sin filas compartidas, "mías + compartidas" da el mismo
resultado que "mías".

### Quién puede tocar qué

```
                      ver      aplicar    renombrar/editar    eliminar
   ─────────────────────────────────────────────────────────────────────
   mía                  ✓          ✓             ✓               ✓
   compartida, ajena    ✓          ✓             ✗               ✗
   compartida, ajena
   siendo administrador ✓          ✓             ✓               ✓
```

Un agente no puede romperle la vista a otro; un administrador sí puede limpiar
la casa. Es la misma regla que ya rige en el resto del módulo de tickets.

**Alternativa descartada:** guardar `shared` dentro del `query` jsonb para no
tocar la tabla nativa. Evita la migración, pero mete metadatos en el campo que
describe los filtros, y deja el scope dependiendo de un operador jsonb en cada
consulta del índice. Una columna booleana con default es más barata de leer y
de indexar.

---

## 4. Forma del `query`

`query` es `jsonb` libre. Lo que guardamos es, literalmente, el estado de
filtros de `Index.vue`:

```json
{
  "v": 1,
  "search": "",
  "date_range": ["2026-09-01", "2026-09-30"],
  "status": "open",
  "priority": "high",
  "origin": "",
  "quick": "unassigned",
  "case_type_id": 6,
  "sort_by": "created_at",
  "sort_order": "desc"
}
```

| clave | de dónde sale en `Index.vue` |
|---|---|
| `search` | `search` |
| `date_range` | `dateRange`, ya formateado `YYYY-MM-DD` |
| `status` | `statusFilter` |
| `priority` | `priorityFilter` |
| `origin` | `originFilter` |
| `quick` | `activeFilter` — `mine` · `unassigned` · `all` · `sla_overdue` |
| `case_type_id` | `activeType` |
| `sort_by` / `sort_order` | `sortBy` / `sortOrder` |

Deliberadamente **no** se guardan `currentPage` ni `perPage`: son estado de
navegación, no criterio. Abrir una vista guardada siempre empieza en la
página 1.

El campo `v` es la versión del formato. Hoy no se usa para nada, pero cuando
agreguemos filtros nuevos —agente concreto, equipo, categoría— una vista vieja
va a llegar sin esas claves y hay que poder distinguir "no lo guardó" de "lo
guardó vacío". Sale gratis ahora y no se puede agregar después.

### Al aplicar: tolerancia

```
   vista guardada          Index.vue
   ──────────────          ─────────
   clave presente   ────►  se asigna
   clave ausente    ────►  se deja el default (NO se toca)
   clave desconocida────►  se ignora en silencio
   case_type_id que
   ya no existe     ────►  se cae a "Todos los tipos" + aviso
```

El último caso es real: los tipos de caso son una tabla configurable por cuenta
(`case_types`), y alguien puede borrar un tipo que una vista guardada todavía
referencia. La vista no debe romperse por eso.

---

## 5. Recorrido de la pantalla

```
   ┌──────────────────────────────────────────────────────────────────────┐
   │  Gestor de Tickets                              [+ Nuevo ticket]     │
   ├──────────────────────────────────────────────────────────────────────┤
   │  Mis Tickets │ Sin Asignar │ Todos │ SLA vencidos (3)                 │
   ├──────────────────────────────────────────────────────────────────────┤
   │  ┌─ Vista ──────────────────┐                                        │
   │  │ ▾ Urgentes sin asignar   │   🔍 buscar   [Estado ▾] [Prioridad ▾] │
   │  ├──────────────────────────┤   [Tipo ▾] [Origen ▾] [Fechas] [↕]     │
   │  │  MIS VISTAS              │                                        │
   │  │   · Mi cola del día      │            ● modificada  [Guardar]     │
   │  │   · Urgentes sin asignar │                          [Guardar como]│
   │  │  COMPARTIDAS             │                                        │
   │  │   · Escalados 👥 Mario   │                                        │
   │  ├──────────────────────────┤                                        │
   │  │  ⚙ Gestionar vistas      │                                        │
   │  └──────────────────────────┘                                        │
   ├──────────────────────────────────────────────────────────────────────┤
   │  FOLIO      TÍTULO                  ESTADO    PRIORIDAD   VENCE      │
   │  DES-173    Base remota CONTPAQi    Abierto   Alta        05/09      │
   └──────────────────────────────────────────────────────────────────────┘
```

El punto `●` aparece cuando el estado actual de los filtros ya no coincide con
la vista cargada. Sin ese indicador nadie sabe si está viendo la vista o algo
que tocó encima, y es la queja clásica de este tipo de UI.

### Pantalla de gestión

```
   ┌─ Gestionar vistas de tickets ────────────────────────── ✕ ─┐
   │                                                            │
   │  MIS VISTAS                                                │
   │   Mi cola del día              personal      ✎   🗑         │
   │   Urgentes sin asignar         compartida    ✎   🗑         │
   │                                                            │
   │  COMPARTIDAS POR OTROS                                     │
   │   Escalados          Mario Alberto           ·   ·         │
   │   Cierres de la semana   Kareli              ✎   🗑  ← solo │
   │                                                  si soy    │
   │                                                  admin     │
   │                                                            │
   │  12 de 50 vistas usadas                                    │
   └────────────────────────────────────────────────────────────┘
```

El contador del pie no es decorativo: ver §8.

---

## 6. Componentes

| Archivo | Qué cambia |
|---|---|
| `db/migrate/…_add_shared_to_custom_filters.rb` | **nuevo** — `shared` boolean, default `false`, not null |
| `app/models/custom_filter.rb` | `case_ticket: 3` **al final** del enum + scope `visible_for` |
| `app/controllers/api/v1/accounts/custom_filters_controller.rb` | `fetch_custom_filters` pasa a "mías + compartidas de la cuenta"; `update`/`destroy` verifican dueño o administrador |
| `app/views/api/v1/models/_custom_filter.json.jbuilder` | agrega `shared`, `user_id` y el nombre del dueño |
| `app/policies/custom_filter_policy.rb` | `update?`/`destroy?` dejan de ser "cualquier agente" |
| `Index.vue` | serializar filtros → `query`, aplicar `query` → filtros, selector de vistas, indicador `●` |
| `gestorTickets/SavedViews.vue` | **nuevo** — pantalla de gestión |
| `i18n/locale/{es,en}/gestorTickets.json` | cadenas nuevas |
| `spec/` | modelo, controller y policy |

No se toca `customViews.js` ni `AddCustomViews.vue`: ya aceptan un
`filterType` arbitrario. `AddCustomViews` sí necesita poder recibir la casilla
"compartir", y eso se resuelve con una prop opcional que los tres usos actuales
ignoran.

---

## 7. Fases

```
   F1  Enum + migración + modelo            back    case_ticket: 3, shared
       └── sin efecto visible; los otros tres tipos siguen igual

   F2  Scope, permisos y payload           back    mías + compartidas
       └── verificable con specs y curl, todavía sin UI

   F3  Guardar y aplicar desde Index.vue   front   selector + Guardar como
       └── aquí ya sirve de punta a punta

   F4  Indicador de "modificada" + Guardar front   el punto ●
       └── sobreescribe la vista cargada

   F5  Pantalla de gestión                 front   renombrar, compartir, borrar

   F6  Documentación                       docs    bóveda + Trampas + skill
```

F1 y F2 son las que pueden romper algo ajeno (Conversaciones, Contactos,
Informes) y por eso van primero y con specs propias. De F3 en adelante el
riesgo es solo del módulo de tickets.

---

## 8. Riesgos

| Riesgo | Mitigación |
|---|---|
| **El enum corrompe filtros existentes** | `case_ticket` al final. Spec que fija los cuatro valores numéricos |
| **El scope nuevo comparte carpetas de Conversaciones** | `shared` con default `false`: sin filas compartidas el resultado no cambia. Spec de regresión sobre los tres tipos viejos |
| **`MAX_FILTER_PER_USER = 50` es por usuario y cuenta TODOS los tipos** | Las vistas de tickets comen del mismo presupuesto que las carpetas de Conversaciones. Mostrar el contador (§5) y decidir si el tope sube o se vuelve por tipo — **queda abierto** |
| **Se borra un `case_type` que una vista referencia** | Al aplicar, tipo inexistente → "Todos los tipos" + aviso, sin romper |
| **Un admin borra la vista compartida de la que depende un equipo** | Confirmar con `woot-delete-modal` diciendo que es compartida y de quién |
| **Divergencia con Chatwoot upstream** | La columna `shared` es aditiva y con default; una actualización que no la conozca no se rompe |

---

## 9. Lo que este plan NO incluye

Salió en la revisión de los filtros y queda fuera a propósito, para no mezclar:

- **Filtros en la URL** (query params). Es el complemento natural —una vista
  guardada no es más que una URL con nombre— pero es un cambio de navegación
  independiente. Si se hace, conviene **después** de F3.
- **Filtrar por agente concreto y por equipo** (`team_id` ni existe en el
  backend hoy).
- **Multi-selección** de valores por filtro, y ordenar por `due_at`,
  `updated_at` o folio.

Cuando alguno de esos entre, el campo `v` del `query` (§4) es lo que permite
que las vistas guardadas hoy sigan abriendo bien.
