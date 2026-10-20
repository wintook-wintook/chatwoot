<!--
  @tickets_cases — Plan-Clase-Proyecto P2
  Pestaña «Casos del proyecto»: las órdenes de trabajo y los tickets de Soporte
  que pertenecen al proyecto (relación `project_member`). Desde aquí se crea uno
  nuevo dentro del proyecto (hereda el cliente), se liga uno que ya existe
  (buscador por folio o asunto) o se saca uno del proyecto (el caso no se borra).
  Emite `changed` para que la ficha refresque el avance.
-->
<script>
import { mapGetters } from 'vuex';
import CaseTicketsAPI from 'dashboard/api/caseTickets';
import { formatDay } from 'dashboard/helper/caseCommercial';
import { formatHours } from 'dashboard/helper/caseWorkOrder';
import { toSimpleStatus } from 'dashboard/helper/caseSimpleStatus';

const CHILD_CLASSES = ['work_order', 'support'];
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
  name: 'ProjectChildren',
  props: {
    ticket: { type: Object, required: true },
  },
  emits: ['changed', 'open'],
  data() {
    return {
      children: [],
      isLoading: false,
      mode: null, // 'create' | 'link'
      form: { case_type_id: '', title: '' },
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
    childTypes() {
      return (this.types || []).filter(t =>
        CHILD_CLASSES.includes(t.case_class || 'support')
      );
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchTypes');
    this.load();
  },
  beforeDestroy() {
    clearTimeout(this.timer);
  },
  methods: {
    async load() {
      this.isLoading = true;
      try {
        const { data } = await CaseTicketsAPI.getProjectChildren(
          this.ticket.id
        );
        this.children = data.project_children || [];
      } finally {
        this.isLoading = false;
      }
    },
    classLabel(key) {
      return this.$t(
        `CASE_TICKETS.TYPES.CLASS.OPTIONS.${(key || 'support').toUpperCase()}`
      );
    },
    statusLabel(status) {
      return this.$t(`CASE_TICKETS.STATUSES.${toSimpleStatus(status)}`);
    },
    statusPill(status) {
      return STATUS_PILL[toSimpleStatus(status)] || STATUS_PILL.closed;
    },
    detail(child) {
      if (child.case_class === 'work_order') {
        const visit = child.next_visit_at
          ? formatDay(child.next_visit_at)
          : '—';
        return `${this.$t(
          'CASE_TICKETS.WORK_ORDER.TABLE.NEXT_VISIT'
        )}: ${visit} · ${formatHours(child.actual_hours)} / ${formatHours(
          child.estimated_hours
        )}`;
      }
      return child.due_at
        ? `${this.$t('CASE_TICKETS.TABLE.DUE')}: ${formatDay(child.due_at)}`
        : '';
    },
    openCreate() {
      this.mode = 'create';
      this.form = {
        case_type_id: this.childTypes[0]?.id || '',
        title: this.ticket.title || '',
      };
    },
    openLink() {
      this.mode = 'link';
      this.query = '';
      this.results = [];
    },
    toastError(e) {
      this.$emitter.emit('newToastMessage', {
        message:
          e.response?.data?.error ||
          this.$t('CASE_TICKETS.PROJECT.CHILDREN.ERROR'),
        type: 'error',
      });
    },
    async add(payload) {
      this.isSaving = true;
      try {
        await CaseTicketsAPI.addProjectChild(this.ticket.id, payload);
        this.mode = null;
        await this.load();
        this.$emit('changed');
      } catch (e) {
        this.toastError(e);
      } finally {
        this.isSaving = false;
      }
    },
    submitCreate() {
      if (!this.form.case_type_id) return;
      this.add({
        case_type_id: this.form.case_type_id,
        title: this.form.title.trim() || undefined,
      });
    },
    onSearchInput() {
      clearTimeout(this.timer);
      this.timer = setTimeout(this.search, 300);
    },
    // Busca por folio o asunto; solo órdenes y tickets que aún no estén aquí.
    async search() {
      const q = this.query.trim();
      if (q.length < 2) {
        this.results = [];
        return;
      }
      this.isSearching = true;
      try {
        const { data } = await CaseTicketsAPI.getAll({ q, per_page: 10 });
        const inHere = new Set(this.children.map(c => c.id));
        this.results = (data.case_tickets || []).filter(
          t =>
            t.id !== this.ticket.id &&
            !inHere.has(t.id) &&
            CHILD_CLASSES.includes(t.case_type?.case_class || 'support')
        );
      } catch (_e) {
        this.results = [];
      } finally {
        this.isSearching = false;
      }
    },
    async remove(child) {
      try {
        await CaseTicketsAPI.removeProjectChild(this.ticket.id, child.id);
        await this.load();
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
        {{ $t('CASE_TICKETS.PROJECT.CHILDREN.TITLE') }}
      </h3>
      <span class="text-xs text-slate-500 dark:text-slate-400">
        {{ $t('CASE_TICKETS.PROJECT.CHILDREN.HELP') }}
      </span>
      <div v-if="!isFrozen" class="flex gap-2 ml-auto">
        <woot-button
          size="small"
          variant="smooth"
          icon="add"
          :disabled="!childTypes.length"
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

    <!-- Crear dentro del proyecto -->
    <form
      v-if="mode === 'create'"
      class="flex flex-wrap items-end gap-3 p-3 rounded-lg bg-indigo-50 dark:bg-slate-900/40 [&_input]:!mb-0 [&_select]:!mb-0"
      @submit.prevent="submitCreate"
    >
      <label class="flex flex-col w-56 gap-1">
        <span class="text-xs text-slate-500 dark:text-slate-400">
          {{ $t('CASE_TICKETS.MODAL.CASE_TYPE_LABEL') }}
        </span>
        <select v-model="form.case_type_id" class="h-8 py-0 text-sm">
          <option v-for="t in childTypes" :key="t.id" :value="t.id">
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
        {{ $t('CASE_TICKETS.PROJECT.CHILDREN.CREATE_CONFIRM') }}
      </woot-button>
    </form>

    <!-- Ligar uno que ya existe -->
    <div
      v-if="mode === 'link'"
      class="flex flex-col gap-2 p-3 rounded-lg bg-indigo-50 dark:bg-slate-900/40"
    >
      <div class="flex items-center gap-2">
        <input
          v-model="query"
          type="text"
          class="flex-1 h-8 text-sm !mb-0"
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
        {{ $t('CASE_TICKETS.PROJECT.CHILDREN.NO_RESULTS') }}
      </p>
      <button
        v-for="r in results"
        :key="r.id"
        type="button"
        class="flex items-center gap-2 px-2 py-1.5 text-sm text-left rounded hover:bg-white dark:hover:bg-slate-800"
        :disabled="isSaving"
        @click="add({ ticket_id: r.id })"
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
      v-if="!isLoading && !children.length"
      class="py-4 m-0 text-sm text-center text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.PROJECT.CHILDREN.EMPTY') }}
    </p>
    <ul v-else class="flex flex-col gap-2 p-0 m-0 list-none">
      <li
        v-for="child in children"
        :key="child.id"
        class="flex flex-wrap items-center gap-x-3 gap-y-1 px-3 py-2 border rounded-md border-slate-100 dark:border-slate-700"
      >
        <button
          type="button"
          class="font-mono text-xs font-semibold text-woot-600 dark:text-woot-300 hover:underline"
          @click="$emit('open', child.id)"
        >
          {{ child.folio || `#${child.id}` }}
        </button>
        <span
          class="px-2 py-0.5 text-[11px] font-medium rounded-full bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
        >
          {{ classLabel(child.case_class) }}
        </span>
        <span
          class="flex-1 min-w-[10rem] text-sm truncate text-slate-700 dark:text-slate-200"
          :title="child.title"
          >{{ child.title }}</span
        >
        <span
          class="px-2 py-0.5 text-[11px] font-medium rounded-full whitespace-nowrap"
          :class="statusPill(child.status)"
        >
          {{ statusLabel(child.status) }}
        </span>
        <span
          v-if="child.assignee"
          class="text-xs text-slate-500 dark:text-slate-400"
          >{{ child.assignee.name }}</span
        >
        <span
          v-if="detail(child)"
          class="w-full text-xs tabular-nums text-slate-500 dark:text-slate-400"
          >{{ detail(child) }}</span
        >
        <woot-button
          v-if="!isFrozen"
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="dismiss"
          :title="$t('CASE_TICKETS.PROJECT.CHILDREN.REMOVE')"
          @click="remove(child)"
        />
      </li>
    </ul>
  </div>
</template>
