<!--
  Pestaña «Casos relacionados» (todos los casos menos los proyectos, que tienen «Casos del
  proyecto»): igual que esa pestaña, desde aquí se crea un caso nuevo dentro de este (de
  cualquier tipo; hereda el contacto y queda como hijo), se liga uno que ya existe
  (buscador por folio o asunto; «Relacionado» por omisión) o se quita el vínculo (el caso
  no se borra). La lista llega del padre (store); emite `changed` para que la recargue.
-->
<script>
import { mapGetters } from 'vuex';
import CaseTicketsAPI from 'dashboard/api/caseTickets';
import { toSimpleStatus } from 'dashboard/helper/caseSimpleStatus';

const LINK_TYPES = [
  'related',
  'parent_child',
  'duplicate',
  'incident_problem',
  'incident_change',
  'change_problem',
];
// Mismos colores que «Casos del proyecto».
const STATUS_PILL = {
  open: 'bg-sky-50 text-sky-800 dark:bg-sky-900/40 dark:text-sky-300',
  in_progress: 'bg-sky-50 text-sky-800 dark:bg-sky-900/40 dark:text-sky-300',
  waiting_on_customer:
    'bg-amber-50 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300',
  resolved:
    'bg-emerald-50 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300',
  closed:
    'bg-slate-100 text-slate-600 dark:bg-slate-700/60 dark:text-slate-300',
  cancelled:
    'bg-slate-100 text-slate-500 line-through dark:bg-slate-700/60 dark:text-slate-400',
};

export default {
  name: 'CaseRelations',
  props: {
    ticket: { type: Object, required: true },
    relations: { type: Array, default: () => [] },
  },
  emits: ['changed', 'open'],
  data() {
    return {
      mode: null, // 'create' | 'link'
      form: { case_type_id: '', title: '' },
      linkType: 'related',
      query: '',
      results: [],
      isSearching: false,
      isSaving: false,
      timer: null,
    };
  },
  computed: {
    ...mapGetters({ types: 'caseTickets/getTypes' }),
    isFrozen() {
      return !!this.ticket.is_frozen;
    },
    // Cualquier tipo que se pueda dar de alta.
    createTypes() {
      return (this.types || []).filter(t => !t.retired);
    },
    linkTypes() {
      return LINK_TYPES;
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchTypes');
  },
  beforeDestroy() {
    clearTimeout(this.timer);
  },
  methods: {
    classLabel(key) {
      return this.$t(
        `CASE_TICKETS.TYPES.CLASS.OPTIONS.${(key || 'support').toUpperCase()}`
      );
    },
    relationLabel(rel) {
      return this.$t(
        `CASE_TICKETS.RELATION_TYPES.${rel.relation_type}.${rel.direction}`
      );
    },
    typeLabel(type) {
      return this.$t(`CASE_TICKETS.RELATION_TYPES.${type}.outgoing`);
    },
    statusLabel(status) {
      return this.$t(`CASE_TICKETS.STATUSES.${toSimpleStatus(status)}`);
    },
    statusPill(status) {
      return STATUS_PILL[toSimpleStatus(status)] || STATUS_PILL.closed;
    },
    openCreate() {
      this.mode = 'create';
      this.form = {
        case_type_id: this.createTypes[0]?.id || '',
        title: this.ticket.title || '',
      };
    },
    openLink() {
      this.mode = 'link';
      this.linkType = 'related';
      this.query = '';
      this.results = [];
    },
    toastError(e) {
      const error = e.response?.data?.error;
      this.$emitter.emit('newToastMessage', {
        message:
          (Array.isArray(error) ? error.join(', ') : error) ||
          this.$t('CASE_TICKETS.RELATIONS.ERROR'),
        type: 'error',
      });
    },
    async save(payload) {
      this.isSaving = true;
      try {
        await CaseTicketsAPI.createRelation(this.ticket.id, payload);
        this.mode = null;
        this.$emit('changed');
      } catch (e) {
        this.toastError(e);
      } finally {
        this.isSaving = false;
      }
    },
    submitCreate() {
      if (!this.form.case_type_id) return;
      this.save({
        case_type_id: this.form.case_type_id,
        title: this.form.title.trim() || undefined,
      });
    },
    link(result) {
      this.save({ related_ticket_id: result.id, relation_type: this.linkType });
    },
    onSearchInput() {
      clearTimeout(this.timer);
      this.timer = setTimeout(this.search, 300);
    },
    // Por folio o asunto; sin este caso ni los que ya están ligados.
    async search() {
      const q = this.query.trim();
      if (q.length < 2) {
        this.results = [];
        return;
      }
      this.isSearching = true;
      try {
        const { data } = await CaseTicketsAPI.getAll({ q, per_page: 10 });
        const linked = new Set(this.relations.map(rel => rel.ticket.id));
        this.results = (data.case_tickets || []).filter(
          t => t.id !== this.ticket.id && !linked.has(t.id)
        );
      } catch (_e) {
        this.results = [];
      } finally {
        this.isSearching = false;
      }
    },
    async remove(rel) {
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.$t('CASE_TICKETS.RELATIONS.DELETE.MESSAGE')))
        return;
      try {
        await CaseTicketsAPI.deleteRelation(this.ticket.id, rel.id);
        this.$emit('changed');
      } catch (e) {
        this.toastError(e);
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col gap-3 p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
  >
    <div class="flex flex-wrap items-center gap-2">
      <h3 class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100">
        {{ $t('CASE_TICKETS.RELATIONS.TITLE') }}
      </h3>
      <span class="text-xs text-slate-500 dark:text-slate-400">
        {{ $t('CASE_TICKETS.RELATIONS.HELP') }}
      </span>
      <div v-if="!isFrozen" class="flex gap-2 ml-auto">
        <woot-button
          size="small"
          variant="smooth"
          icon="add"
          :disabled="!createTypes.length"
          @click="openCreate"
        >
          {{ $t('CASE_TICKETS.PROJECT.CHILDREN.CREATE') }}
        </woot-button>
        <woot-button
          size="small"
          variant="smooth"
          color-scheme="secondary"
          icon="link"
          @click="openLink"
        >
          {{ $t('CASE_TICKETS.PROJECT.CHILDREN.LINK') }}
        </woot-button>
      </div>
    </div>

    <!-- Crear un caso dentro de este -->
    <form
      v-if="mode === 'create'"
      class="flex flex-wrap items-end gap-3 p-3 rounded-lg bg-indigo-50 dark:bg-slate-900/40 [&_input]:!mb-0 [&_select]:!mb-0"
      @submit.prevent="submitCreate"
    >
      <label class="flex flex-col w-64 gap-1">
        <span class="text-xs text-slate-500 dark:text-slate-400">
          {{ $t('CASE_TICKETS.MODAL.CASE_TYPE_LABEL') }}
        </span>
        <select v-model="form.case_type_id" class="h-8 py-0 text-sm">
          <option v-for="t in createTypes" :key="t.id" :value="t.id">
            {{ t.name }} · {{ classLabel(t.case_class) }}
          </option>
        </select>
      </label>
      <label class="flex flex-col flex-1 min-w-[14rem] gap-1">
        <span class="text-xs text-slate-500 dark:text-slate-400">
          {{ $t('CASE_TICKETS.MODAL.TITLE_LABEL') }}
        </span>
        <input v-model="form.title" type="text" class="h-8 text-sm" />
      </label>
      <woot-button
        size="small"
        variant="clear"
        color-scheme="secondary"
        type="button"
        @click="mode = null"
      >
        {{ $t('CASE_TICKETS.CLOSURE.CANCEL') }}
      </woot-button>
      <woot-button
        size="small"
        type="submit"
        :is-loading="isSaving"
        :disabled="!form.case_type_id"
      >
        {{ $t('CASE_TICKETS.RELATIONS.CREATE_CONFIRM') }}
      </woot-button>
    </form>

    <!-- Ligar uno que ya existe -->
    <div
      v-if="mode === 'link'"
      class="flex flex-col gap-2 p-3 rounded-lg bg-indigo-50 dark:bg-slate-900/40"
    >
      <div class="flex flex-wrap items-center gap-2">
        <select v-model="linkType" class="h-8 py-0 text-sm w-52 !mb-0">
          <option v-for="type in linkTypes" :key="type" :value="type">
            {{ typeLabel(type) }}
          </option>
        </select>
        <input
          v-model="query"
          type="text"
          class="flex-1 h-8 text-sm !mb-0 min-w-[12rem]"
          :placeholder="$t('CASE_TICKETS.PROJECT.CHILDREN.SEARCH_PLACEHOLDER')"
          @input="onSearchInput"
        />
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          type="button"
          @click="mode = null"
        >
          {{ $t('CASE_TICKETS.CLOSURE.CANCEL') }}
        </woot-button>
      </div>
      <p
        v-if="query.trim().length >= 2 && !isSearching && !results.length"
        class="m-0 text-xs text-slate-500 dark:text-slate-400"
      >
        {{ $t('CASE_TICKETS.RELATIONS.NO_RESULTS') }}
      </p>
      <button
        v-for="r in results"
        :key="r.id"
        type="button"
        class="flex items-center gap-2 px-2 py-1.5 text-sm text-left rounded hover:bg-white dark:hover:bg-slate-800"
        :disabled="isSaving"
        @click="link(r)"
      >
        <span class="font-mono text-xs text-slate-500">{{
          r.folio || `#${r.id}`
        }}</span>
        <span class="truncate text-slate-700 dark:text-slate-200">{{
          r.title
        }}</span>
        <span class="ml-auto text-xs text-slate-500">{{
          classLabel(r.case_type && r.case_type.case_class)
        }}</span>
      </button>
    </div>

    <p
      v-if="!relations.length"
      class="py-4 m-0 text-sm text-center text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.RELATIONS.EMPTY') }}
    </p>
    <ul v-else class="flex flex-col gap-2 p-0 m-0 list-none">
      <li
        v-for="rel in relations"
        :key="rel.id"
        class="flex flex-wrap items-center gap-x-3 gap-y-1 px-3 py-2 border rounded-md border-slate-100 dark:border-slate-700"
      >
        <button
          type="button"
          class="font-mono text-xs font-semibold text-woot-600 dark:text-woot-300 hover:underline"
          @click="$emit('open', rel.ticket.id)"
        >
          {{ rel.ticket.folio || `#${rel.ticket.id}` }}
        </button>
        <span
          class="px-2 py-0.5 text-[11px] font-medium rounded-full bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
        >
          {{ classLabel(rel.ticket.case_class) }}
        </span>
        <span
          class="flex-1 min-w-[10rem] text-sm truncate text-slate-700 dark:text-slate-200"
          :title="rel.ticket.title"
          >{{ rel.ticket.title }}</span
        >
        <span
          class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded bg-indigo-100 text-indigo-800 dark:bg-indigo-900 dark:text-indigo-300"
        >
          {{ relationLabel(rel) }}
        </span>
        <span
          class="px-2 py-0.5 text-[11px] font-medium rounded-full whitespace-nowrap"
          :class="statusPill(rel.ticket.status)"
        >
          {{ statusLabel(rel.ticket.status) }}
        </span>
        <span
          v-if="rel.ticket.assignee"
          class="text-xs text-slate-500 dark:text-slate-400"
          >{{ rel.ticket.assignee.name }}</span
        >
        <woot-button
          v-if="!isFrozen"
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="dismiss"
          :title="$t('CASE_TICKETS.RELATIONS.REMOVE')"
          @click="remove(rel)"
        />
      </li>
    </ul>
  </div>
</template>
