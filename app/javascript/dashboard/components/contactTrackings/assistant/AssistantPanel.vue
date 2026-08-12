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

export default {
  components: { LintBadges },
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
    };
  },
  computed: {
    modes() {
      return ['interview', 'audit', 'tweak'];
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
    canSave() {
      return Boolean(this.draft.name && this.draft.objective);
    },
  },
  mounted() {
    this.openSession();
  },
  methods: {
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
    // Cambiar de modo abre una conversación nueva: el guion y el encuadre son otros.
    async onModeChange(mode) {
      if (mode === this.mode) return;
      this.mode = mode;
      this.messages = [];
      this.proposals = [];
      await this.openSession();
    },
    absorb(data) {
      this.sessionId = data.id;
      this.messages = data.messages || [];
      this.draft = data.draft || {};
      this.proposals = data.proposals || [];
      this.steps = data.steps || this.steps;
      this.step = data.step;
      if (data.turn) {
        this.findings = data.turn.findings || [];
        this.error = data.turn.error || null;
      }
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
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <!-- Modos -->
    <div class="flex items-center gap-2 pb-3">
      <woot-button
        v-for="option in modes"
        :key="option"
        size="small"
        :variant="mode === option ? 'smooth' : 'clear'"
        @click.prevent="onModeChange(option)"
      >
        {{ $t(`AI_AGENT_ASSISTANT.CHAT.MODE_${option.toUpperCase()}`) }}
      </woot-button>
      <span
        v-if="showsProgress"
        class="ml-auto text-xs text-slate-500 dark:text-slate-400"
      >
        {{
          $t('AI_AGENT_ASSISTANT.CHAT.PROGRESS', {
            current: stepIndex + 1,
            total: steps.length,
          })
        }}
      </span>
    </div>

    <div class="flex flex-1 min-h-0 gap-4">
      <!-- Conversación -->
      <div class="flex flex-col flex-1 min-w-0">
        <div class="flex-1 min-h-0 pr-2 overflow-y-auto">
          <div
            v-for="(message, index) in messages"
            :key="index"
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

        <div class="flex items-end gap-2 pt-3">
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
          <woot-button
            v-else
            size="small"
            :is-loading="isSaving"
            :is-disabled="!canSave"
            :title="canSave ? '' : $t('AI_AGENT_ASSISTANT.CHAT.SAVE_BLOCKED')"
            @click.prevent="onSave"
          >
            {{ $t('AI_AGENT_ASSISTANT.CHAT.SAVE') }}
          </woot-button>
        </div>
      </div>
    </div>
  </div>
</template>
