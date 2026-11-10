<!--
  Seguimiento IA — el formulario corto de «Delegar a agente» en el caso: qué lograr,
  indicaciones, cuándo empezar, cuánto insistir y qué hacer al terminar. El resto lo
  decide el agente (AiFollowUps::Runner).
-->
<script>
import { useAlert } from 'dashboard/composables';
import AiFollowUpsAPI from 'dashboard/api/aiFollowUps';

const T = 'ASSISTANT.AI_FOLLOW_UP';

export default {
  name: 'AiFollowUpModal',
  props: {
    show: { type: Boolean, default: false },
    ticket: { type: Object, default: null }, // sin caso: desde el panel de la conversación
    conversationId: { type: [Number, String], default: null },
    // Ficha del contacto: sus conversaciones [{ id (display_id), label }] para elegir en cuál.
    conversations: { type: Array, default: null },
    // Contacto sin conversaciones: se elige la bandeja [{ id, name }] y al delegar se abre
    // la conversación ahí (AiFollowUps::ConversationOpener).
    newContactId: { type: Number, default: null },
    inboxes: { type: Array, default: null },
  },
  // legacy: «Vista anterior» — el padre cierra esta y abre la del agente de seguimiento de siempre.
  emits: ['close', 'created', 'legacy'],
  data() {
    return {
      objective: '',
      instructions: '',
      startMode: 'now',
      startsAt: '',
      maxAttempts: 3,
      intervalValue: 1,
      intervalUnit: 'days',
      onFinish: 'notify',
      units: ['minutes', 'hours', 'days'],
      // Plantilla de WhatsApp para reabrir la ventana de 24 h ('' = el agente elige).
      chosenId: this.conversationId || this.conversations?.[0]?.id || null,
      chosenInboxId: this.inboxes?.[0]?.id || null,
      template: '',
      templates: [],
      isWhatsapp: false,
      // Lo que consulta: respuestas predefinidas (si hay) y la nota IA del contacto.
      canned: false,
      aiNote: null,
      contactId: null,
      busy: false,
      error: '',
    };
  },
  computed: {
    // El enlace a la ficha del contacto, para editar su nota IA.
    contactLink() {
      return this.contactId
        ? `/app/accounts/${this.$route.params.accountId}/contacts/${this.contactId}`
        : '';
    },
    // Lo que va al servidor para plantillas y contexto: la conversación o contacto + bandeja.
    target() {
      if (this.newContactId) {
        return this.chosenInboxId
          ? { contact_id: this.newContactId, inbox_id: this.chosenInboxId }
          : null;
      }
      return this.chosenId;
    },
    pickedTemplate() {
      return this.templates.find(tp => this.templateKey(tp) === this.template);
    },
  },
  watch: {
    chosenInboxId() {
      this.template = '';
      this.loadTemplates();
      this.loadContext();
    },
    chosenId() {
      this.template = '';
      this.loadTemplates();
      this.loadContext();
    },
  },
  mounted() {
    this.loadTemplates();
    this.loadContext();
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    templateKey(tp) {
      return `${tp.name}|${tp.language}`;
    },
    async loadTemplates() {
      try {
        if (!this.target) return;
        const { data } = await AiFollowUpsAPI.templates(this.target);
        this.isWhatsapp = data.whatsapp;
        this.templates = data.payload || [];
      } catch {
        this.templates = [];
      }
    },
    async loadContext() {
      if (!this.target) return;
      try {
        const { data } = await AiFollowUpsAPI.context(this.target);
        this.canned = data.canned;
        this.aiNote = data.ai_note;
        this.contactId = data.contact_id;
      } catch {
        this.canned = false;
        this.aiNote = null;
      }
    },
    async submit() {
      this.error = '';
      if (!this.objective.trim()) {
        this.error = this.t('NEED_OBJECTIVE');
        return;
      }
      this.busy = true;
      try {
        const { data } = await AiFollowUpsAPI.create({
          case_id: this.ticket?.id || null,
          ...(this.newContactId
            ? { contact_id: this.newContactId, inbox_id: this.chosenInboxId }
            : { conversation_id: this.chosenId }),
          objective: this.objective.trim(),
          instructions: this.instructions.trim(),
          starts_at:
            this.startMode === 'at' && this.startsAt
              ? new Date(this.startsAt).toISOString()
              : null,
          max_attempts: Number(this.maxAttempts),
          interval_value: Number(this.intervalValue),
          interval_unit: this.intervalUnit,
          on_finish: this.onFinish,
          template_name: this.pickedTemplate?.name || null,
          template_language: this.pickedTemplate?.language || null,
        });
        useAlert(this.t('CREATED'));
        this.$emit('created', data.payload);
      } catch (e) {
        this.error = e.response?.data?.error || this.t('FAILED');
      } finally {
        this.busy = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="medium">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="t('TITLE')"
        :header-content="t('INTRO')"
      />
      <form class="flex flex-col gap-4 px-8 pb-8" @submit.prevent="submit">
        <label v-if="newContactId" class="text-sm">
          {{ t('NEW_CONVERSATION_INBOX') }}
          <select v-model="chosenInboxId" class="!mb-0">
            <option v-for="ib in inboxes" :key="ib.id" :value="ib.id">
              {{ ib.name }}
            </option>
          </select>
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ t('NEW_CONVERSATION_HINT') }}
          </span>
        </label>
        <label v-if="conversations && conversations.length" class="text-sm">
          {{ t('CONVERSATION') }}
          <select v-model="chosenId" class="!mb-0">
            <option v-for="c in conversations" :key="c.id" :value="c.id">
              {{ c.label }}
            </option>
          </select>
        </label>
        <label class="text-sm">
          {{ t('OBJECTIVE') }}
          <textarea
            v-model="objective"
            rows="2"
            class="!mb-0"
            :placeholder="t('OBJECTIVE_PLACEHOLDER')"
          />
        </label>
        <label class="text-sm">
          {{ t('INSTRUCTIONS') }}
          <textarea
            v-model="instructions"
            rows="4"
            class="!mb-0"
            :placeholder="t('INSTRUCTIONS_PLACEHOLDER')"
          />
        </label>
        <div v-if="aiNote" class="flex flex-col gap-1 text-sm">
          <span class="flex items-center gap-2">
            {{ t('AI_NOTE') }}
            <a
              v-if="contactLink"
              :href="contactLink"
              target="_blank"
              rel="noopener noreferrer"
              class="text-xs text-woot-600 hover:underline"
            >
              {{ t('AI_NOTE_EDIT') }}
            </a>
          </span>
          <p
            class="max-h-24 p-2 m-0 overflow-y-auto text-xs whitespace-pre-line rounded-md bg-slate-50 dark:bg-slate-800 text-slate-600 dark:text-slate-300"
          >
            {{ aiNote.content }}
          </p>
        </div>
        <p v-else-if="contactId" class="m-0 text-xs text-slate-500">
          {{ t('AI_NOTE_NONE') }}
          <a
            :href="contactLink"
            target="_blank"
            rel="noopener noreferrer"
            class="text-woot-600 hover:underline"
          >
            {{ t('AI_NOTE_ADD') }}
          </a>
        </p>
        <p
          v-if="contactId"
          class="m-0 text-xs"
          :class="canned ? 'text-slate-500' : 'text-amber-600'"
        >
          {{ canned ? t('SOURCES_CANNED') : t('SOURCES_NONE') }}
        </p>
        <div class="flex flex-col gap-1 text-sm">
          {{ t('START') }}
          <div class="flex items-center gap-4">
            <label class="flex items-center gap-1">
              <input v-model="startMode" type="radio" value="now" />
              {{ t('START_NOW') }}
            </label>
            <label class="flex items-center gap-1">
              <input v-model="startMode" type="radio" value="at" />
              {{ t('START_AT') }}
            </label>
            <input
              v-if="startMode === 'at'"
              v-model="startsAt"
              type="datetime-local"
              class="!mb-0 h-9 flex-1"
            />
          </div>
        </div>
        <div class="flex flex-wrap items-center gap-2 text-sm">
          {{ t('ATTEMPTS') }}
          <input
            v-model="maxAttempts"
            type="number"
            min="1"
            max="10"
            class="!mb-0 h-9 !w-16"
          />
          {{ t('ATTEMPTS_SUFFIX') }} · {{ t('EVERY') }}
          <input
            v-model="intervalValue"
            type="number"
            min="1"
            class="!mb-0 h-9 !w-16"
          />
          <select v-model="intervalUnit" class="!mb-0 !h-9 !w-28 !py-1">
            <option v-for="u in units" :key="u" :value="u">
              {{ t(`UNITS.${u}`) }}
            </option>
          </select>
        </div>
        <label class="text-sm">
          {{ t('ON_FINISH') }}
          <select v-model="onFinish" class="!mb-0">
            <option value="notify">{{ t('ON_FINISH_NOTIFY') }}</option>
            <option value="assign">{{ t('ON_FINISH_ASSIGN') }}</option>
          </select>
        </label>
        <label v-if="isWhatsapp" class="text-sm">
          {{ t('TEMPLATE') }}
          <select v-model="template" class="!mb-0">
            <option value="">{{ t('TEMPLATE_AUTO') }}</option>
            <option
              v-for="tp in templates"
              :key="templateKey(tp)"
              :value="templateKey(tp)"
            >
              {{ tp.name }} ({{ tp.language }})
            </option>
          </select>
          <span class="block mt-1 text-xs text-slate-500">
            {{
              pickedTemplate
                ? pickedTemplate.body
                : templates.length
                ? t('TEMPLATE_HELP', { n: templates.length })
                : t('TEMPLATE_NONE')
            }}
          </span>
        </label>
        <p v-if="error" class="m-0 text-sm text-red-600">{{ error }}</p>
        <div class="flex items-center justify-end gap-2">
          <woot-button
            v-if="!newContactId"
            v-tooltip="t('LEGACY_HINT')"
            type="button"
            variant="link"
            color-scheme="secondary"
            size="small"
            class="mr-auto"
            @click="$emit('legacy', chosenId)"
          >
            {{ t('LEGACY') }}
          </woot-button>
          <woot-button
            type="button"
            variant="clear"
            color-scheme="secondary"
            @click="$emit('close')"
          >
            {{ t('CANCEL') }}
          </woot-button>
          <woot-button type="submit" :is-loading="busy" :disabled="busy">
            {{ t('SUBMIT') }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>
