<!--
  Agenda — participantes de una tarea agendada: otros usuarios del equipo además del
  responsable. La ven en su Agenda, Mi día y Mi ruta y reciben avisos; solo el
  responsable la concluye. Si alguno ya tiene algo a esa hora, lo avisa (no bloquea).
  v-model = [ids]
-->
<script>
import { mapGetters } from 'vuex';
import AgendaItemsAPI from 'dashboard/api/agendaItems';

export default {
  name: 'ParticipantsPicker',
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Array, default: () => [] },
    // El responsable no se ofrece: ya está.
    organizerId: { type: [Number, String], default: null },
    startsAt: { type: String, default: '' },
    endsAt: { type: String, default: '' },
    // Al editar: la misma tarea no cuenta como choque.
    excludeId: { type: [Number, String], default: null },
    // Estado de cada uno al editar: [{ id, status, note }].
    current: { type: Array, default: () => [] },
    // feat/ventana_evento_calendario — título propio (en el calendario dice «Agentes»).
    label: { type: String, default: '' },
  },
  data() {
    return { busy: [], timer: null };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    options() {
      return this.agents.filter(a => a.id !== Number(this.organizerId));
    },
    busyKey() {
      return [this.value.join(','), this.startsAt, this.endsAt].join('|');
    },
  },
  watch: {
    busyKey() {
      clearTimeout(this.timer);
      this.timer = setTimeout(this.checkBusy, 400);
    },
  },
  mounted() {
    if (!this.agents.length) this.$store.dispatch('agents/get');
    this.checkBusy();
  },
  beforeDestroy() {
    clearTimeout(this.timer);
  },
  methods: {
    selected(id) {
      return this.value.includes(id);
    },
    toggle(id) {
      const ids = this.selected(id)
        ? this.value.filter(v => v !== id)
        : [...this.value, id];
      this.$emit('input', ids);
    },
    declined(id) {
      return this.current.find(p => p.id === id && p.status === 'declined');
    },
    busyFor(id) {
      return this.busy.find(b => b.user_id === id);
    },
    hour(value) {
      return new Date(value).toLocaleTimeString([], {
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    busyText(entry) {
      const item = entry.items[0];
      const range = `${this.hour(item.start)}–${this.hour(item.end)}`;
      return item.title ? `${item.title} (${range})` : range;
    },
    async checkBusy() {
      const start = new Date(this.startsAt);
      const end = new Date(this.endsAt);
      if (
        !this.value.length ||
        Number.isNaN(start.getTime()) ||
        !(end > start)
      ) {
        this.busy = [];
        return;
      }
      try {
        const { data } = await AgendaItemsAPI.busy({
          user_ids: this.value,
          start: start.toISOString(),
          end: end.toISOString(),
          exclude_id: this.excludeId || undefined,
        });
        this.busy = data.busy || [];
      } catch {
        this.busy = [];
      }
    },
  },
};
</script>

<template>
  <div class="block">
    <span class="field-label">
      {{ label || $t('AGENDA_PARTICIPANTS.LABEL') }}
    </span>
    <div class="flex flex-wrap gap-1.5">
      <button
        v-for="agent in options"
        :key="agent.id"
        type="button"
        class="px-2.5 py-1 text-xs rounded-full border transition-colors"
        :class="
          selected(agent.id)
            ? 'bg-woot-500 border-woot-500 text-white'
            : 'border-slate-200 dark:border-slate-600 text-slate-700 dark:text-slate-200 hover:border-woot-400'
        "
        @click="toggle(agent.id)"
      >
        {{ agent.name }}
        <span v-if="selected(agent.id) && declined(agent.id)">
          · {{ $t('AGENDA_PARTICIPANTS.DECLINED') }}
        </span>
      </button>
    </div>
    <p class="mt-1 mb-0 text-xs text-slate-500 dark:text-slate-400">
      {{ $t('AGENDA_PARTICIPANTS.HINT') }}
    </p>
    <template v-for="id in value">
      <p
        v-if="declined(id) && declined(id).note"
        :key="`d${id}`"
        class="mt-1 mb-0 text-xs text-slate-600 dark:text-slate-300"
      >
        {{
          $t('AGENDA_PARTICIPANTS.DECLINED_NOTE', {
            name: (options.find(a => a.id === id) || {}).name,
            note: declined(id).note,
          })
        }}
      </p>
      <p
        v-if="busyFor(id)"
        :key="`b${id}`"
        class="mt-1 mb-0 text-xs text-amber-700 dark:text-amber-400"
      >
        {{
          $t('AGENDA_PARTICIPANTS.BUSY', {
            name: busyFor(id).name,
            what: busyText(busyFor(id)),
          })
        }}
      </p>
    </template>
  </div>
</template>
