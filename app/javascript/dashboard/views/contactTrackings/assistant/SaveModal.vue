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
//
// EL CALENDARIO (24/09/2026): si el Entrenamiento agenda (@agendar_calendar), se
// elige acá con qué cuenta de Google. Antes era un aviso pasajero después de guardar
// y un agente quedó sin calendario: elegía la ruta de agendar y no ofrecía horarios.
// ============================================================================
export default {
  props: {
    show: { type: Boolean, default: false },
    templates: { type: Array, default: () => [] },
    inboxes: { type: Array, default: () => [] },
    // El canal elegido arriba del chat: es con el que se probó, así que se propone.
    defaultInboxId: { type: Number, default: null },
    isSaving: { type: Boolean, default: false },
    error: { type: String, default: '' },
    proposal: { type: Object, default: null },
    // El Agente IA del que vino el borrador, si vino de uno.
    editingTemplate: { type: Object, default: null },
    // El Entrenamiento usa @agendar_calendar: sin calendario no agenda nada.
    needsCalendar: { type: Boolean, default: false },
    // Las cuentas de Google conectadas: [{ id, google_email, user_name }].
    calendarIntegrations: { type: Array, default: () => [] },
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
      calendarIds: [],
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
    // Si agenda y la cuenta tiene con qué, hay que elegir al menos un calendario.
    calendarMissing() {
      return (
        this.needsCalendar &&
        this.calendarIntegrations.length > 0 &&
        !this.calendarIds.length
      );
    },
    canSave() {
      if (this.calendarMissing) return false;
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
      if (!value) return;
      this.applyProposal();
      if (!this.inboxId && this.defaultInboxId)
        this.inboxId = this.defaultInboxId;
      // Si el borrador vino de un agente existente, lo natural es REEMPLAZARLO.
      // Abrir en "crear nuevo" dejaba dos agentes casi iguales y el original
      // roto — que es justo lo que la persona vino a arreglar.
      if (this.editingTemplate) {
        this.mode = 'replace';
        this.templateId = this.editingTemplate.id;
      }
      this.preselectCalendars();
    },
    // Al reemplazar, los calendarios que ya tiene ese agente.
    templateId() {
      this.preselectCalendars();
    },
    calendarIntegrations() {
      this.preselectCalendars();
    },
  },
  methods: {
    applyProposal() {
      if (!this.proposal) return;
      if (!this.name) this.name = this.proposal.name || '';
      if (!this.objective) this.objective = this.proposal.objective || '';
      if (!this.aiContext) this.aiContext = this.proposal.ai_context || '';
    },
    preselectCalendars() {
      if (!this.needsCalendar) return;
      const agente =
        this.mode === 'replace'
          ? this.templates.find(t => t.id === this.templateId)
          : null;
      const actuales = (agente?.calendar_integration_ids || []).map(Number);
      if (actuales.length) {
        this.calendarIds = actuales;
        return;
      }
      if (!this.calendarIds.length && this.calendarIntegrations.length === 1) {
        this.calendarIds = [this.calendarIntegrations[0].id];
      }
    },
    toggleCalendar(id) {
      this.calendarIds = this.calendarIds.includes(id)
        ? this.calendarIds.filter(c => c !== id)
        : [...this.calendarIds, id];
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
        calendarIntegrationIds: this.needsCalendar ? this.calendarIds : null,
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
        <p
          v-if="editingTemplate"
          class="text-xs text-slate-600 dark:text-slate-400 mb-2"
        >
          {{
            $t('TRACKING_ASSISTANT_VIEW.SAVE_FROM_TEMPLATE', {
              name: editingTemplate.name,
            })
          }}
        </p>
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
        <p class="text-xs text-amber-800 dark:text-amber-800 mt-1">
          {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_REPLACE_HINT') }}
        </p>
      </template>

      <!-- El calendario: solo si el Entrenamiento agenda. -->
      <div
        v-if="needsCalendar"
        class="flex flex-col gap-2 p-3 mt-4 border rounded-lg border-slate-200 dark:border-slate-600"
      >
        <p class="!m-0 text-sm font-medium text-slate-800 dark:text-slate-100">
          {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_CALENDAR') }}
        </p>
        <p
          v-if="!calendarIntegrations.length"
          class="!m-0 text-xs text-amber-800 dark:text-amber-800"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_CALENDAR_NONE') }}
        </p>
        <template v-else>
          <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
            {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_CALENDAR_HINT') }}
          </p>
          <label
            v-for="integration in calendarIntegrations"
            :key="integration.id"
            class="flex items-center gap-2 !m-0 text-sm cursor-pointer"
          >
            <input
              type="checkbox"
              class="!m-0"
              :checked="calendarIds.includes(integration.id)"
              @change="toggleCalendar(integration.id)"
            />
            {{ integration.user_name }}
            <span class="text-xs text-slate-500 dark:text-slate-400">
              {{ integration.google_email }}
            </span>
          </label>
          <p
            v-if="calendarMissing"
            class="!m-0 text-xs text-red-600 dark:text-red-400"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_CALENDAR_REQUIRED') }}
          </p>
        </template>
      </div>

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
