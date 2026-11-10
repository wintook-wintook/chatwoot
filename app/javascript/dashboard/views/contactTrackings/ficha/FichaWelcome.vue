<script>
// feat/ficha_agente_ia — EL MENSAJE DE BIENVENIDA (sección propia de Recursos)
// ============================================================================
// Pedido del usuario (10/11/2026): «no veo en ningún lado del siguiente, siguiente el
// mensaje de bienvenida y sus adjuntos». El texto (con ✨ proponer/mejorar) y qué
// archivos van con él. El motor lo manda TAL CUAL en el primer mensaje del cliente.
//   v-model:text · files: [{ key, name, welcome }] · @toggle(file) · @suggest
// ============================================================================
export default {
  props: {
    text: { type: String, default: '' },
    files: { type: Array, default: () => [] },
    // Preguntas «enseguida de la bienvenida»: la primera va al final del mensaje.
    firstQuestion: { type: String, default: '' },
    suggesting: { type: Boolean, default: false },
    disabled: { type: Boolean, default: false },
  },
  emits: ['update:text', 'toggle', 'suggest'],
  computed: {
    withWelcome() {
      return this.files.filter(file => file.welcome);
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_TEMPLATES.FICHA.${key}`, args);
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
      {{ t('WELCOME_HINT') }}
    </p>
    <div class="flex items-center justify-between gap-2">
      <span class="text-sm text-slate-800 dark:text-slate-100">
        {{ t('WELCOME') }}
      </span>
      <woot-button
        size="small"
        variant="smooth"
        icon="wand"
        :is-loading="suggesting"
        :is-disabled="disabled || suggesting"
        @click="$emit('suggest')"
      >
        {{ text.trim() ? t('WELCOME_IMPROVE') : t('SUGGEST') }}
      </woot-button>
    </div>
    <textarea
      rows="5"
      maxlength="600"
      class="!mb-0"
      :value="text"
      :disabled="disabled"
      :placeholder="t('WELCOME_PLACEHOLDER')"
      @input="$emit('update:text', $event.target.value)"
    />
    <!-- Vista previa: como la verá el cliente -->
    <div
      v-if="text.trim() || withWelcome.length || firstQuestion"
      class="flex flex-col self-start max-w-full gap-1 px-3 py-2 text-sm whitespace-pre-wrap bg-white rounded-lg rounded-tl-none shadow-sm dark:bg-slate-800 text-slate-700 dark:text-slate-200"
    >
      <span v-if="text.trim()">{{ text }}</span>
      <span v-if="firstQuestion" class="font-medium">{{ firstQuestion }}</span>
      <span
        v-for="file in withWelcome"
        :key="file.key"
        class="flex items-center gap-1 text-xs text-woot-600"
      >
        <fluent-icon icon="attach" size="12" />
        {{ file.name }}
      </span>
    </div>
    <p v-if="firstQuestion" class="!m-0 text-xs text-slate-500">
      {{ t('WELCOME_WITH_QUESTION') }}
    </p>
    <div class="flex flex-col gap-1">
      <span class="text-sm text-slate-800 dark:text-slate-100">
        {{ t('WELCOME_FILES_PICK') }}
      </span>
      <p v-if="!files.length" class="!m-0 text-xs text-slate-500">
        {{ t('WELCOME_NO_FILES') }}
      </p>
      <label
        v-for="file in files"
        :key="file.key"
        class="flex items-center gap-2 !m-0 text-sm cursor-pointer"
      >
        <input
          type="checkbox"
          class="!m-0"
          :checked="file.welcome"
          :disabled="disabled"
          @change="$emit('toggle', file)"
        />
        <fluent-icon icon="attach" size="14" class="text-slate-400" />
        {{ file.name }}
      </label>
    </div>
  </div>
</template>
