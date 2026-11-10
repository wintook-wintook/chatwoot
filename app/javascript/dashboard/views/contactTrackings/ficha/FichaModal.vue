<script>
// feat/ficha_agente_ia — MODAL AMPLIO DE LA FICHA
// Pedido del usuario (10/11/2026): hoja, ticket y archivo se configuran en un modal amplio.
// Molde nativo (woot-modal + woot-modal-header) y un pie con [Listo].
export default {
  props: {
    show: { type: Boolean, default: false },
    title: { type: String, default: '' },
    subtitle: { type: String, default: '' },
  },
  emits: ['close'],
};
</script>

<template>
  <woot-modal
    :show="show"
    size="!w-[min(60rem,95vw)]"
    :on-close="() => $emit('close')"
  >
    <div class="flex flex-col h-auto max-h-[85vh]">
      <woot-modal-header :header-title="title" :header-content="subtitle" />
      <div class="flex flex-col flex-1 min-h-0 gap-4 px-8 pb-2 overflow-auto">
        <slot />
      </div>
      <div class="flex justify-end gap-2 px-8 py-4">
        <woot-button @click="$emit('close')">
          {{ $t('TRACKING_TEMPLATES.FICHA.MODAL_DONE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
