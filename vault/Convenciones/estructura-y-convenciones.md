# Estructura y convenciones del repo

## Rutas relevantes

- i18n ES: `app/javascript/dashboard/i18n/locale/es/index.js`
- i18n EN: `app/javascript/dashboard/i18n/locale/en/index.js`
- Store modules: `app/javascript/dashboard/store/modules/`

## Convenciones

- Los archivos custom del proyecto llevan comentarios con etiquetas tipo `proyecto@contact_tracking`,
  `proyecto@contacts_notes`, `proyecto@bot_seguimiento_calendar`, `proyecto@automatizacion_tracking`,
  etc. — sirven para identificar rápido qué código es custom vs. upstream de Chatwoot.
- Los archivos de idioma custom son `.js` (no `.json`) cuando exportan un objeto ES module (ej:
  `contactTracking.js`). Ver [[i18n-claves-faltantes-en]].
- Ante un fix, suele generarse un respaldo `<archivo>.bak_<timestamp>` antes de modificar (ver
  ejemplos en [[contact-tracking-changes-20260420]], [[discourse-knowledge-base]]) — no siempre se
  usa, pero cuando aparece un `.bak_*` es la forma de revertir sin git.

## Notas de performance general (frontend)

- Los getters del store NO deben mutar arrays del state — siempre usar spread `[...arr]` antes de
  `sort`/`reverse`. Ver [[contactnotes-loop-infinito]].
- Los `console.log` dentro de `computed` son muy dañinos en Vue 2 — se ejecutan en cada
  re-evaluación. Ver [[contactpanel-performance]].
- Modales pesados (ProseMirror, modales de tracking) deben usar `v-if` para no montar hasta que se
  necesiten.

## Relacionado
- [[arquitectura-procesos]]
- [[db-wintook-dev-desincronizada]]
