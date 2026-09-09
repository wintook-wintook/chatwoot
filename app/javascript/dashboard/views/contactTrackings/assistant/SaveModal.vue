<script>
// proyecto@asistente_agentes_ia — F4
// ============================================================================
// Guardar el borrador: como Agente IA nuevo, o pisando el de uno existente.
//
// Reemplazar es la acción peligrosa —hay agentes en producción— así que se
// elige explícitamente y se avisa que se guarda una copia del anterior.
// ============================================================================
export default {
  props: {
    show: { type: Boolean, default: false },
    templates: { type: Array, default: () => [] },
    inboxes: { type: Array, default: () => [] },
    isSaving: { type: Boolean, default: false },
    error: { type: String, default: '' },
  },
  emits: ['close', 'save'],
  data() {
    return {
      mode: 'create',
      name: '',
      objective: '',
      inboxId: null,
      templateId: null,
    };
  },
  computed: {
    canSave() {
      if (this.mode === 'create') {
        return (
          this.name.trim().length >= 2 && this.objective.trim().length >= 5
        );
      }
      return Boolean(this.templateId);
    },
  },
  methods: {
    submit() {
      if (!this.canSave || this.isSaving) return;
      this.$emit('save', {
        mode: this.mode,
        name: this.name.trim(),
        objective: this.objective.trim(),
        inboxId: this.inboxId,
        templateId: this.templateId,
      });
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')">
    <div class="p-8">
      <h2 class="text-lg font-medium text-slate-800 dark:text-slate-100 mb-4">
        {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_TITLE') }}
      </h2>

      <div class="flex flex-col gap-2 mb-4">
        <label class="flex items-center gap-2 text-sm">
          <input v-model="mode" type="radio" value="create" />
          {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_MODE_CREATE') }}
        </label>
        <label class="flex items-center gap-2 text-sm">
          <input v-model="mode" type="radio" value="replace" />
          {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_MODE_REPLACE') }}
        </label>
      </div>

      <template v-if="mode === 'create'">
        <label class="text-sm">
          {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_NAME') }}
          <input v-model="name" type="text" />
        </label>
        <label class="text-sm">
          {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_OBJECTIVE') }}
          <input v-model="objective" type="text" />
        </label>
        <label class="text-sm">
          {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_INBOX') }}
          <select v-model="inboxId">
            <option :value="null">
              {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_INBOX_NONE') }}
            </option>
            <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
              {{ inbox.name }}
            </option>
          </select>
        </label>
      </template>

      <template v-else>
        <label class="text-sm">
          {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_TEMPLATE') }}
          <select v-model="templateId">
            <option :value="null">
              {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_TEMPLATE_PICK') }}
            </option>
            <option
              v-for="template in templates"
              :key="template.id"
              :value="template.id"
            >
              {{ template.name }}
            </option>
          </select>
        </label>
        <p class="text-xs text-amber-600 dark:text-amber-400 mt-1">
          {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_REPLACE_HINT') }}
        </p>
      </template>

      <p v-if="error" class="text-xs text-red-600 dark:text-red-400 mt-3">
        {{ error }}
      </p>

      <div class="flex justify-end gap-2 mt-6">
        <woot-button variant="clear" @click="$emit('close')">
          {{ $t('TRACKING_ASSISTANT_VIEW.CANCEL') }}
        </woot-button>
        <woot-button
          :is-disabled="!canSave"
          :is-loading="isSaving"
          @click="submit"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.SAVE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
