# Plan: Dali lee sus guías del Centro de ayuda «Guías de Dali»

Rama: `feat/dali_guias_centro_ayuda` (desde `origin/develop`, 2026-11-23). **No mergear a develop hasta terminar y probar.**

## Objetivo

Hoy Dali contesta las preguntas de uso («¿cómo creo…?», «¿dónde veo…?») **solo** con los archivos
`config/assistant/guides/*.md` (54 guías). El Centro de ayuda global es una **copia** que genera
`rake assistant:guides:publish` (y que sobrescribe cualquier edición hecha en el portal).

Queremos que la **fuente** de las guías sea el Centro de ayuda **«Guías de Dali»** (slug `ayuda-dali`)
y que **Dali funcione exactamente igual** que con los `.md`: mismas guías encontradas, mismo orden,
mismos permisos por área, mismas ligas a pantallas, mismo texto.

## Decisiones ya tomadas

| Tema | Decisión |
|---|---|
| Slug del portal | `ayuda-dali` (se ve en la liga pública `/hc/ayuda-dali/articles/...`) |
| Nombre visible | «Guías de Dali» |
| Cuenta dueña | **568** hoy (dev: «Developer Test»; confirmar en prod). **Nunca escribir 568 en el código**: el portal se encuentra por su slug, no por la cuenta. |
| Alcance | Un solo portal para **todas** las cuentas. Ninguna cuenta captura nada. Solo el Administrador de la cuenta dueña lo edita. Las demás cuentas no lo ven en su pantalla de Centro de ayuda (`Current.account.portals`), pero Dali les contesta con él y la liga pública abre el artículo. |
| Comportamiento | Idéntico al actual. La búsqueda (`Assistant::Guides.search`/`score`/`stem`/`sound`) **no se toca**. |
| Centros de ayuda de cada cuenta | Fuera de alcance. Dali no los lee (ni antes ni después). |

## Cómo funciona hoy (lo que no debe cambiar)

- `app/services/assistant/guides.rb` → `load_all` lee los `.md` y arma `Guide(key, title, areas, keywords, pages, body, category, sources, reviewed)`. En producción se memoriza (`@all ||=`); en desarrollo se relee en cada llamada.
- `search(text, grant)`: palabras sin stopwords; puntos 3 keywords / 2 título / 1 texto; raíz (`stem`) y faltas comunes (`sound`); top 3 con `MIN_SCORE = 3`; solo guías visibles por área (`visible_to?`).
- `find(key, grant)`: por clave o por título.
- `app/services/assistant/guide_tools.rb`: `search_guides`, `read_guide` (regresa `content`, `pages` con su etiqueta y `url` del artículo), `report_gap` (tabla `assistant_guide_gaps`). `tool_choice` obliga `search_guides` en preguntas de uso (`HOW_TO`).
- Otros que usan las guías: `app/services/academy/catalog.rb:94` (`Guides.all`), `app/controllers/api/v1/accounts/academy_controller.rb:33` (`Guides.find`), `app/services/assistant/guide_freshness.rb` (`rake assistant:guides:stale`), `lib/tasks/assistant_guides.rake` (`check`, `portal`, `publish`, `stale`).
- `app/services/assistant/guide_publisher.rb`: `portal` = `Portal.find_by(slug: ENV.fetch('PLATFORM_HELP_PORTAL_SLUG', 'ayuda'), archived: false)` (sin filtrar por cuenta; slug único: `index_portals_on_slug`). Artículos con slug `kontrolya-<clave>` y `meta = { guide_key, tags: keywords.first(10) }`.
- Specs: `spec/services/assistant/guides_spec.rb`, `guide_tools_spec.rb`, `guide_publisher_spec.rb`, `guide_freshness_spec.rb`.

Estado en dev (`wintook_dev`, 2026-11-23): **no existe ningún portal `ayuda` ni `ayuda-dali`**; la cuenta 568 no tiene portales; las guías nunca se publicaron aquí. `PLATFORM_HELP_PORTAL_SLUG` no está en `.env`.

---

## Paso a paso

### Paso 1. Nombre del portal: `ayuda-dali` / «Guías de Dali»

- `guide_publisher.rb`: `DEFAULT_PORTAL_SLUG = 'ayuda-dali'`; `create_portal!(name: 'Guías de Dali')`; `header_text` acorde.
- `lib/tasks/assistant_guides.rake` (`portal`): default `NAME` = «Guías de Dali»; textos de ayuda con el slug nuevo.
- Se conserva `PLATFORM_HELP_PORTAL_SLUG` para sobrescribirlo sin tocar código.
- Revisar comentarios/guías que digan «ayuda» o «Ayuda Kontrolya» (`centro_ayuda.md`, `dali.md`, cabecera de `guides.rb`).

**Hecho cuando:** `Assistant::GuidePublisher.portal_slug == 'ayuda-dali'` sin variable de entorno.

### Paso 2. Guardar en el artículo todo lo de la cabecera del `.md`

En `article.meta` (jsonb) del portal `ayuda-dali`:

| Clave en `meta` | De la cabecera | Uso |
|---|---|---|
| `guide_key` | `key` | identifica la guía (ya existe) |
| `areas` | `areas` | permisos (`visible_to?`). `[]` = todos |
| `keywords` | `keywords` | **todas** (hoy `tags` solo guarda 10) — valen 3 puntos |
| `tags` | `keywords.first(10)` | se deja como está para el portal público/SEO |
| `pages` | `pages` | ligas a pantallas en `read_guide` |
| `sources` | `sources` | `rake assistant:guides:stale` |
| `reviewed` | `reviewed` | última revisión |

Título → `title`, texto → `content`, resumen → `description`, categoría → `category` (ya se guardan así).

- `guide_publisher.rb#article_attrs` y `#same?`: incluir las claves nuevas.

**Hecho cuando:** tras publicar, cada artículo tiene `meta` igual a su cabecera.

### Paso 3. Que el editor del Centro de ayuda NO borre esos datos  ⚠️ riesgo principal

Hoy `articles_controller.rb#update` hace `@article.update!(article_params)` y `article_params` solo permite
`meta: [:title, :description, { tags: [] }]` → **reemplaza todo el `meta`**. La primera edición desde la
pantalla borraría `guide_key` y `areas`: Dali perdería esa guía o se la mostraría a todos.

- `articles_controller.rb`: hacer **merge** del `meta` recibido con el existente (`@article.meta.merge(nuevo)`), no reemplazo. Aplica a todos los portales y no cambia el comportamiento de Chatwoot (solo conserva claves extra).
- Permitir `areas: []`, `keywords: []`, `pages: []`, `reviewed` **solo** si el artículo es del portal de Dali (`portal.slug == GuidePublisher.portal_slug`). `guide_key` y `sources` no se editan desde la pantalla.
- `app/javascript/dashboard/routes/dashboard/helpcenter/pages/articles/ArticleSettings.vue`: si el portal es el de Dali, mostrar:
  - **Clave** (solo lectura).
  - **Áreas**: selección múltiple con `AccessRole::AREAS` (vacío = todos). Hace falta exponer la lista (endpoint o constante del front).
  - **Palabras clave**: lista sin límite (separar de `tags` o usar el mismo control).
  - **Pantallas**: selección múltiple con las claves de `Assistant::Pages::SCREENS` y su etiqueta.
  - **Revisada el**: fecha.
- Artículo nuevo creado desde la pantalla en este portal: generar `guide_key` desde el slug (`kontrolya-xxx` → `xxx`) y exigir título y al menos una palabra clave; sin `guide_key` Dali no lo toma.
- i18n ES/EN de los campos nuevos.

**Hecho cuando:** editar título/texto/etiquetas desde la pantalla conserva `guide_key`, `areas`, `keywords`, `pages`, `sources`.

### Paso 4. Proteger el portal de Dali

Si el portal se archiva o le cambian el slug, Dali se queda sin guías **en todas las cuentas**.

- `portals_controller.rb#update`: no permitir cambiar `slug` ni `archived` del portal de Dali (error claro). Sí permitir nombre, color, textos.
- `portals_controller.rb#destroy`: bloquear el borrado del portal de Dali.
- Artículos del portal de Dali: archivar/borrar desde la pantalla solo con confirmación («Dali dejará de usar esta guía en todas las cuentas»).

### Paso 5. Que Dali lea del portal (`Assistant::Guides.load_all`)

- Nueva fuente: `Assistant::GuidePublisher.portal&.articles` con `status: :published`, `locale: 'es'`, `meta->>'guide_key'` presente.
- Armar el **mismo** `Guide`:
  - `key` = `meta['guide_key']`, `title` = `title`, `body` = `content`
  - `areas`, `keywords`, `pages`, `sources` = `Array(meta[...]).map(&:to_s)`
  - `reviewed` = `meta['reviewed']`, `category` = nombre de la categoría
- **Prohibido** filtrar por `Current.account` o por un id de cuenta: el portal se encuentra solo por slug.
- `find`, `search`, `score`, `stem`, `sound`, `summary`, `visible_to?` **sin cambios**.
- `read_guide` sigue regresando `url` con `GuidePublisher.article_url` (usa el slug nuevo).
- Separar la lectura de archivos en un método (`load_files`) para el respaldo del paso 7 y para la migración.

### Paso 6. Caché que se vacía al editar

Hoy en producción `@all ||=` deja las guías fijas hasta reiniciar Puma.

- Cambiar a `Rails.cache.fetch` con una llave de versión: `[portal.id, articles.maximum(:updated_at), articles.count]` (un query barato), o
- `after_commit` en `Article` (y en `Portal`) que borre la llave cuando cambie un artículo del portal de Dali.
- En desarrollo puede seguir sin caché.
- Puma y Sidekiq (Dali corre en jobs) deben ver el cambio sin reiniciar: por eso `Rails.cache` (Redis), no memoria del proceso.

**Hecho cuando:** editar una guía en la pantalla y preguntarle a Dali muestra el cambio al momento.

### Paso 7. Respaldo: si no hay portal, leer los `.md`

- Si `GuidePublisher.portal` es `nil` o no regresa guías → `load_files` (lo de hoy) y log `[Assistant::Guides] sin portal ayuda-dali: usando archivos`.
- Así un ambiente sin migrar, un portal archivado por error o un slug cambiado no dejan a Dali sin guías.
- Mientras exista el respaldo, los `.md` se quedan en el repo como copia. Decidir al final (paso 13) si se quitan.

### Paso 8. Migración única de las 54 guías al portal

1. Crear el portal en la cuenta dueña: `rake assistant:guides:portal ACCOUNT=568` (crea `ayuda-dali` «Guías de Dali»).
2. Correr `GuidePublisher` **una última vez** con el `meta` completo del paso 2 (nuevo rake `assistant:guides:import` o el `publish` actual antes de apagarlo).
3. Verificar (rake `assistant:guides:verify`):
   - 54 de 54 publicadas, ninguna en `failed`;
   - `content` **idéntico carácter por carácter** al cuerpo del `.md`;
   - `meta` idéntico a la cabecera;
   - mismas categorías.

### Paso 9. Apagar la sobrescritura

- `rake assistant:guides:publish` ya **no** debe reescribir artículos (borraría lo editado en el portal). Quitarlo del deploy si está y dejarlo como `import` explícito con confirmación (`FORCE=1`), solo para la migración inicial o para restaurar.
- Opcional recomendado: `rake assistant:guides:export` → portal a `.md` (mismo formato con cabecera), para guardar una copia en git con historial y poder copiar de un ambiente a otro (paso 12).

### Paso 10. Límites del editor

- **Tamaño:** `ApplicationRecord#validate_content_length` limita columnas `text` a 20,000 caracteres. `agenda.md` ya ronda los 19k (con cabecera; `campanas_eventos` ~17k, `dali` ~16.6k). Opciones: validación de longitud propia en `Article` (p. ej. 60,000) solo para el portal de Dali —al existir un validador `:length` el genérico se salta (`check_and_validate_content_length`)— o dividir la guía `agenda`.
- **Formato:** el editor (ProseMirror/markdown) puede reescribir el texto al guardar. Probar: abrir una guía en la pantalla, guardar sin cambiar nada y comparar `content` antes/después. Cuidar listas numeradas, `###`, viñetas, escapes y los `[[clave]]` que usan 5 guías. Si cambia, documentar qué y ajustar (o normalizar al guardar).

### Paso 11. Ajustar lo que dependía de los archivos

- **Academia** (`academy/catalog.rb`, `academy_controller.rb`): usan `Guides.all`/`Guides.find` → funcionan sin cambios si el paso 5 respeta la interfaz. Probar los pasos de la Academia que apuntan a una guía.
- **`rake assistant:guides:check`**: validar los artículos (clave, título, keywords no vacías, áreas ⊂ `AccessRole::AREAS`, pantallas ⊂ `Assistant::Pages::MAP`, `sources` con archivos, áreas sin guía). Quitar `broken_files` (o dejarlo para los `.md` del respaldo).
- **`rake assistant:guides:stale`** (`GuideFreshness`): hoy compara el último commit del `.md` contra los commits de sus `sources`. Cambiar la fecha de la guía a `max(article.updated_at, meta['reviewed'])` y comparar contra los commits de `sources` después de esa fecha.
- **Specs**: `guides_spec.rb` (hoy recorre archivos) → crear portal y artículos de prueba con `PLATFORM_HELP_PORTAL_SLUG` aleatorio (como ya hace `guide_publisher_spec.rb`); `guide_tools_spec.rb` igual; nuevos specs para el merge de `meta`, la protección del portal y el respaldo. Recordar: RSpec corre contra `wintook_dev` → solo specs acotados y transaccionales.

### Paso 12. Ambientes (dev / prod)

- **Diferencia con hoy:** el repo mantiene iguales las guías de dev y prod. Con el portal, **cada ambiente tiene su propia copia** en su base. Lo que se edite en prod no llega a dev.
- Decidir: editar **solo en prod** y bajar a dev con `export`/`import` (paso 9), o al revés.
- Confirmar en prod que la 568 es la cuenta de Kontrolya y si ya existe un portal `ayuda` (de publicaciones anteriores): `Portal.find_by(slug: %w[ayuda ayuda-dali])`. Si existe `ayuda`, renombrarlo a `ayuda-dali` o crear el nuevo y archivar el viejo.
- Si mañana cambia la cuenta dueña: nuevo rake `assistant:guides:move_portal ACCOUNT=<nueva>` que cambie `account_id` del portal, sus artículos y sus categorías (el slug no cambia, Dali lo sigue encontrando).

### Paso 13. Prueba de paridad («funciona igual»)

1. **Comparación automática** (rake o spec, sin tocar datos): para un set de preguntas reales (`assistant_threads` mensajes `user` + `assistant_guide_gaps.question` + las preguntas de ejemplo de `dali.md`) y para cada combinación de áreas de `AccessRole::AREAS`, comparar `Guides.search` con archivos vs con portal: **mismas claves, mismo orden, mismo puntaje**. Y `read_guide` de cada clave: mismo `content`, `pages`, `title`. Tiene que salir **100% igual**.
2. **Prueba con Dali en dev** en **dos cuentas distintas** (la 568 y otra, p. ej. 1128) y con 3 roles (administrador, vendedor, servicio):
   - preguntas de uso → contesta con la guía y la liga `/hc/ayuda-dali/...`;
   - una sin guía → «no lo tengo documentado» y queda en `assistant_guide_gaps`;
   - una guía de otra área → no aparece.
3. Editar una guía en la pantalla → Dali contesta con el cambio sin reiniciar.
4. Archivar el portal en una copia de prueba → Dali usa los `.md` (respaldo) y lo dice en el log.
5. Academia: abrir un paso que apunte a una guía.

### Paso 14. Despliegue

1. Merge a develop (PR, sin push directo) → dev.
2. Por ambiente: `rake assistant:guides:portal ACCOUNT=568` → `import` → `verify` → `check`.
3. Compilar assets (cambia `ArticleSettings.vue`) y reiniciar **Puma y Sidekiq**.
4. Prueba del paso 13.2 en el ambiente.
5. Después: decidir si se borran los `.md` del repo o se dejan como respaldo/export.

### Paso 15. Reglas de edición (documentar en `centro_ayuda.md` / `dali.md`)

- Solo el Administrador de la cuenta dueña edita las guías.
- Cuando cambie una pantalla: actualizar su artículo y «Revisada el». `rake assistant:guides:stale` avisa si se olvida.
- No archivar ni renombrar el portal «Guías de Dali».
- Revisar `rake assistant:guide_gaps` para saber qué guías faltan.

---

## Archivos que se tocan (resumen)

| Archivo | Cambio |
|---|---|
| `app/services/assistant/guide_publisher.rb` | slug/nombre nuevos, `meta` completo, import/export/verify |
| `app/services/assistant/guides.rb` | `load_all` desde el portal + respaldo `load_files` + caché |
| `app/services/assistant/guide_freshness.rb` | fecha desde el artículo |
| `app/controllers/api/v1/accounts/articles_controller.rb` | merge de `meta`, campos extra solo en portal de Dali |
| `app/controllers/api/v1/accounts/portals_controller.rb` | proteger slug/archivado/borrado del portal de Dali |
| `app/models/article.rb` | límite de longitud del portal de Dali; `after_commit` de caché |
| `app/javascript/dashboard/routes/dashboard/helpcenter/pages/articles/ArticleSettings.vue` | campos Clave, Áreas, Palabras clave, Pantallas, Revisada el |
| i18n ES/EN del Centro de ayuda | etiquetas nuevas |
| `lib/tasks/assistant_guides.rake` | `portal`, `import`, `verify`, `export`, `move_portal`, `check`, `stale` |
| `spec/services/assistant/*guide*_spec.rb` + specs nuevos | portal de prueba, merge, protección, respaldo, paridad |
| `config/assistant/guides/centro_ayuda.md`, `dali.md` | explicar el portal «Guías de Dali» |

## Riesgos y cómo se cubren

| Riesgo | Cubierto en |
|---|---|
| Editor borra `guide_key`/`areas` al guardar | Paso 3 |
| Guías visibles para todas las áreas | Pasos 2, 3, 13 |
| Peor búsqueda por keywords recortadas a 10 | Paso 2 |
| Portal archivado/renombrado → Dali sin guías en todas las cuentas | Pasos 4 y 7 |
| Buscar por cuenta (solo la 568 tendría guías) | Paso 5 (regla) y 13.2 (prueba en otra cuenta) |
| Cambios no llegan a Dali hasta reiniciar | Paso 6 |
| Guía > 20,000 caracteres no se guarda | Paso 10 |
| Editor altera el markdown | Paso 10 |
| `publish` sobrescribe lo editado | Paso 9 |
| dev y prod con guías distintas | Paso 12 |
