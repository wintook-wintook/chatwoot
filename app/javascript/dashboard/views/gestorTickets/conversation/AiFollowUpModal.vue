<!--
  Seguimiento IA — el formulario corto de «Delegar a agente» en el caso: qué lograr,
  indicaciones, cuándo empezar, cuánto insistir y qué hacer al terminar. El resto lo
  decide el agente (AiFollowUps::Runner).
  Si ya corre uno en la conversación, abre con lo suyo y al guardar lo reemplaza (arranca por
  omisión en su siguiente intento). «Usar plantilla» carga una plantilla de seguimiento (o un
  ejemplo de arranque si la cuenta no tiene) y «Guardar como plantilla» la guarda.
-->
<script>
import { useAlert } from 'dashboard/composables';
import AiFollowUpsAPI from 'dashboard/api/aiFollowUps';
import AiFollowUpPresetsAPI from 'dashboard/api/aiFollowUpPresets';
import { STARTERS, STARTER_KEYS } from './followUpStarters';

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
    // La empresa tiene Agentes a medida: arriba se elige quién da el seguimiento.
    customAgents: { type: Boolean, default: false },
  },
  // legacy: eligió «Un agente a medida» — el padre cierra esta y abre la de esos agentes (otro motor).
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
      // Plantillas de seguimiento: la elegida ('' ninguna; 'starter:KEY' un ejemplo de arranque).
      presets: [],
      presetChoice: '',
      presetName: '',
      askName: false,
      savingPreset: false,
      // El Seguimiento IA que ya corre en la conversación (se reemplaza al guardar).
      live: null,
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
    pickedPreset() {
      return this.presets.find(p => String(p.id) === String(this.presetChoice));
    },
    // Sin plantillas guardadas se ofrecen los ejemplos de arranque.
    starterOptions() {
      return this.presets.length ? [] : STARTER_KEYS;
    },
    // Lo que se guarda como plantilla (la receta, sin conversación ni fecha).
    presetFields() {
      return {
        objective: this.objective.trim(),
        instructions: this.instructions.trim(),
        max_attempts: Number(this.maxAttempts),
        interval_value: Number(this.intervalValue),
        interval_unit: this.intervalUnit,
        on_finish: this.onFinish,
        template_name: this.pickedTemplate?.name || null,
        template_language: this.pickedTemplate?.language || null,
      };
    },
    // Cargó una plantilla suya (o es admin) y le cambió algo: se puede actualizar.
    canUpdatePreset() {
      const p = this.pickedPreset;
      if (!p || !p.editable) return false;
      const f = this.presetFields;
      return (
        p.objective !== f.objective ||
        (p.instructions || '') !== f.instructions ||
        p.max_attempts !== f.max_attempts ||
        p.interval_value !== f.interval_value ||
        p.interval_unit !== f.interval_unit ||
        p.on_finish !== f.on_finish ||
        (p.template_name || null) !== f.template_name
      );
    },
    replaceNotice() {
      if (!this.live) return '';
      const next = this.live.next_run_at
        ? this.t('REPLACE_NEXT', { at: this.formatWhen(this.live.next_run_at) })
        : '';
      return this.t('REPLACE_NOTICE', {
        attempts: this.live.attempts || 0,
        max: this.live.max_attempts,
        next,
      });
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
      this.loadLive();
    },
  },
  mounted() {
    this.loadTemplates();
    this.loadContext();
    this.loadPresets();
    this.loadLive();
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
        // Si ya corre uno con plantilla fijada, se marca cuando llegan las de la bandeja.
        const fixed = this.live && this.live.template_name;
        const tp = fixed && this.templates.find(x => x.name === fixed);
        if (tp && !this.template) this.template = this.templateKey(tp);
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
    formatWhen(iso) {
      return new Date(iso).toLocaleString(undefined, {
        weekday: 'short',
        day: 'numeric',
        month: 'short',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    toLocalInput(iso) {
      const d = new Date(iso);
      const pad = n => String(n).padStart(2, '0');
      return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(
        d.getDate()
      )}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
    },
    async loadPresets() {
      try {
        const { data } = await AiFollowUpPresetsAPI.list();
        this.presets = data.payload || [];
      } catch {
        this.presets = [];
      }
    },
    // El que ya corre en la conversación: la ventana abre con lo suyo para cambiarlo.
    async loadLive() {
      this.live = null;
      if (this.newContactId || !this.chosenId) return;
      try {
        const { data } = await AiFollowUpsAPI.forConversation(this.chosenId);
        const live = (data.payload || []).find(f =>
          ['active', 'paused'].includes(f.status)
        );
        if (!live) return;
        this.live = live;
        this.fillFields(live);
        const next = live.next_run_at && new Date(live.next_run_at);
        if (next && next > new Date()) {
          this.startMode = 'at';
          this.startsAt = this.toLocalInput(live.next_run_at);
        }
      } catch {
        this.live = null;
      }
    },
    fillFields(source) {
      this.objective = source.objective || '';
      this.instructions = source.instructions || '';
      this.maxAttempts = source.max_attempts || 3;
      this.intervalValue = source.interval_value || 1;
      this.intervalUnit = source.interval_unit || 'days';
      this.onFinish = source.on_finish || 'notify';
      const tp = this.templates.find(x => x.name === source.template_name);
      this.template = tp ? this.templateKey(tp) : '';
    },
    // «Usar plantilla»: una guardada o un ejemplo de arranque (sus textos van traducidos).
    applyPreset() {
      const choice = String(this.presetChoice || '');
      if (choice.startsWith('starter:')) {
        const key = choice.slice(8);
        this.fillFields({
          ...STARTERS[key],
          objective: this.t(`STARTERS.${key}.OBJECTIVE`),
          instructions: this.t(`STARTERS.${key}.INSTRUCTIONS`),
        });
        this.presetName = this.t(`STARTERS.${key}.NAME`);
        return;
      }
      if (this.pickedPreset) this.fillFields(this.pickedPreset);
    },
    async savePreset() {
      if (!this.presetName.trim() || !this.objective.trim()) return;
      this.savingPreset = true;
      try {
        const { data } = await AiFollowUpPresetsAPI.create({
          name: this.presetName.trim(),
          ...this.presetFields,
        });
        await this.loadPresets();
        this.presetChoice = data.payload.id;
        this.askName = false;
        useAlert(this.t('PRESET_SAVED', { name: data.payload.name }));
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('FAILED'));
      } finally {
        this.savingPreset = false;
      }
    },
    async updatePreset() {
      const p = this.pickedPreset;
      if (!p) return;
      this.savingPreset = true;
      try {
        await AiFollowUpPresetsAPI.update(p.id, this.presetFields);
        await this.loadPresets();
        useAlert(this.t('PRESET_UPDATED', { name: p.name }));
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('FAILED'));
      } finally {
        this.savingPreset = false;
      }
    },
    async deletePreset() {
      const p = this.pickedPreset;
      // eslint-disable-next-line no-alert
      if (!p || !window.confirm(this.t('DELETE_CONFIRM', { name: p.name })))
        return;
      try {
        await AiFollowUpPresetsAPI.delete(p.id);
        this.presetChoice = '';
        await this.loadPresets();
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('FAILED'));
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
          replace: !!this.live,
        });
        useAlert(this.t(this.live ? 'REPLACED' : 'CREATED'));
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
        <!-- Ya corre uno: se cambia (se cancela y arranca este) -->
        <p
          v-if="live"
          class="p-2 m-0 text-sm rounded-md bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-200"
        >
          {{ replaceNotice }}
        </p>
        <!-- Usar plantilla de seguimiento (o un ejemplo de arranque) -->
        <div class="flex flex-col gap-1 text-sm">
          <span>{{ t('PRESET_LABEL') }}</span>
          <div class="flex items-center gap-2">
            <select
              v-model="presetChoice"
              class="!mb-0 flex-1"
              @change="applyPreset"
            >
              <option value="">{{ t('PRESET_NONE') }}</option>
              <option v-for="p in presets" :key="p.id" :value="p.id">
                {{ p.name }}
              </option>
              <option
                v-for="key in starterOptions"
                :key="key"
                :value="`starter:${key}`"
              >
                {{ t(`STARTERS.${key}.NAME`) }} {{ t('STARTER_SUFFIX') }}
              </option>
            </select>
            <woot-button
              v-if="pickedPreset && pickedPreset.editable"
              type="button"
              variant="clear"
              color-scheme="alert"
              size="small"
              icon="delete"
              :title="t('DELETE_PRESET')"
              @click="deletePreset"
            />
          </div>
          <span
            v-if="!presets.length"
            class="text-xs text-slate-500 dark:text-slate-400"
          >
            {{ t('PRESET_EMPTY') }}
          </span>
        </div>
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
        <!-- Guardar lo de arriba como plantilla de seguimiento (o actualizar la cargada) -->
        <div class="flex flex-wrap items-center gap-2 text-sm">
          <template v-if="askName">
            <input
              v-model="presetName"
              type="text"
              class="!mb-0 flex-1 h-9"
              :placeholder="t('PRESET_NAME_PLACEHOLDER')"
            />
            <woot-button
              type="button"
              size="small"
              :is-loading="savingPreset"
              :disabled="!presetName.trim() || !objective.trim()"
              @click="savePreset"
            >
              {{ t('SAVE') }}
            </woot-button>
            <woot-button
              type="button"
              size="small"
              variant="clear"
              color-scheme="secondary"
              @click="askName = false"
            >
              {{ t('CANCEL') }}
            </woot-button>
          </template>
          <template v-else>
            <woot-button
              type="button"
              size="small"
              variant="link"
              icon="save"
              :disabled="!objective.trim()"
              @click="askName = true"
            >
              {{ t('SAVE_PRESET') }}
            </woot-button>
            <woot-button
              v-if="canUpdatePreset"
              type="button"
              size="small"
              variant="link"
              :is-loading="savingPreset"
              @click="updatePreset"
            >
              {{ t('UPDATE_PRESET', { name: pickedPreset.name }) }}
            </woot-button>
          </template>
        </div>
        <p v-if="error" class="m-0 text-sm text-red-600">{{ error }}</p>
        <div class="flex items-center justify-end gap-2">
          <!-- Por omisión es el Seguimiento IA (este formulario); si la empresa tiene agentes a
               medida, este botón abre la ventana de esos (otro motor). -->
          <woot-button
            v-if="customAgents && !newContactId"
            v-tooltip="t('ENGINE.CUSTOM_HINT')"
            type="button"
            variant="link"
            color-scheme="secondary"
            size="small"
            icon="bot-outline"
            class="mr-auto"
            data-test="follow-up-engine-custom"
            @click="$emit('legacy', chosenId)"
          >
            {{ t('ENGINE.CUSTOM') }}
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
            {{ live ? t('REPLACE_SUBMIT') : t('SUBMIT') }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>
