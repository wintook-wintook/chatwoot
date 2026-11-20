<!--
  Lo que tienen igual los tres agentes listos después de pasarlo o agendar (Functions::Extras):
  el plazo para que alguien le escriba (attend_hours, Motor2::AttendClock) y el recordatorio de la cita
  (appointment_notice, Motor2::AppointmentNotice). v-model: los settings del agente.
-->
<script>
export default {
  name: 'AfterHandoff',
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, required: true },
    templates: { type: Array, default: () => [] },
    // ¿Agenda citas? (si no, no se enseña el recordatorio de la cita).
    appointments: { type: Boolean, default: false },
  },
  emits: ['input'],
  computed: {
    notice() {
      return this.value.appointment_notice || { on: false, template: '' };
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`READY_AGENTS.FIELDS.${key}`, params);
    },
    set(field, val) {
      this.$emit('input', { ...this.value, [field]: val });
    },
    setNotice(field, val) {
      this.set('appointment_notice', { ...this.notice, [field]: val });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <label class="block">
      <span class="field-label">{{ t('ATTEND_HOURS') }}</span>
      <select
        :value="value.attend_hours || 0"
        @change="set('attend_hours', Number($event.target.value))"
      >
        <option v-for="h in [0, 1, 2, 4, 8]" :key="h" :value="h">
          {{ h ? t('ATTEND_HOURS_N', { n: h }) : t('ATTEND_OFF') }}
        </option>
      </select>
      <span class="block mt-1 text-xs text-slate-500">{{
        t('ATTEND_HINT')
      }}</span>
    </label>
    <template v-if="appointments">
      <label class="flex items-start gap-2 text-sm">
        <input
          type="checkbox"
          class="!m-0 mt-1"
          :checked="notice.on"
          @change="setNotice('on', $event.target.checked)"
        />
        {{ t('APPOINTMENT_NOTICE') }}
      </label>
      <label v-if="notice.on && templates.length" class="block">
        <span class="field-label">{{ t('APPOINTMENT_NOTICE_TEMPLATE') }}</span>
        <select
          :value="notice.template || ''"
          @change="setNotice('template', $event.target.value)"
        >
          <option value="">{{ t('NO_TEMPLATE') }}</option>
          <option v-for="tpl in templates" :key="tpl" :value="tpl">
            {{ tpl }}
          </option>
        </select>
      </label>
    </template>
  </div>
</template>
