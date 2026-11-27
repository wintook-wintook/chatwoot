<!--
  feat/ventana_evento_calendario F2 — quién va, en una sola lista y un solo buscador.
  · Agentes del equipo → participantes (`participantIds`, tarea agendada) o, en un evento solo
    de Google, invitados con su correo.
  · Contactos con correo y cualquier correo → invitados (`attendees`, les llega la invitación
    de Google).
  · Pegar o escribir varios correos separados por comas los agrega todos; lo que no es correo
    se queda en la caja marcado en rojo (`flush()` → false para que la ventana no guarde).
  · Sugerencia del cliente (D4: no se agrega sola) y aviso de «ocupado» por agente.
  v-bind: participant-ids.sync, attendees.sync
-->
<script>
import { mapGetters } from 'vuex';
import ContactAPI from 'dashboard/api/contacts';
import AgendaItemsAPI from 'dashboard/api/agendaItems';

const T = 'GOOGLE_CALENDAR.PEOPLE';
const EMAIL_RE = /^[^\s@,;<>]+@[^\s@,;<>]+\.[^\s@,;<>]+$/;
const MAX_OPTIONS = 6;

export const isEmail = text => EMAIL_RE.test(String(text || '').trim());

export const splitEmails = text =>
  String(text || '')
    .split(/[,;\s]+/)
    .map(part => part.trim())
    .filter(Boolean);

export default {
  name: 'PeoplePicker',
  props: {
    participantIds: { type: Array, default: () => [] },
    attendees: { type: Array, default: () => [] },
    // Tarea agendada: los agentes van como participantes.
    allowAgents: { type: Boolean, default: false },
    // Se pueden invitar correos (contactos o cualquiera).
    allowEmails: { type: Boolean, default: true },
    // Ofrecer agentes en el buscador. En una tarea agendada no: van en las pastillas de
    // «Agentes» (como siempre, a la vista); aquí solo contactos y correos.
    searchAgents: { type: Boolean, default: true },
    // El responsable nunca se ofrece.
    organizerId: { type: [Number, String], default: null },
    startsAt: { type: String, default: '' },
    endsAt: { type: String, default: '' },
    excludeId: { type: [Number, String], default: null },
    // Estado de cada participante al editar: [{ id, status }].
    current: { type: Array, default: () => [] },
    // { name, email } del cliente de la tarea, para sugerirlo.
    client: { type: Object, default: null },
  },
  emits: ['update:participantIds', 'update:attendees'],
  data() {
    return {
      query: '',
      open: false,
      contacts: [],
      // Nombre de los contactos invitados (para mostrarlo en su fila).
      names: {},
      invalid: [],
      busy: [],
      searchTimer: null,
      busyTimer: null,
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    agentsById() {
      return Object.fromEntries((this.agents || []).map(a => [a.id, a]));
    },
    agentsByEmail() {
      return Object.fromEntries(
        (this.agents || [])
          .filter(a => a.email)
          .map(a => [a.email.toLowerCase(), a])
      );
    },
    taken() {
      return new Set(this.attendees.map(e => e.toLowerCase()));
    },
    agentOptions() {
      const q = this.query.trim().toLowerCase();
      if (!q || !this.searchAgents) return [];
      return (this.agents || [])
        .filter(a => a.id !== Number(this.organizerId))
        .filter(a =>
          this.allowAgents
            ? !this.participantIds.includes(a.id)
            : !!a.email && !this.taken.has(a.email.toLowerCase())
        )
        .filter(a =>
          [a.available_name, a.name, a.email].some(v =>
            String(v || '')
              .toLowerCase()
              .includes(q)
          )
        )
        .map(a => ({
          key: `agent-${a.id}`,
          type: 'agent',
          agent: a,
          title: a.available_name || a.name,
          sub: this.t('AGENT'),
        }));
    },
    contactOptions() {
      if (!this.allowEmails) return [];
      return this.contacts
        .filter(c => c.email && !this.taken.has(c.email.toLowerCase()))
        .filter(c => !this.agentsByEmail[c.email.toLowerCase()])
        .map(c => ({
          key: `contact-${c.id}`,
          type: 'contact',
          email: c.email,
          name: c.name,
          title: c.name || c.email,
          sub: `${c.email} · ${this.t('CONTACT')}`,
        }));
    },
    emailOption() {
      const q = this.query.trim();
      if (!this.allowEmails || !isEmail(q) || this.taken.has(q.toLowerCase())) {
        return [];
      }
      return [
        {
          key: `email-${q}`,
          type: 'email',
          email: q,
          title: this.t('INVITE_EMAIL', { email: q }),
          sub: '',
        },
      ];
    },
    options() {
      return [
        ...this.agentOptions,
        ...this.contactOptions,
        ...this.emailOption,
      ].slice(0, MAX_OPTIONS);
    },
    clientSuggestion() {
      const c = this.client;
      if (!this.allowEmails || !c || !isEmail(c.email)) return null;
      return this.taken.has(c.email.toLowerCase()) ? null : c;
    },
    rows() {
      const agentRows = this.participantIds.map(id => {
        const agent = this.agentsById[id] || {};
        return {
          key: `p-${id}`,
          kind: 'agent',
          id,
          title: agent.available_name || agent.name || `#${id}`,
          sub: this.t('AGENT'),
          busy: this.busyText(id),
          declined: this.declined(id),
        };
      });
      const guestRows = this.attendees.map(email => {
        const agent = this.agentsByEmail[email.toLowerCase()];
        const name =
          (agent && (agent.available_name || agent.name)) || this.names[email];
        return {
          key: `g-${email}`,
          kind: 'guest',
          email,
          title: name || email,
          sub: name ? `${this.t('GUEST')} · ${email}` : this.t('GUEST'),
        };
      });
      return [...agentRows, ...guestRows];
    },
    placeholder() {
      if (!this.allowEmails) return this.t('PLACEHOLDER_AGENTS');
      return this.t(this.searchAgents ? 'PLACEHOLDER' : 'PLACEHOLDER_GUESTS');
    },
    label() {
      if (!this.allowEmails) return this.t('LABEL_AGENTS');
      return this.t(this.searchAgents ? 'LABEL' : 'LABEL_GUESTS');
    },
    busyKey() {
      return [this.participantIds.join(','), this.startsAt, this.endsAt].join(
        '|'
      );
    },
  },
  watch: {
    query(value) {
      // La marca roja se va cuando el usuario cambia el texto (no cuando flush lo deja).
      if (value !== this.invalid.join(', ')) this.invalid = [];
      clearTimeout(this.searchTimer);
      const q = value.trim();
      if (!this.allowEmails || q.length < 2) {
        this.contacts = [];
        return;
      }
      this.searchTimer = setTimeout(() => this.searchContacts(q), 300);
    },
    busyKey() {
      clearTimeout(this.busyTimer);
      this.busyTimer = setTimeout(this.checkBusy, 400);
    },
  },
  mounted() {
    if (!(this.agents || []).length) this.$store.dispatch('agents/get');
    this.checkBusy();
  },
  beforeDestroy() {
    clearTimeout(this.searchTimer);
    clearTimeout(this.busyTimer);
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async searchContacts(q) {
      try {
        const { data } = await ContactAPI.search(q);
        if (this.query.trim() === q) this.contacts = data.payload || [];
      } catch {
        this.contacts = [];
      }
    },
    addEmail(email, name) {
      const clean = email.trim();
      if (this.taken.has(clean.toLowerCase())) return;
      if (name) this.names = { ...this.names, [clean]: name };
      this.$emit('update:attendees', [...this.attendees, clean]);
    },
    addAgent(agent) {
      if (this.allowAgents) {
        if (!this.participantIds.includes(agent.id)) {
          this.$emit('update:participantIds', [
            ...this.participantIds,
            agent.id,
          ]);
        }
      } else if (agent.email) {
        this.addEmail(agent.email);
      }
    },
    pick(option) {
      if (option.type === 'agent') this.addAgent(option.agent);
      else this.addEmail(option.email, option.name);
      this.query = '';
      this.contacts = [];
    },
    // Lo escrito o pegado: correos separados por comas → todos; si no parece correo, la
    // primera sugerencia; si nada aplica, se queda en rojo. → true si no quedó nada mal.
    flush() {
      const text = this.query.trim();
      if (!text) return true;
      const parts = splitEmails(text);
      if (this.allowEmails && parts.some(isEmail)) {
        const bad = [];
        let added = [...this.attendees];
        parts.forEach(part => {
          if (!isEmail(part)) bad.push(part);
          else if (!added.some(e => e.toLowerCase() === part.toLowerCase())) {
            added = [...added, part];
          }
        });
        if (added.length !== this.attendees.length) {
          this.$emit('update:attendees', added);
        }
        this.query = bad.join(', ');
        this.invalid = bad;
        return bad.length === 0;
      }
      if (this.options.length === 1) {
        this.pick(this.options[0]);
        return true;
      }
      this.invalid = parts;
      return false;
    },
    onEnter() {
      if (this.options.length && !this.query.includes(',')) {
        this.pick(this.options[0]);
        return;
      }
      this.flush();
    },
    onPaste() {
      this.$nextTick(() => {
        if (this.query.includes('@')) this.flush();
      });
    },
    onBlur() {
      // Deja tiempo al clic en una sugerencia.
      setTimeout(() => {
        this.open = false;
      }, 150);
    },
    remove(row) {
      if (row.kind === 'agent') {
        this.$emit(
          'update:participantIds',
          this.participantIds.filter(id => id !== row.id)
        );
      } else {
        this.$emit(
          'update:attendees',
          this.attendees.filter(e => e !== row.email)
        );
      }
    },
    declined(id) {
      return !!this.current.find(p => p.id === id && p.status === 'declined');
    },
    hour(value) {
      return new Date(value).toLocaleTimeString([], {
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    busyText(id) {
      const entry = this.busy.find(b => b.user_id === id);
      const item = entry && entry.items && entry.items[0];
      if (!item) return '';
      const range = `${this.hour(item.start)}–${this.hour(item.end)}`;
      return item.title ? `${item.title} (${range})` : range;
    },
    async checkBusy() {
      const start = new Date(this.startsAt);
      const end = new Date(this.endsAt);
      if (
        !this.allowAgents ||
        !this.participantIds.length ||
        Number.isNaN(start.getTime()) ||
        !(end > start)
      ) {
        this.busy = [];
        return;
      }
      try {
        const { data } = await AgendaItemsAPI.busy({
          user_ids: this.participantIds,
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
  <div class="space-y-2">
    <label class="block">
      <span class="block mb-1 field-label">
        {{ label }}
      </span>
      <div class="relative">
        <input
          v-model="query"
          type="text"
          class="!mb-0"
          :class="{ '!border-ruby-400': invalid.length }"
          :placeholder="placeholder"
          data-test="people-search"
          @focus="open = true"
          @input="open = true"
          @blur="onBlur"
          @paste="onPaste"
          @keydown.enter.prevent="onEnter"
          @keydown.188.prevent="flush"
        />
        <ul
          v-if="open && options.length"
          class="absolute left-0 right-0 z-20 p-1 m-0 mt-1 list-none bg-white border rounded-md shadow-lg top-full dark:bg-slate-800 border-slate-200 dark:border-slate-700"
          data-test="people-options"
        >
          <li v-for="option in options" :key="option.key">
            <button
              type="button"
              class="flex flex-col items-start w-full px-2 py-1.5 text-left rounded hover:bg-slate-50 dark:hover:bg-slate-700"
              @mousedown.prevent="pick(option)"
            >
              <span class="text-sm text-slate-800 dark:text-slate-100">
                {{ option.title }}
              </span>
              <span
                v-if="option.sub"
                class="text-xs text-slate-500 dark:text-slate-400"
              >
                {{ option.sub }}
              </span>
            </button>
          </li>
        </ul>
      </div>
    </label>
    <p
      v-if="invalid.length"
      class="m-0 text-xs text-ruby-600 dark:text-ruby-400"
      data-test="people-invalid"
    >
      {{ t('INVALID', { text: invalid.join(', ') }) }}
    </p>
    <p v-else-if="allowEmails" class="m-0 text-xs text-slate-500">
      {{ t('HINT') }}
    </p>

    <div
      v-if="clientSuggestion"
      class="flex items-center justify-between gap-2 px-2 py-1 text-sm rounded-md bg-woot-50 dark:bg-woot-900/40"
      data-test="people-client"
    >
      <span class="truncate text-slate-700 dark:text-slate-200">
        {{
          t('INVITE_CLIENT', {
            name: clientSuggestion.name,
            email: clientSuggestion.email,
          })
        }}
      </span>
      <woot-button
        type="button"
        size="tiny"
        variant="smooth"
        @click="addEmail(clientSuggestion.email, clientSuggestion.name)"
      >
        {{ t('INVITE') }}
      </woot-button>
    </div>

    <ul class="p-0 m-0 list-none" data-test="people-rows">
      <li
        v-for="row in rows"
        :key="row.key"
        class="flex items-center gap-2 py-1 border-b border-slate-100 dark:border-slate-700/60"
      >
        <span
          class="flex items-center justify-center flex-shrink-0 w-6 h-6 text-xs font-medium rounded-full"
          :class="
            row.kind === 'agent'
              ? 'bg-woot-100 text-woot-700 dark:bg-woot-800 dark:text-woot-100'
              : 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-200'
          "
        >
          {{ row.title.charAt(0).toUpperCase() }}
        </span>
        <span class="flex flex-col flex-1 min-w-0">
          <span class="text-sm truncate text-slate-800 dark:text-slate-100">
            {{ row.title }}
          </span>
          <span class="text-xs truncate text-slate-500 dark:text-slate-400">
            {{ row.sub }}
          </span>
        </span>
        <span
          v-if="row.declined"
          class="flex-shrink-0 text-xs text-ruby-600 dark:text-ruby-400"
        >
          {{ t('DECLINED') }}
        </span>
        <span
          v-else-if="row.busy"
          class="flex-shrink-0 max-w-[45%] text-xs truncate text-amber-700 dark:text-amber-300"
          :title="row.busy"
        >
          {{ t('BUSY', { what: row.busy }) }}
        </span>
        <button
          type="button"
          class="flex-shrink-0 p-1 rounded text-slate-400 hover:text-slate-700 hover:bg-slate-100 dark:hover:bg-slate-700"
          :aria-label="t('REMOVE')"
          :data-test="'people-remove-' + row.key"
          @click="remove(row)"
        >
          <fluent-icon icon="dismiss" size="12" />
        </button>
      </li>
    </ul>
  </div>
</template>
