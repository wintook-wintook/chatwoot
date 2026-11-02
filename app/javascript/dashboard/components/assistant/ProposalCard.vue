<!--
  Asistente (Dali) — tarjeta de una acción que el asistente propone. Trae los datos
  ya llenos y se pueden cambiar antes de «Confirmar»; nada se hace sin ese clic.
  El borrador no se ejecuta: se copia.
-->
<script>
import AssistantAPI from 'dashboard/api/platformAssistant';

const T = 'ASSISTANT.PROPOSAL';
const ICONS = {
  note: 'document',
  task: 'checkmark-circle',
  meeting: 'calendar-clock',
  scheduled_message: 'clock',
  draft: 'edit',
  delegate: 'bot',
  tracking_action: 'bot',
  // D4 — casos y clientes
  create_case: 'add',
  move_stage: 'arrow-swap',
  outcome: 'checkmark-circle',
  postpone: 'calendar-clock',
  resume_case: 'arrow-clockwise',
  update_opportunity: 'edit',
  create_contact: 'person-add',
};

// ISO (con zona) ↔ valor de <input type="datetime-local"> en hora local.
const toLocalInput = iso => {
  if (!iso) return '';
  const d = new Date(iso);
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(
    d.getHours()
  )}:${pad(d.getMinutes())}`;
};
const toIso = local => (local ? new Date(local).toISOString() : null);

export default {
  name: 'ProposalCard',
  props: {
    proposal: { type: Object, required: true },
  },
  emits: ['updated', 'navigate'],
  data() {
    const p = this.proposal.payload || {};
    return {
      form: {
        title: p.title || '',
        content: p.content || '',
        due_at: toLocalInput(p.due_at),
        starts_at: toLocalInput(p.starts_at),
        ends_at: toLocalInput(p.ends_at),
        send_at: toLocalInput(p.send_at),
        location: p.location || '',
        // D3 — delegar seguimiento
        objective: p.objective || '',
        instruction: p.instruction || '',
        first_at: toLocalInput(p.starts_at),
        max_attempts: p.max_attempts || 3,
        interval_value: p.interval_value || 1,
        interval_unit: p.interval_unit || 'days',
        // D4
        column_id: p.column_id || '',
        reason_id: p.reason_id || '',
        note: p.note || '',
        pending_tasks: p.pending_tasks || 'keep',
        until: p.until || '',
        name: p.name || '',
        email: p.email || '',
        phone: p.phone || '',
      },
      units: ['minutes', 'hours', 'days'],
      busy: false,
      error: '',
      copied: false,
    };
  },
  computed: {
    type() {
      return this.proposal.type;
    },
    icon() {
      return ICONS[this.type] || 'add';
    },
    labels() {
      return this.proposal.labels || {};
    },
    options() {
      return this.labels.options || {};
    },
    // Etapas a las que se puede mover (las de resultado se cierran con su tarjeta).
    stages() {
      return (this.options.stages || []).filter(s => !s.outcome);
    },
    pending() {
      return this.proposal.status === 'pending';
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    // Solo los campos que se ven en la tarjeta de ese tipo.
    payload() {
      const f = this.form;
      return {
        note: { content: f.content },
        task: { title: f.title, due_at: toIso(f.due_at) },
        meeting: {
          title: f.title,
          starts_at: toIso(f.starts_at),
          ends_at: toIso(f.ends_at),
          location: f.location,
        },
        scheduled_message: { content: f.content, send_at: toIso(f.send_at) },
        draft: { content: f.content },
        delegate: {
          objective: f.objective,
          instruction: f.instruction,
          starts_at: toIso(f.first_at),
          max_attempts: Number(f.max_attempts),
          interval_value: Number(f.interval_value),
          interval_unit: f.interval_unit,
        },
        tracking_action: {},
        create_case: { title: f.title },
        move_stage: { column_id: f.column_id },
        outcome: {
          reason_id: f.reason_id || null,
          note: f.note,
          pending_tasks: f.pending_tasks,
        },
        postpone: { until: f.until, reason_id: f.reason_id || null },
        resume_case: {},
        update_opportunity: {},
        create_contact: { name: f.name, email: f.email, phone: f.phone },
      }[this.type];
    },
    // «TYPE» → «Tipo»; el valor del resultado (won…) también se traduce.
    rowLabel(key) {
      return this.$te(`ASSISTANT.PROPOSAL.ROWS.${key}`)
        ? this.t(`ROWS.${key}`)
        : key;
    },
    rowValue(key, value) {
      if (key === 'OUTCOME') return this.t(`OUTCOMES.${value}`);
      if (value === true || value === 'true') return this.t('YES');
      if (value === false || value === 'false') return this.t('NO_WORD');
      return value;
    },
    async confirm() {
      this.busy = true;
      this.error = '';
      try {
        const { data } = await AssistantAPI.confirm(
          this.proposal.id,
          this.payload()
        );
        this.$emit('updated', data.proposal);
      } catch (e) {
        this.error = e.response?.data?.error || this.t('FAILED');
      } finally {
        this.busy = false;
      }
    },
    async cancel() {
      this.busy = true;
      try {
        const { data } = await AssistantAPI.cancel(this.proposal.id);
        this.$emit('updated', data.proposal);
      } finally {
        this.busy = false;
      }
    },
    async copy() {
      try {
        await navigator.clipboard.writeText(this.form.content);
        this.copied = true;
      } catch (_e) {
        this.copied = false;
      }
      if (this.pending) this.confirm();
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col gap-2 p-3 bg-white border rounded-lg border-slate-200 dark:bg-slate-900 dark:border-slate-700"
  >
    <div class="flex items-center gap-2 text-sm font-semibold">
      <fluent-icon :icon="icon" size="14" class="text-woot-600" />
      <span class="text-slate-800 dark:text-slate-100">{{ t(type) }}</span>
      <span
        v-if="!pending"
        class="ml-auto text-xs font-medium"
        :class="
          proposal.status === 'done' ? 'text-green-600' : 'text-slate-400'
        "
      >
        {{ proposal.status === 'done' ? t('DONE') : t('CANCELLED') }}
      </span>
    </div>

    <!-- D3 — delegar: agente, cliente y conversación -->
    <template v-if="type === 'delegate' || type === 'tracking_action'">
      <p v-if="labels.agent" class="m-0 text-xs text-slate-500">
        {{ t('AGENT') }}:
        <span class="font-medium text-slate-700 dark:text-slate-200">{{
          labels.agent
        }}</span>
      </p>
      <p
        v-if="type === 'tracking_action'"
        class="m-0 text-sm text-slate-700 dark:text-slate-200"
      >
        {{ t(`ACTIONS.${proposal.payload.action}`) }}
        <template v-if="labels.target"> · {{ labels.target }}</template>
      </p>
    </template>
    <p
      v-if="
        (labels.target || labels.conversation) && type !== 'tracking_action'
      "
      class="m-0 text-xs text-slate-500"
    >
      {{ labels.target ? t('TARGET') : t('CONVERSATION') }}:
      <span class="text-slate-700 dark:text-slate-200">{{
        labels.target || labels.conversation
      }}</span>
    </p>
    <p
      v-else-if="type === 'task' || type === 'meeting'"
      class="m-0 text-xs text-slate-500"
    >
      {{ t('NO_TARGET') }}
    </p>

    <!-- D4 — lo que la tarjeta resume (tipo, cliente, etapa, resultado, datos…) -->
    <dl v-if="labels.rows && labels.rows.length" class="m-0 text-xs">
      <div v-for="[key, value] in labels.rows" :key="key" class="flex gap-1">
        <dt class="text-slate-500">{{ rowLabel(key) }}:</dt>
        <dd class="m-0 text-slate-700 dark:text-slate-200">
          {{ rowValue(key, value) }}
        </dd>
      </div>
    </dl>

    <fieldset
      :disabled="!pending || busy"
      class="flex flex-col gap-2 p-0 m-0 border-0 [&_input]:!mb-0 [&_textarea]:!mb-0"
    >
      <label v-if="type === 'task' || type === 'meeting'" class="text-xs">
        {{ t('TITLE') }}
        <input v-model="form.title" type="text" class="h-8 text-sm" />
      </label>
      <label
        v-if="['note', 'scheduled_message', 'draft'].includes(type)"
        class="text-xs"
      >
        {{ t('CONTENT') }}
        <textarea v-model="form.content" rows="4" class="text-sm" />
      </label>
      <label v-if="type === 'task'" class="text-xs">
        {{ t('DUE') }}
        <input
          v-model="form.due_at"
          type="datetime-local"
          class="h-8 text-sm"
        />
      </label>
      <div v-if="type === 'meeting'" class="grid grid-cols-2 gap-2">
        <label class="text-xs">
          {{ t('STARTS') }}
          <input
            v-model="form.starts_at"
            type="datetime-local"
            class="h-8 text-sm"
          />
        </label>
        <label class="text-xs">
          {{ t('ENDS') }}
          <input
            v-model="form.ends_at"
            type="datetime-local"
            class="h-8 text-sm"
          />
        </label>
      </div>
      <label v-if="type === 'meeting'" class="text-xs">
        {{ t('LOCATION') }}
        <input v-model="form.location" type="text" class="h-8 text-sm" />
      </label>
      <template v-if="type === 'delegate'">
        <label class="text-xs">
          {{ t('OBJECTIVE') }}
          <textarea v-model="form.objective" rows="2" class="text-sm" />
        </label>
        <label class="text-xs">
          {{ t('INSTRUCTION') }}
          <textarea v-model="form.instruction" rows="2" class="text-sm" />
        </label>
        <label class="text-xs">
          {{ t('FIRST') }}
          <input
            v-model="form.first_at"
            type="datetime-local"
            class="h-8 text-sm"
          />
        </label>
        <div class="grid grid-cols-3 gap-2">
          <label class="text-xs">
            {{ t('ATTEMPTS') }}
            <input
              v-model="form.max_attempts"
              type="number"
              min="1"
              max="10"
              class="h-8 text-sm"
            />
          </label>
          <label class="text-xs">
            {{ t('EVERY') }}
            <input
              v-model="form.interval_value"
              type="number"
              min="1"
              class="h-8 text-sm"
            />
          </label>
          <label class="text-xs">
            &nbsp;
            <select v-model="form.interval_unit" class="!h-9 !py-1 text-sm">
              <option v-for="u in units" :key="u" :value="u">
                {{ t(`UNITS.${u}`) }}
              </option>
            </select>
          </label>
        </div>
      </template>
      <label v-if="type === 'create_case'" class="text-xs">
        {{ t('TITLE') }}
        <input v-model="form.title" type="text" class="h-8 text-sm" />
      </label>
      <label v-if="type === 'move_stage'" class="text-xs">
        {{ t('ROWS.STAGE') }}
        <select v-model="form.column_id" class="!h-9 !py-1 text-sm">
          <option v-for="s in stages" :key="s.id" :value="s.id">
            {{ s.label }}
          </option>
        </select>
      </label>
      <label v-if="type === 'postpone'" class="text-xs">
        {{ t('UNTIL') }}
        <input v-model="form.until" type="date" class="h-8 text-sm" />
      </label>
      <label
        v-if="
          (type === 'outcome' || type === 'postpone') &&
          (options.reasons || []).length
        "
        class="text-xs"
      >
        {{ t('REASON') }}
        <select v-model="form.reason_id" class="!h-9 !py-1 text-sm">
          <option value="">—</option>
          <option v-for="r in options.reasons" :key="r.id" :value="r.id">
            {{ r.label }}
          </option>
        </select>
      </label>
      <template v-if="type === 'outcome'">
        <label class="text-xs">
          {{ t('NOTE') }}
          <textarea v-model="form.note" rows="2" class="text-sm" />
        </label>
        <label v-if="labels.pending" class="text-xs">
          {{ t('PENDING_TASKS', { n: labels.pending }) }}
          <select v-model="form.pending_tasks" class="!h-9 !py-1 text-sm">
            <option value="keep">{{ t('PENDING_KEEP') }}</option>
            <option value="cancel">{{ t('PENDING_CANCEL') }}</option>
          </select>
        </label>
      </template>
      <template v-if="type === 'create_contact'">
        <label class="text-xs">
          {{ t('NAME') }}
          <input v-model="form.name" type="text" class="h-8 text-sm" />
        </label>
        <div class="grid grid-cols-2 gap-2">
          <label class="text-xs">
            {{ t('EMAIL') }}
            <input v-model="form.email" type="email" class="h-8 text-sm" />
          </label>
          <label class="text-xs">
            {{ t('PHONE') }}
            <input v-model="form.phone" type="tel" class="h-8 text-sm" />
          </label>
        </div>
      </template>
      <label v-if="type === 'scheduled_message'" class="text-xs">
        {{ t('SEND_AT') }}
        <input
          v-model="form.send_at"
          type="datetime-local"
          class="h-8 text-sm"
        />
      </label>
    </fieldset>

    <p v-if="labels.assignee" class="m-0 text-xs text-slate-500">
      {{ t('ASSIGNEE') }}: {{ labels.assignee }}
    </p>
    <p
      v-if="type === 'meeting' && labels.google"
      class="m-0 text-xs text-slate-500"
    >
      {{ t('GOOGLE') }}
    </p>
    <p v-if="error" class="m-0 text-xs text-red-600">{{ error }}</p>

    <div v-if="pending" class="flex justify-end gap-2">
      <woot-button
        size="small"
        variant="clear"
        color-scheme="secondary"
        :is-disabled="busy"
        @click="cancel"
      >
        {{ t('CANCEL') }}
      </woot-button>
      <woot-button
        v-if="type === 'draft'"
        size="small"
        icon="copy"
        :is-loading="busy"
        @click="copy"
      >
        {{ t('COPY') }}
      </woot-button>
      <woot-button v-else size="small" :is-loading="busy" @click="confirm">
        {{ t('CONFIRM') }}
      </woot-button>
    </div>
    <div
      v-else-if="proposal.result && proposal.result.label"
      class="flex items-center gap-2 text-xs text-green-700 dark:text-green-400"
    >
      <fluent-icon icon="checkmark-circle" size="12" />
      <span class="flex-1">{{ proposal.result.label }}</span>
      <button
        v-if="proposal.result.path"
        class="p-0 bg-transparent border-0 cursor-pointer text-woot-600 hover:underline"
        @click="$emit('navigate', proposal.result.path)"
      >
        {{ t('OPEN') }}
      </button>
    </div>
  </div>
</template>
