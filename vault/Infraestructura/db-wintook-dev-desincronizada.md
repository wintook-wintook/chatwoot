# BD local wintook_dev desincronizada del repo

**Detectado:** 2026-07-01

Al correr una migración nueva (tracking_campaigns), Rails regeneró `db/schema.rb` completo desde
la BD real `wintook_dev`, y el diff resultó enorme y "raro" en `git status` (muchos modelos con
anotaciones cambiadas + schema.rb con cientos de líneas).

## Diagnóstico

- `schema_migrations` en la BD tiene 327 versiones; `db/migrate/` en el repo solo tiene 108
  archivos. 219 versiones aplicadas (fechas desde 2020) no tienen migración en el repo — esperable
  si la BD arrastra historial pre-squash (`20230426130150_init_schema.rb`), no es en sí un
  problema.
- La BD tiene una tabla `migrations` con columnas `id, migration, batch` — es la tabla de
  migraciones default de **Laravel**. Confirma que en el mismo Postgres `wintook_dev` conviven
  tablas de Chatwoot (Rails) y de otra app en Laravel (probablemente sistema de licencias/catálogo
  del cliente).
- Tablas Laravel/ajenas al repo (sin migración ni modelo Rails): `catalogo_opciones`, `cz_options`,
  `cz_packages`, `license_periods`, `type_license`, `forums_accounts`, `forums_type`,
  `forum_responses`, `questions_account`, `questions_answers`, `knowledge_base_articles`,
  `knowledge_base_content_chunks`, `internal_link_content_chunks`, `internal_link_embeddings`.
- Tablas que SÍ estaban en el `schema.rb` committeado (viejo) pero que NO existen en la BD real, y
  tampoco tienen modelo Rails: `case_portals`, `case_settings`, `case_tasks`,
  `external_db_connections`, `external_db_queries`, `erp_collection_bots`. Es decir, el `schema.rb`
  viejo ya estaba desactualizado/con basura de tablas que ya no se usan.

## Por qué importa

Si se commitea el `schema.rb` regenerado tal cual (reflejando la BD real), cualquier entorno que
use `db:schema:load` en vez de `db:migrate` crearía las tablas Laravel dentro de la BD de Chatwoot,
y NO crearía las tablas que el código sí espera para esas 6 features fantasma (si es que aún se
usan en otro lado).

## Estado (al 2026-07-01)

Los cambios de `schema.rb` + anotaciones de modelos quedaron guardados en un **git stash**
(mensaje: "annotate/schema.rb tras migracion local (wintook_dev desincronizada)"), sin pop, a la
espera de decidir qué hacer. Se hizo `git pull` en rama `fix/bulk_tracking` sin conflictos.

## Cómo aplicar

- **No commitear `db/schema.rb` regenerado desde `wintook_dev`** sin antes limpiar/excluir las
  tablas Laravel (vía `ActiveRecord::SchemaDumper.ignore_tables` o similar) y confirmar si las 6
  tablas fantasma deben recrearse o eliminarse del código/histórico.
- Antes de correr más migraciones en este entorno, verificar con el usuario si `wintook_dev` es la
  BD correcta a usar o si hay una BD "limpia" solo-Chatwoot en otro lado.

## Relacionado
- [[fix-whatsapp-named-templates]] — este bug advirtió sobre la misma fuente de ruido en el repo
