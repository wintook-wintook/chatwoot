<!--
  Cancelar una tarea o una tarea agendada — «ya no se va a hacer» (no es completarla ni
  borrarla). Pide el motivo (catálogo; «Otro» pide comentario) y el tiempo dedicado:
  opcional, obligatorio si ya se trabajó (`item.work_started`).
  Tarea agendada: primero ofrece reprogramar (evento `reschedule`); si es de una serie,
  esta o toda; y avisarle al cliente.
  Emite `submit` con { reason_id, comment, minutes, scope, notify_client } y `close`.
-->
<script>
import TaskOutcomesAPI from 'dashboard/api/taskOutcomes';

const T = 'CANCEL_ITEM';

export default {
  name: 'CancelItemModal',
  props: {
    show: { type: Boolean, default: false },
    // { title, work_started, series, has_client }
    item: { type: Object, default: null },
    kind: { type: String, default: 'task' }, // task | meeting
    busy: { type: Boolean, default: false },
    error: { type: String, default: '' },
  },
  emits: ['submit', 'close', 'reschedule'],
  data() {
    return {
      reasons: [],
      step: 'ask', // ask (¿reprogramar?) | form
      form: this.emptyForm(),
    };
  },
  computed: {
    isMeeting() {
      return this.kind === 'meeting';
    },
    reason() {
      return this.reasons.find(r => r.id === Number(this.form.reason_id));
    },
    needsComment() {
      return !!this.reason && this.reason.label.trim().toLowerCase() === 'otro';
    },
    needsMinutes() {
      return !!this.item?.work_started;
    },
    valid() {
      if (!this.reason) return false;
      if (this.needsComment && !this.form.comment.trim()) return false;
      return !this.needsMinutes || Number(this.form.minutes) > 0;
    },
  },
  watch: {
    show(open) {
      if (!open) return;
      this.form = this.emptyForm();
      this.step = this.isMeeting ? 'ask' : 'form';
      if (!this.reasons.length) this.load();
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    emptyForm() {
      return {
        reason_id: '',
        comment: '',
        minutes: '',
        scope: 'one',
        notify_client: true,
      };
    },
    async load() {
      const { data } = await TaskOutcomesAPI.list('cancel');
      this.reasons = data.task_outcomes.filter(r => r.active);
    },
    submit() {
      if (!this.valid) return;
      this.$emit('submit', {
        reason_id: Number(this.form.reason_id),
        comment: this.form.comment.trim(),
        minutes: this.form.minutes ? Number(this.form.minutes) : null,
        scope: this.form.scope,
        notify_client:
          this.isMeeting && this.item?.has_client && this.form.notify_client,
      });
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="small">
    <div class="flex flex-col gap-3 p-6">
      <h3 class="m-0 text-lg font-semibold text-slate-800 dark:text-slate-100">
        {{ isMeeting ? t('TITLE_MEETING') : t('TITLE_TASK') }}
      </h3>
      <p v-if="item" class="m-0 text-sm text-slate-600 dark:text-slate-300">
        {{ item.title }}
      </p>

      <!-- Tarea agendada: muchas «cancelaciones» son cambios de fecha. -->
      <template v-if="step === 'ask'">
        <p class="m-0 text-sm text-slate-700 dark:text-slate-200">
          {{ t('RESCHEDULE_QUESTION') }}
        </p>
        <div class="flex flex-wrap justify-end gap-2">
          <woot-button variant="smooth" @click="$emit('reschedule')">
            {{ t('RESCHEDULE') }}
          </woot-button>
          <woot-button color-scheme="alert" @click="step = 'form'">
            {{ t('REALLY_CANCEL') }}
          </woot-button>
        </div>
      </template>

      <template v-else>
        <label class="text-sm">
          {{ t('REASON') }}
          <select v-model="form.reason_id" class="!mb-0">
            <option value="" disabled>{{ t('REASON_PLACEHOLDER') }}</option>
            <option v-for="r in reasons" :key="r.id" :value="r.id">
              {{ r.label }}
            </option>
          </select>
        </label>
        <label class="text-sm">
          {{ needsComment ? t('COMMENT_REQUIRED') : t('COMMENT') }}
          <textarea v-model="form.comment" rows="2" class="!mb-0" />
        </label>
        <label class="text-sm">
          {{ needsMinutes ? t('MINUTES_REQUIRED') : t('MINUTES') }}
          <input
            v-model="form.minutes"
            type="number"
            min="0"
            step="5"
            class="!mb-0"
            :placeholder="t('MINUTES_PLACEHOLDER')"
          />
          <span class="text-xs text-slate-500">{{ t('MINUTES_HINT') }}</span>
        </label>
        <div v-if="isMeeting && item && item.series" class="flex gap-4 text-sm">
          <label class="flex items-center gap-2">
            <input v-model="form.scope" type="radio" value="one" class="!m-0" />
            {{ t('SCOPE_ONE') }}
          </label>
          <label class="flex items-center gap-2">
            <input v-model="form.scope" type="radio" value="all" class="!m-0" />
            {{ t('SCOPE_ALL') }}
          </label>
        </div>
        <label
          v-if="isMeeting && item && item.has_client"
          class="flex items-center gap-2 text-sm"
        >
          <input v-model="form.notify_client" type="checkbox" class="!m-0" />
          {{ t('NOTIFY_CLIENT') }}
        </label>
        <p v-if="error" class="m-0 text-xs text-red-600">{{ error }}</p>
        <div class="flex justify-end gap-2">
          <woot-button variant="clear" @click="$emit('close')">
            {{ t('BACK') }}
          </woot-button>
          <woot-button
            color-scheme="alert"
            :is-loading="busy"
            :is-disabled="!valid"
            @click="submit"
          >
            {{ t('CONFIRM') }}
          </woot-button>
        </div>
      </template>
    </div>
  </woot-modal>
</template>
