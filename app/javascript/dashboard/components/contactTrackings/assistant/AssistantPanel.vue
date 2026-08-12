<script>
// ================================================================================
// proyecto@ai_agent_assistant - F5
// ================================================================================
// Componente: AssistantPanel
// Descripción: El chat asistente. Conversación a la izquierda, borrador en vivo a
//              la derecha, y las propuestas del último turno con [Aplicar] campo
//              por campo.
//
// Dos usos, el mismo componente:
//   · página propia   → modo entrevista, cierra creando el Agente IA
//   · cajón del editor → modo auditar/ajuste, cierra devolviendo el borrador al
//                        formulario (`embedded`), donde el usuario decide guardar.
//
// El asistente nunca escribe en el Agente IA. Todo lo que produce es borrador.
// ================================================================================
import AiAgentAssistantSessionsAPI from 'dashboard/api/aiAgentAssistantSessions';
import { useAlert } from 'dashboard/composables';
import LintBadges from './LintBadges.vue';
import DirectiveMention from './DirectiveMention.vue';
import AiAgentAssistantAPI from 'dashboard/api/aiAgentAssistant';

export default {
  components: { LintBadges, DirectiveMention },
  props: {
    // interview | audit | tweak
    initialMode: {
      type: String,
      default: 'interview',
    },
    trackingTemplateId: {
      type: [Number, String],
      default: null,
    },
    // Prompt que el usuario trae escrito de fuera (modo auditar).
    initialPrompt: {
      type: String,
      default: '',
    },
    // true dentro del editor: cierra devolviendo el borrador en vez de crear.
    embedded: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['applyDraft', 'created'],
  data() {
    return {
      mode: this.initialMode,
      sessionId: null,
      messages: [],
      draft: {},
      proposals: [],
      steps: [],
      step: null,
      findings: [],
      input: '',
      isSending: false,
      isSaving: false,
      error: null,
      draftName: '',
      capabilities: [], // para la lista que sale al escribir «/»
    };
  },
  computed: {
    modes() {
      return ['interview', 'audit', 'tweak'];
    },
    // Qué significa el estado en el que estás, dicho al lado del selector.
    modeHint() {
      return this.$t(
        `AI_AGENT_ASSISTANT.CHAT.MODE_HINT_${this.mode.toUpperCase()}`
      );
    },
    stepIndex() {
      return this.steps.findIndex(s => s.key === this.step);
    },
    // Solo la entrevista tiene guion; auditar y ajustar no avanzan por pasos.
    showsProgress() {
      return this.mode === 'interview' && this.stepIndex >= 0;
    },
    draftEntries() {
      return Object.entries(this.draft)
        .filter(([, value]) => this.isFilled(value))
        .map(([field, value]) => ({ field, value: this.readable(value) }));
    },
    // Lo que hay escrito tras un «/» al principio de palabra. null = no estamos
    // referenciando ninguna directiva.
    directiveQuery() {
      const match = /(?:^|\s)\/([^\s/]*)$/.exec(this.input);
      return match ? match[1] : null;
    },
    canSave() {
      return Boolean(
        this.draftName.trim() && this.draft.objective && this.draft.inbox_id
      );
    },
    // Qué falta exactamente para poder guardar. Antes solo se veía en un tooltip
    // sobre un botón deshabilitado, o sea: no se veía.
    saveBlockedReason() {
      if (!this.draftName.trim()) {
        return this.$t('AI_AGENT_ASSISTANT.CHAT.NEEDS_NAME');
      }
      if (!this.draft.objective) {
        return this.$t('AI_AGENT_ASSISTANT.CHAT.NEEDS_OBJECTIVE');
      }
      // Un agente sin canal no puede enviar nada: es el agente huérfano número 7 de
      // la cuenta 568. Mejor no dejar crearlo que crearlo muerto.
      if (!this.draft.inbox_id) {
        return this.$t('AI_AGENT_ASSISTANT.CHAT.NEEDS_INBOX');
      }
      return '';
    },
  },
  mounted() {
    this.resumeOrOpen();
    this.loadCapabilities();
  },
  methods: {
    async loadCapabilities() {
      try {
        const { data } = await AiAgentAssistantAPI.getCapabilities({
          inboxId: this.draft.inbox_id,
          trackingTemplateId: this.trackingTemplateId,
        });
        this.capabilities = data.capabilities;
      } catch (e) {
        this.capabilities = [];
      }
    },
    // Sustituye el «/loquesea» a medio escribir por la directiva elegida. Queda en
    // TU mensaje: es una referencia para el asistente, no una inserción en el agente.
    onDirectiveSelect(token) {
      this.input = this.input.replace(/(?:^|\s)\/[^\s/]*$/, match =>
        `${match.startsWith(' ') ? ' ' : ''}${token} `
      );
      this.$refs.composer?.focus();
    },
    // Cerrar el cajón ya no tira el trabajo: si hay una conversación de este mismo
    // Agente IA, se retoma con su borrador intacto.
    async resumeOrOpen() {
      try {
        const { data } = await AiAgentAssistantSessionsAPI.list(
          this.trackingTemplateId
        );
        const last = (data.sessions || [])[0];
        if (last) {
          const { data: session } = await AiAgentAssistantSessionsAPI.get(
            last.id
          );
          this.absorb(session);
          this.mode = session.mode;
          return;
        }
      } catch (e) {
        // Sin historial que retomar se abre una nueva, que es el caso normal.
      }
      await this.openSession();
    },
    async openSession() {
      this.isSending = true;
      this.error = null;
      try {
        const { data } = await AiAgentAssistantSessionsAPI.open({
          mode: this.mode,
          trackingTemplateId: this.trackingTemplateId,
          complementaryPrompt: this.initialPrompt,
        });
        this.absorb(data);
      } catch (e) {
        this.error = 'session_failed';
      } finally {
        this.isSending = false;
      }
    },
    async onSend() {
      const message = this.input.trim();
      if (!message || this.isSending) return;
      this.input = '';
      this.isSending = true;
      this.scrollToBottom();
      try {
        const { data } = await AiAgentAssistantSessionsAPI.send(
          this.sessionId,
          message
        );
        this.absorb(data);
      } catch (e) {
        this.error = 'turn_failed';
      } finally {
        this.isSending = false;
      }
    },
    async onApply(fields) {
      try {
        const { data } = await AiAgentAssistantSessionsAPI.apply(
          this.sessionId,
          fields
        );
        this.absorb(data);
        if (this.embedded) this.$emit('applyDraft', this.draft);
      } catch (e) {
        useAlert(this.$t('AI_AGENT_ASSISTANT.CHAT.APPLY_ERROR'));
      }
    },
    // Cambiar de modo NO abre otra conversación. El borrador es el mismo agente y el
    // hilo anterior es contexto: auditar lo que acabas de armar en la entrevista es
    // justo el caso de uso. Solo cambia el encuadre del siguiente turno.
    // El nombre viaja a la sesión: si no, el siguiente turno lo borraría al refrescar
    // el borrador desde el servidor.
    async onNameChange() {
      if (!this.sessionId) return;
      try {
        const { data } = await AiAgentAssistantSessionsAPI.setDraft(
          this.sessionId,
          {
            name: this.draftName.trim(),
          }
        );
        this.absorb(data);
      } catch (e) {
        // Sin sesión abierta el nombre se queda en el formulario y se manda al crear.
      }
    },
    async onModeSelect() {
      if (!this.sessionId) return;
      try {
        const { data } = await AiAgentAssistantSessionsAPI.setMode(
          this.sessionId,
          this.mode
        );
        this.absorb(data);
      } catch (e) {
        this.error = 'turn_failed';
      }
    },
    // Empezar de cero, cuando de verdad se quiere: es explícito, no un efecto
    // secundario de tocar una pestaña.
    async onNewConversation() {
      this.sessionId = null;
      this.messages = [];
      this.proposals = [];
      this.draft = {};
      this.findings = [];
      await this.openSession();
    },
    absorb(data) {
      this.sessionId = data.id;
      this.messages = data.messages || [];
      const inboxBefore = this.draft.inbox_id;
      this.draft = data.draft || {};
      if (this.draft.name) this.draftName = this.draft.name;
      // @discourse se configura POR INBOX: al fijar el canal cambia lo disponible.
      if (this.draft.inbox_id !== inboxBefore) this.loadCapabilities();
      this.proposals = data.proposals || [];
      this.steps = data.steps || this.steps;
      this.step = data.step;
      if (data.turn) {
        this.findings = data.turn.findings || [];
        this.error = data.turn.error || null;
      }
      this.scrollToBottom();
    },
    // El hilo crece hacia abajo: sin esto la respuesta nueva queda fuera de vista y
    // parece que el asistente no contestó.
    scrollToBottom() {
      this.$nextTick(() => {
        const thread = this.$refs.thread;
        if (thread) thread.scrollTop = thread.scrollHeight;
      });
    },
    // El guardado lo hace el usuario, no el asistente: esto solo manda el borrador
    // por la vía de siempre, marcándolo como venido del chat para el historial.
    async onSave() {
      this.isSaving = true;
      try {
        // La acción del store devuelve el registro, no la respuesta de axios.
        const template = await this.$store.dispatch(
          'trackingTemplates/create',
          {
            tracking_template: { ...this.draft, version_source: 'assistant' },
          }
        );
        useAlert(this.$t('AI_AGENT_ASSISTANT.CHAT.SAVED'));
        this.$emit('created', template);
      } catch (e) {
        useAlert(this.$t('AI_AGENT_ASSISTANT.CHAT.SAVE_ERROR'));
      } finally {
        this.isSaving = false;
      }
    },
    isFilled(value) {
      if (Array.isArray(value)) return value.length > 0;
      return value !== null && value !== undefined && value !== '';
    },
    readable(value) {
      if (Array.isArray(value)) {
        return value
          .map(item =>
            typeof item === 'object' && item !== null
              ? Object.values(item).join(' · ')
              : item
          )
          .join('\n');
      }
      if (typeof value === 'object' && value !== null) {
        return JSON.stringify(value);
      }
      return String(value);
    },
    fieldLabel(field) {
      return this.$t(`AI_AGENT_ASSISTANT.VERSIONS.FIELD.${field}`);
    },
    modeLabel(mode) {
      return this.$t(
        `AI_AGENT_ASSISTANT.CHAT.MODE_${(mode || '').toUpperCase()}`
      );
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <!-- El modo no es un destino al que navegas: es el estado desde el que escribes,
         así que vive junto al mensaje, abajo. Aquí arriba solo el progreso. -->
    <div class="flex items-center gap-2 pb-3">
      <span
        v-if="showsProgress"
        class="text-xs whitespace-nowrap text-slate-500 dark:text-slate-400"
      >
        {{
          $t('AI_AGENT_ASSISTANT.CHAT.PROGRESS', {
            current: stepIndex + 1,
            total: steps.length,
          })
        }}
      </span>
      <woot-button
        size="tiny"
        variant="clear"
        icon="add"
        class="ml-auto"
        @click.prevent="onNewConversation"
      >
        {{ $t('AI_AGENT_ASSISTANT.CHAT.NEW') }}
      </woot-button>
    </div>

    <div class="flex flex-1 min-h-0 gap-4">
      <!-- Conversación -->
      <div class="flex flex-col flex-1 min-w-0">
        <div ref="thread" class="flex-1 min-h-0 pr-2 overflow-y-auto">
          <div v-for="(message, index) in messages" :key="index">
            <!-- Marca de cambio de encuadre: el hilo sigue, no se corta -->
            <div
              v-if="message.role === 'system'"
              class="flex items-center gap-2 my-4"
            >
              <span class="flex-1 h-px bg-woot-200 dark:bg-woot-700" />
              <span
                class="px-3 py-1 text-xs font-semibold text-center rounded-full bg-woot-50 text-woot-700 dark:bg-woot-800/40 dark:text-woot-200"
              >
                {{
                  $t('AI_AGENT_ASSISTANT.CHAT.MODE_SWITCHED', {
                    mode: modeLabel(message.mode),
                  })
                }}
              </span>
              <span class="flex-1 h-px bg-woot-200 dark:bg-woot-700" />
            </div>
            <div
              v-else
              class="mb-3"
              :class="message.role === 'user' ? 'text-right' : 'text-left'"
            >
              <p
                class="inline-block max-w-[85%] px-3 py-2 m-0 text-sm text-left whitespace-pre-wrap rounded-lg"
                :class="
                  message.role === 'user'
                    ? 'bg-woot-50 text-slate-800 dark:bg-woot-800/40 dark:text-slate-100'
                    : 'bg-slate-50 text-slate-700 dark:bg-slate-800 dark:text-slate-200'
                "
              >
                {{ message.content }}
              </p>
            </div>
          </div>

          <p
            v-if="isSending"
            class="text-xs text-slate-400 dark:text-slate-500"
          >
            {{ $t('AI_AGENT_ASSISTANT.CHAT.THINKING') }}
          </p>

          <!-- Sin integración de OpenAI el asistente no puede hablar: se dice, no se
               simula un turno vacío. -->
          <div
            v-if="error"
            class="px-4 py-3 text-xs border rounded-lg bg-amber-50 border-amber-200 dark:bg-amber-800/20 dark:border-amber-800 text-amber-800 dark:text-amber-200"
          >
            {{ $t(`AI_AGENT_ASSISTANT.CHAT.ERROR_${error.toUpperCase()}`) }}
          </div>
        </div>

        <div class="pt-3">
          <!-- El estado desde el que hablas. Cambiarlo no corta la conversación. -->
          <div class="flex flex-wrap items-center gap-2 mb-2">
            <label
              class="mb-0 text-xs font-semibold text-slate-700 dark:text-slate-200"
            >
              {{ $t('AI_AGENT_ASSISTANT.CHAT.MODE_LABEL') }}
            </label>
            <select
              v-model="mode"
              class="h-8 py-0 mb-0 text-sm w-36"
              @change="onModeSelect"
            >
              <option v-for="option in modes" :key="option" :value="option">
                {{ modeLabel(option) }}
              </option>
            </select>
            <span
              class="text-xs truncate whitespace-nowrap text-slate-600 dark:text-slate-300"
            >
              {{ modeHint }}
            </span>
          </div>
          <div class="flex items-end gap-2">
            <textarea
              v-model="input"
              rows="2"
              class="mb-0 text-sm"
              :placeholder="$t('AI_AGENT_ASSISTANT.CHAT.PLACEHOLDER')"
              @keydown.enter.exact.prevent="onSend"
            />
            <woot-button
              :is-loading="isSending"
              :is-disabled="!input.trim()"
              @click.prevent="onSend"
            >
              {{ $t('AI_AGENT_ASSISTANT.CHAT.SEND') }}
            </woot-button>
          </div>
        </div>
      </div>

      <!-- Borrador en vivo -->
      <div
        class="flex flex-col w-2/5 min-w-0 pl-4 border-l border-slate-200 dark:border-slate-700"
      >
        <div class="flex-1 min-h-0 overflow-y-auto">
          <!-- Propuestas del último turno: se aplican por campo, nunca en bloque -->
          <template v-if="proposals.length">
            <p
              class="mb-2 text-xs font-semibold text-slate-500 dark:text-slate-400"
            >
              {{ $t('AI_AGENT_ASSISTANT.CHAT.PROPOSALS') }}
            </p>
            <div
              v-for="proposal in proposals"
              :key="proposal.field"
              class="px-3 py-2 mb-2 text-xs border rounded-lg bg-woot-25 border-woot-200 dark:bg-woot-800/20 dark:border-woot-700"
            >
              <div class="flex items-center gap-2">
                <span class="font-semibold text-slate-700 dark:text-slate-200">
                  {{ fieldLabel(proposal.field) }}
                </span>
                <woot-button
                  size="tiny"
                  class="ml-auto"
                  @click.prevent="onApply([proposal.field])"
                >
                  {{ $t('AI_AGENT_ASSISTANT.CHAT.APPLY') }}
                </woot-button>
              </div>
              <p
                class="mt-1 mb-0 whitespace-pre-wrap text-slate-600 dark:text-slate-300"
              >
                {{ readable(proposal.value) }}
              </p>
              <p
                v-if="proposal.rationale"
                class="mt-1 mb-0 italic text-slate-500 dark:text-slate-400"
              >
                {{ proposal.rationale }}
              </p>
            </div>
            <woot-button
              size="tiny"
              variant="clear"
              class="mb-4"
              @click.prevent="onApply(proposals.map(p => p.field))"
            >
              {{ $t('AI_AGENT_ASSISTANT.CHAT.APPLY_ALL') }}
            </woot-button>
          </template>

          <p
            class="mb-2 text-xs font-semibold text-slate-500 dark:text-slate-400"
          >
            {{ $t('AI_AGENT_ASSISTANT.CHAT.DRAFT') }}
          </p>
          <p
            v-if="!draftEntries.length"
            class="text-xs text-slate-400 dark:text-slate-500"
          >
            {{ $t('AI_AGENT_ASSISTANT.CHAT.DRAFT_EMPTY') }}
          </p>
          <div v-for="entry in draftEntries" :key="entry.field" class="mb-3">
            <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
              {{ fieldLabel(entry.field) }}
            </p>
            <p
              class="m-0 text-xs whitespace-pre-wrap text-slate-700 dark:text-slate-200"
            >
              {{ entry.value }}
            </p>
          </div>
        </div>

        <!-- El asistente valida su propia propuesta antes de enseñarla -->
        <LintBadges
          class="pt-3 mt-3 border-t border-slate-200 dark:border-slate-700"
          :findings="findings"
        />

        <div class="flex items-center gap-2 pt-3">
          <woot-button
            v-if="embedded"
            variant="smooth"
            size="small"
            :is-disabled="!draftEntries.length"
            @click.prevent="$emit('applyDraft', draft)"
          >
            {{ $t('AI_AGENT_ASSISTANT.CHAT.TO_FORM') }}
          </woot-button>
          <template v-else>
            <woot-button
              size="small"
              :is-loading="isSaving"
              :is-disabled="!canSave"
              @click.prevent="onSave"
            >
              {{ $t('AI_AGENT_ASSISTANT.CHAT.SAVE') }}
            </woot-button>
            <span
              v-if="saveBlockedReason"
              class="text-xs text-amber-700 dark:text-amber-300"
            >
              {{ saveBlockedReason }}
            </span>
          </template>
        </div>
      </div>
    </div>
  </div>
</template>
