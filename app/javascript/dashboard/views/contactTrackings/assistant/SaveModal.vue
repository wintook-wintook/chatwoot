<script>
// proyecto@asistente_agentes_ia — F4
// ============================================================================
// Guardar el borrador: como Agente IA nuevo, o pisando el de uno existente.
//
// Reemplazar es la acción peligrosa —hay agentes en producción— así que se
// elige explícitamente y se avisa que se guarda una copia del anterior.
//
// LOS CAMPOS VIENEN PROPUESTOS, NO VACÍOS:
//   El asistente acaba de entrevistar sobre qué hace el agente, así que pedir
//   que se reescriba el nombre y el objetivo es pedir un resumen de lo que se
//   acaba de decir. Y `objetivo` es obligatorio: vacío es un muro.
//   Un nombre propuesto y equivocado se ve y se corrige; el campo vacío frena.
//
//   El CONTEXTO es distinto y por eso puede llegar vacío: el asistente conoce
//   las fuentes de la cuenta pero NO su negocio. Ese campo entra al prompt como
//   "BASE DE CONOCIMIENTO" y el agente lo cita como cierto, así que solo lleva
//   lo que la persona dijo en la conversación. Vacío es una respuesta válida.
// ============================================================================
export default {
  props: {
    show: { type: Boolean, default: false },
    templates: { type: Array, default: () => [] },
    inboxes: { type: Array, default: () => [] },
    isSaving: { type: Boolean, default: false },
    error: { type: String, default: '' },
    proposal: { type: Object, default: null },
  },
  emits: ['close', 'save'],
  data() {
    return {
      mode: 'create',
      name: '',
      objective: '',
      aiContext: '',
      inboxId: null,
      templateId: null,
    };
  },
  computed: {
    // El nombre es único por cuenta: proponer uno que ya existe hace fallar el
    // guardado con un error del modelo, que es peor que avisarlo acá.
    nameTaken() {
      const needle = this.name.trim().toLowerCase();
      if (!needle) return false;
      return this.templates.some(t => (t.name || '').toLowerCase() === needle);
    },
    canSave() {
      if (this.mode === 'create') {
        return (
          this.name.trim().length >= 2 &&
          this.objective.trim().length >= 5 &&
          !this.nameTaken
        );
      }
      return Boolean(this.templateId);
    },
  },
  watch: {
    // Al abrirse se precargan las propuestas. No se pisan si la persona ya
    // escribió algo: lo suyo gana sobre lo propuesto.
    show(value) {
      if (value) this.applyProposal();
    },
  },
  methods: {
    applyProposal() {
      if (!this.proposal) return;
      if (!this.name) this.name = this.proposal.name || '';
      if (!this.objective) this.objective = this.proposal.objective || '';
      if (!this.aiContext) this.aiContext = this.proposal.ai_context || '';
    },
    submit() {
      if (!this.canSave || this.isSaving) return;
      this.$emit('save', {
        mode: this.mode,
        name: this.name.trim(),
        objective: this.objective.trim(),
        aiContext: this.aiContext.trim(),
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
        <p
          v-if="nameTaken"
          class="text-xs text-red-600 dark:text-red-400 -mt-2"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_NAME_TAKEN') }}
        </p>
        <label class="text-sm">
          {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_OBJECTIVE') }}
          <input v-model="objective" type="text" />
        </label>
        <label class="text-sm">
          {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_CONTEXT') }}
          <textarea v-model="aiContext" rows="3" />
        </label>
        <p class="text-xs text-slate-500 dark:text-slate-400 -mt-2 mb-2">
          {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_CONTEXT_HINT') }}
        </p>

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
