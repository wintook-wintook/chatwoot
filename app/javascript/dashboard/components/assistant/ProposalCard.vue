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
  // Seguimiento IA — el agente nuevo
  follow_up: 'bot',
  follow_up_action: 'bot',
  // D4 — casos y clientes
  create_case: 'add',
  move_stage: 'arrow-swap',
  outcome: 'checkmark-circle',
  postpone: 'calendar-clock',
  resume_case: 'arrow-clockwise',
  update_opportunity: 'edit',
  create_contact: 'person-add',
  // Cotizaciones
  create_quote: 'receipt',
  send_quote: 'send',
  // Contestar una conversación
  reply: 'send',
  // Trabajo en campo
  on_my_way: 'navigation',
  visit_report: 'clipboard',
  // Captar en la expo (etiqueta NFC)
  nfc_link: 'flash-on',
  // Tareas con el cliente
  client_task: 'person',
  // Cancelar con motivo
  cancel_item: 'dismiss-circle',
};

// Igual que el servidor (Assistant::QuoteTools.totals): descuento por partida, IVA de la partida.
const round2 = n => Math.round(n * 100) / 100;
const itemNet = i =>
  round2(
    Number(i.quantity || 0) *
      Number(i.unit_price || 0) *
      (1 - Number(i.discount_percent || 0) / 100)
  );

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
        // Cotización: las partidas se pueden ajustar (cantidad, precio) o quitar.
        items: (p.items || []).map(i => ({ ...i })),
        // Campo: hora de llegada, lo dictado, puntos de la lista y minutos.
        eta_minutes: p.eta_minutes || 30,
        notes: p.notes || '',
        done_task_ids: [...(p.done_task_ids || [])],
        minutes: p.minutes || '',
        // NFC: el mensaje que envía el cliente.
        message: p.message || '',
        // Tarea del cliente: pide archivo y avisarle con el enlace.
        requires_file: !!p.requires_file,
        notify: p.notify !== false,
        // Cancelar: comentario y si se le avisa al cliente (motivo en reason_id, tiempo en minutes).
        cancel_comment: p.comment || '',
        notify_client: p.notify_client !== false,
      },
      writing: false,
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
    // Delegar a un agente del módulo o al Seguimiento IA: la misma tarjeta.
    isDelegate() {
      return this.type === 'delegate' || this.type === 'follow_up';
    },
    quoteTotals() {
      const net = this.form.items.reduce((sum, i) => sum + itemNet(i), 0);
      const tax = this.form.items.reduce(
        (sum, i) =>
          sum + round2((itemNet(i) * Number(i.tax_percent || 0)) / 100),
        0
      );
      return { net: round2(net), tax: round2(tax), total: round2(net + tax) };
    },
    isAction() {
      return (
        this.type === 'tracking_action' || this.type === 'follow_up_action'
      );
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    // Solo los campos que se ven en la tarjeta de ese tipo.
    payload() {
      const f = this.form;
      const delegate = {
        objective: f.objective,
        instruction: f.instruction,
        starts_at: toIso(f.first_at),
        max_attempts: Number(f.max_attempts),
        interval_value: Number(f.interval_value),
        interval_unit: f.interval_unit,
      };
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
        delegate,
        follow_up: delegate,
        tracking_action: {},
        follow_up_action: {},
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
        create_quote: { items: f.items },
        send_quote: {},
        // Con plantilla no se edita: la llenó Dali con datos reales.
        reply: this.labels.template ? {} : { content: f.content },
        on_my_way: { eta_minutes: Number(f.eta_minutes) },
        nfc_link: { message: f.message },
        cancel_item: {
          reason_id: Number(f.reason_id) || null,
          comment: f.cancel_comment,
          minutes: f.minutes === '' ? null : Number(f.minutes),
          notify_client: !!this.labels.meeting && !!f.notify_client,
        },
        client_task: {
          title: f.title,
          due_at: toIso(f.due_at),
          requires_file: !!f.requires_file,
          notify: !!f.notify,
        },
        visit_report: {
          notes: f.notes,
          done_task_ids: f.done_task_ids,
          minutes: f.minutes === '' ? null : Number(f.minutes),
        },
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
    money(value) {
      const currency = this.labels.currency || 'MXN';
      try {
        return new Intl.NumberFormat(undefined, {
          style: 'currency',
          currency,
        }).format(value || 0);
      } catch {
        return `${Number(value || 0).toFixed(2)} ${currency}`;
      }
    },
    removeItem(index) {
      this.form.items.splice(index, 1);
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
    // NFC: grabar el enlace en la etiqueta (Web NFC, Chrome en Android) o copiarlo.
    async writeNfc() {
      const { url } = this.proposal.result;
      if (!('NDEFReader' in window)) {
        await navigator.clipboard?.writeText(url);
        this.error = this.t('NFC_NO_WEB');
        return;
      }
      this.writing = true;
      this.error = '';
      try {
        // eslint-disable-next-line no-undef
        await new NDEFReader().write({
          records: [{ recordType: 'url', data: url }],
        });
        this.copied = true;
      } catch (_e) {
        this.error = this.t('NFC_ERROR');
      } finally {
        this.writing = false;
      }
    },
    async copyNfc() {
      await navigator.clipboard?.writeText(this.proposal.result.url);
      this.copied = true;
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
    <template v-if="isDelegate || isAction">
      <p v-if="labels.agent" class="m-0 text-xs text-slate-500">
        {{ t('AGENT') }}:
        <span class="font-medium text-slate-700 dark:text-slate-200">{{
          labels.agent
        }}</span>
      </p>
      <p v-if="labels.template" class="m-0 text-xs text-slate-500">
        {{ t('TEMPLATE') }}:
        <span class="font-medium text-slate-700 dark:text-slate-200">{{
          labels.template
        }}</span>
      </p>
      <p v-if="isAction" class="m-0 text-sm text-slate-700 dark:text-slate-200">
        {{ t(`ACTIONS.${proposal.payload.action}`) }}
        <template v-if="labels.target"> · {{ labels.target }}</template>
      </p>
    </template>
    <p
      v-if="(labels.target || labels.conversation) && !isAction"
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
      <label
        v-if="type === 'task' || type === 'meeting' || type === 'client_task'"
        class="text-xs"
      >
        {{ t('TITLE') }}
        <input v-model="form.title" type="text" class="h-8 text-sm" />
      </label>
      <label
        v-if="
          ['note', 'scheduled_message', 'draft'].includes(type) ||
          (type === 'reply' && !labels.template)
        "
        class="text-xs"
      >
        {{ t('CONTENT') }}
        <textarea v-model="form.content" rows="4" class="text-sm" />
      </label>
      <label v-if="type === 'task' || type === 'client_task'" class="text-xs">
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
      <template v-if="isDelegate">
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
      <!-- Cotización: partidas (cantidad y precio sin IVA editables) y totales -->
      <template v-if="type === 'create_quote'">
        <div
          class="grid grid-cols-[1fr_4rem_6rem_1rem] gap-2 text-xs text-slate-500"
        >
          <span />
          <span>{{ t('QUANTITY') }}</span>
          <span>{{ t('UNIT_PRICE') }}</span>
        </div>
        <div
          v-for="(item, index) in form.items"
          :key="index"
          class="grid items-center grid-cols-[1fr_4rem_6rem_1rem] gap-2"
        >
          <span
            class="text-xs truncate text-slate-700 dark:text-slate-200"
            :title="item.description"
          >
            {{ item.description }}
          </span>
          <input
            v-model.number="item.quantity"
            type="number"
            min="0.01"
            step="any"
            :aria-label="t('QUANTITY')"
            class="h-8 text-sm"
          />
          <input
            v-model.number="item.unit_price"
            type="number"
            min="0"
            step="any"
            :aria-label="t('UNIT_PRICE')"
            class="h-8 text-sm"
          />
          <button
            v-if="pending && form.items.length > 1"
            type="button"
            class="p-0 bg-transparent border-0 cursor-pointer text-slate-400 hover:text-red-600"
            :title="t('REMOVE_ITEM')"
            @click="removeItem(index)"
          >
            <fluent-icon icon="dismiss" size="12" />
          </button>
        </div>
        <dl class="m-0 text-xs text-right text-slate-500">
          <div>
            {{ t('NET') }}:
            <span class="text-slate-700 dark:text-slate-200">{{
              money(quoteTotals.net)
            }}</span>
          </div>
          <div>
            {{ t('TAX') }}:
            <span class="text-slate-700 dark:text-slate-200">{{
              money(quoteTotals.tax)
            }}</span>
          </div>
          <div class="font-semibold text-slate-800 dark:text-slate-100">
            {{ t('TOTAL') }}: {{ money(quoteTotals.total) }}
          </div>
        </dl>
        <p class="m-0 text-xs text-slate-500">{{ t('QUOTE_DRAFT') }}</p>
      </template>
      <!-- Cancelar con motivo: motivo, comentario, tiempo y aviso al cliente -->
      <template v-if="type === 'cancel_item'">
        <label class="text-xs">
          {{ t('CANCEL_REASON') }}
          <select v-model="form.reason_id" class="h-8 text-sm">
            <option v-for="r in labels.reasons || []" :key="r.id" :value="r.id">
              {{ r.label }}
            </option>
          </select>
        </label>
        <label class="text-xs">
          {{ t('CANCEL_COMMENT') }}
          <textarea v-model="form.cancel_comment" rows="2" class="text-sm" />
        </label>
        <label class="text-xs">
          {{
            labels.work_started
              ? t('CANCEL_MINUTES_REQUIRED')
              : t('CANCEL_MINUTES')
          }}
          <input
            v-model="form.minutes"
            type="number"
            min="0"
            class="h-8 text-sm"
          />
        </label>
        <label v-if="labels.meeting" class="flex items-center gap-2 text-xs">
          <input v-model="form.notify_client" type="checkbox" class="!m-0" />
          {{ t('CANCEL_NOTIFY') }}
        </label>
      </template>
      <!-- Tarea del cliente: pide archivo y avisarle con el enlace de su portal -->
      <template v-if="type === 'client_task'">
        <label class="flex items-center gap-2 text-xs">
          <input v-model="form.requires_file" type="checkbox" class="!m-0" />
          {{ t('CLIENT_TASK_FILE') }}
        </label>
        <label class="flex items-center gap-2 text-xs">
          <input v-model="form.notify" type="checkbox" class="!m-0" />
          {{ t('CLIENT_TASK_NOTIFY') }}
        </label>
      </template>
      <!-- NFC: el mensaje que envía el cliente al acercar el celular -->
      <label v-if="type === 'nfc_link'" class="text-xs">
        {{ t('NFC_MESSAGE') }}
        <textarea v-model="form.message" rows="2" class="text-sm" />
      </label>
      <!-- Campo: «Voy en camino» -->
      <label v-if="type === 'on_my_way'" class="text-xs">
        {{ t('ETA') }}
        <input
          v-model="form.eta_minutes"
          type="number"
          min="5"
          max="240"
          class="h-8 text-sm"
        />
      </label>
      <!-- Campo: el reporte dictado de la visita -->
      <template v-if="type === 'visit_report'">
        <label class="text-xs">
          {{ t('NOTES') }}
          <textarea v-model="form.notes" rows="5" class="text-sm" />
        </label>
        <div v-if="(labels.checklist || []).length" class="text-xs">
          <p class="m-0 mb-1 text-slate-500">{{ t('CHECKLIST') }}</p>
          <label
            v-for="task in labels.checklist"
            :key="task.id"
            class="flex items-center gap-2 py-0.5 text-sm text-slate-700 dark:text-slate-200"
          >
            <input
              v-model="form.done_task_ids"
              type="checkbox"
              :value="task.id"
              class="!m-0"
            />
            {{ task.title }}
          </label>
        </div>
        <label v-if="labels.closes_visit" class="text-xs">
          {{ t('MINUTES') }}
          <input
            v-model="form.minutes"
            type="number"
            min="0"
            class="h-8 text-sm"
          />
        </label>
        <p class="m-0 text-xs text-slate-500">
          {{ labels.closes_visit ? t('CLOSES_VISIT') : t('FIELD_REST') }}
        </p>
      </template>
      <!-- Ventana de 24 h cerrada: sale una plantilla aprobada, ya llena -->
      <template v-if="type === 'reply' && labels.template">
        <p class="m-0 text-xs text-slate-500">
          {{ t('TEMPLATE') }}:
          <span class="font-medium text-slate-700 dark:text-slate-200">{{
            labels.template
          }}</span>
        </p>
        <p
          class="p-2 m-0 text-sm whitespace-pre-line rounded bg-slate-50 text-slate-700 dark:bg-slate-800 dark:text-slate-200"
        >
          {{ labels.template_text }}
        </p>
        <p class="m-0 text-xs text-slate-500">{{ t('TEMPLATE_NOTE') }}</p>
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
        {{ type === 'reply' ? t('SEND') : t('CONFIRM') }}
      </woot-button>
    </div>
    <!-- NFC hecho: grabar en la etiqueta o copiar el enlace -->
    <div
      v-if="type === 'nfc_link' && proposal.result && proposal.result.url"
      class="flex flex-wrap items-center gap-2"
    >
      <span
        class="flex items-center w-full gap-1 text-xs text-green-700 dark:text-green-400"
      >
        <fluent-icon icon="checkmark-circle" size="12" />
        {{ proposal.result.label }}
      </span>
      <woot-button
        size="small"
        icon="flash-on"
        :is-loading="writing"
        @click="writeNfc"
      >
        {{ writing ? t('NFC_WRITING') : t('NFC_WRITE') }}
      </woot-button>
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="secondary"
        icon="copy"
        @click="copyNfc"
      >
        {{ t('NFC_COPY') }}
      </woot-button>
      <span v-if="copied" class="text-xs text-green-700 dark:text-green-400">
        {{ t('NFC_DONE') }}
      </span>
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
