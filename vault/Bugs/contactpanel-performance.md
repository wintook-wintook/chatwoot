# ContactPanel.vue — Performance

## Problemas encontrados y corregidos

- Había ~15 `console.log` dentro de computed properties (`hasRequiredIntegrations`,
  `showTrackingButton`) — eliminados. Los `console.log` dentro de `computed` son muy dañinos en
  Vue 2 porque se ejecutan en cada re-evaluación.
- `handleTrackingClick` estaba definido dos veces; el primero incluía un `alert(JSON.stringify(...))`
  de debug — eliminado el duplicado.
- `ContactTrackingModal` y `ContactNoteModal` se renderizaban sin `v-if`, siempre montados —
  corregido a `v-if="showModal && contact.id"`. Modales pesados (ProseMirror, modales de tracking)
  deben usar `v-if` para no montar hasta que se necesiten.

## Relacionado
- [[contactnotes-loop-infinito]]
