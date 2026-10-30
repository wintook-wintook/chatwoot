<script>
// feat/plantillas_whatsapp_mejoras — LOS BOTONES DE UNA PLANTILLA ENVIADA
// ============================================================================
// El cliente recibe la plantilla con sus botones (respuesta rápida, liga, teléfono, copiar
// código), pero el mensaje del agente solo guarda el texto: la burbuja no los mostraba.
// Salen de la plantilla de la bandeja (message_templates), por nombre e idioma de
// additional_attributes.template_params; el dato que escribió el agente (la terminación
// de la liga o el código) viene en processed_params.buttons.
// ============================================================================
const ICONS = {
  URL: 'open',
  PHONE_NUMBER: 'call',
  COPY_CODE: 'copy',
  QUICK_REPLY: 'arrow-reply',
};

export default {
  props: {
    // [{ index, type, text, url }] (describeTemplate de templateForm.js)
    buttons: {
      type: Array,
      required: true,
    },
    // processed_params.buttons: [{ type, parameter } | null], en el orden de los botones
    values: {
      type: Array,
      default: () => [],
    },
  },
  computed: {
    items() {
      return this.buttons.map(boton => {
        const valor = (this.values[boton.index] || {}).parameter || '';
        return {
          key: boton.index,
          icon: ICONS[boton.type] || 'arrow-reply',
          text:
            boton.type === 'COPY_CODE'
              ? this.$t('CONVERSATION.TEMPLATE_BUTTONS.COPY_CODE')
              : boton.text,
          detail: valor,
        };
      });
    },
  },
};
</script>

<template>
  <div class="template-buttons">
    <div
      v-for="item in items"
      :key="item.key"
      class="template-buttons__item"
      :title="item.detail"
    >
      <fluent-icon :icon="item.icon" size="14" />
      <span>{{ item.text }}</span>
      <span v-if="item.detail" class="template-buttons__detail">
        {{ item.detail }}
      </span>
    </div>
  </div>
</template>

<style scoped lang="scss">
.template-buttons {
  @apply flex flex-col mt-2 -mx-1;
}

.template-buttons__item {
  @apply flex items-center justify-center gap-1 py-1.5 text-sm font-medium border-0 border-t border-solid border-slate-200 dark:border-slate-600;
}

.template-buttons__detail {
  @apply text-xs font-normal opacity-70 truncate max-w-[10rem];
}
</style>
