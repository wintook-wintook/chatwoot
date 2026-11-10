<!--
  Tarea → tarea agendada desde las listas fuera del caso (Cases::Conversion#to_meeting).
  Día y hora (la duración sale de lo estimado) y lugar. Dentro del caso se usa la ventana
  completa de «Agendar tarea» (MeetingFormModal).
  Emite `submit` con { starts_at, ends_at, location, time_zone } y `close`.
-->
<script>
const T = 'CONVERT_ITEM';

const pad = n => String(n).padStart(2, '0');
const toLocalInput = d =>
  `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(
    d.getHours()
  )}:${pad(d.getMinutes())}`;

export default {
  name: 'ScheduleTaskModal',
  props: {
    show: { type: Boolean, default: false },
    // { title, estimated_minutes, due_at, replaceable }
    task: { type: Object, default: null },
    busy: { type: Boolean, default: false },
    error: { type: String, default: '' },
  },
  emits: ['submit', 'close'],
  data() {
    return { startsAt: '', endsAt: '', location: '' };
  },
  computed: {
    valid() {
      return (
        !!this.startsAt &&
        !!this.endsAt &&
        new Date(this.endsAt) > new Date(this.startsAt)
      );
    },
  },
  watch: {
    show(open) {
      if (open) this.reset();
    },
    // Al mover el inicio, el fin conserva la duración estimada.
    startsAt(value) {
      if (!value || !this.show) return;
      const end = new Date(value);
      end.setMinutes(end.getMinutes() + (this.task?.estimated_minutes || 60));
      this.endsAt = toLocalInput(end);
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    // El día de su fecha límite (o mañana) a las 10:00.
    reset() {
      const due = this.task?.due_at ? new Date(this.task.due_at) : null;
      const start = due && due > new Date() ? due : new Date();
      if (!due || due <= new Date()) start.setDate(start.getDate() + 1);
      start.setHours(10, 0, 0, 0);
      this.location = '';
      this.startsAt = toLocalInput(start);
    },
    submit() {
      if (!this.valid) return;
      this.$emit('submit', {
        starts_at: new Date(this.startsAt).toISOString(),
        ends_at: new Date(this.endsAt).toISOString(),
        location: this.location,
        time_zone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      });
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="small">
    <div v-if="task" class="flex flex-col gap-3 p-6">
      <h3 class="m-0 text-lg font-semibold text-slate-800 dark:text-slate-100">
        {{ t('SCHEDULE_TITLE', { title: task.title }) }}
      </h3>
      <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
        {{
          task.replaceable === false
            ? $t('CASE_TICKETS.MEETINGS.MODAL.KEEP_LOCKED')
            : t('SCHEDULE_DESC')
        }}
      </p>
      <div class="grid grid-cols-2 gap-2">
        <label class="text-sm">
          <span class="block">{{ t('STARTS') }}</span>
          <input v-model="startsAt" type="datetime-local" class="!mb-0" />
        </label>
        <label class="text-sm">
          <span class="block">{{ t('ENDS') }}</span>
          <input v-model="endsAt" type="datetime-local" class="!mb-0" />
        </label>
      </div>
      <label class="text-sm">
        <span class="block">{{ t('LOCATION') }}</span>
        <input v-model="location" type="text" class="!mb-0" />
      </label>
      <p v-if="error" class="m-0 text-xs text-red-600">{{ error }}</p>
      <div class="flex justify-end gap-2">
        <woot-button variant="clear" @click="$emit('close')">
          {{ t('CANCEL') }}
        </woot-button>
        <woot-button :is-loading="busy" :is-disabled="!valid" @click="submit">
          {{ t('SAVE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
