# contactNotes.js (store) — Loop infinito

## Causa

El getter `getAllNotesByContact` hacía `records.sort()` mutando el array del store directamente.
Vue 2 intercepta mutaciones de arrays → dispara reactividad → el getter se vuelve a llamar → loop
infinito.

## Corrección

`[...records].sort(...)` — crear una copia antes de ordenar, en vez de mutar el array original del
state.

## Regla general

Los getters del store NO deben mutar arrays del state — siempre usar spread `[...arr]` antes de
`sort`/`reverse`.

## Relacionado
- [[contactpanel-performance]]
