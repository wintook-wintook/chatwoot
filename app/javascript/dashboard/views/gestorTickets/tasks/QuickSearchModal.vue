<!--
  La lupa de la barra de arriba — buscar una palabra en contactos, organizaciones y
  casos (todos sus campos: nombre, folio, RFC, descripción, notas, atributos…) y abrir
  el registro. El servidor (GlobalSearch) respeta los permisos de quien busca.
  Cuando la palabra no está en el nombre o título, se ve el campo y el pedacito de
  texto donde apareció, con la palabra resaltada. «Ver más» trae el resto del grupo.
-->
<script>
import GlobalSearchAPI from 'dashboard/api/globalSearch';

const MIN_CHARS = 3;
const DEBOUNCE_MS = 300;
const GROUPS = ['contacts', 'organizations', 'cases'];
const T = 'QUICK_ACTIONS.SEARCH';

const emptyGroups = () =>
  GROUPS.reduce(
    (acc, key) => ({ ...acc, [key]: { count: 0, items: [], page: 1 } }),
    {}
  );
// Sin acentos ni mayúsculas, letra por letra (mismo largo que el texto).
const fold = text =>
  Array.from(String(text || ''))
    .map(ch => ch.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase())
    .map(ch => (ch.length === 1 ? ch : ' '))
    .join('');

export default {
  name: 'QuickSearchModal',
  props: {
    show: { type: Boolean, default: false },
  },
  emits: ['close'],
  data() {
    return {
      query: '',
      groups: emptyGroups(),
      searching: false,
      searched: false,
      loadingMore: null,
      timer: null,
      GROUPS,
    };
  },
  computed: {
    hasResults() {
      return GROUPS.some(key => this.groups[key].items.length);
    },
    tooShort() {
      const q = this.query.trim();
      return q.length > 0 && q.length < MIN_CHARS;
    },
    // Enter abre el primero.
    first() {
      const key = GROUPS.find(k => this.groups[k].items.length);
      return key ? { key, item: this.groups[key].items[0] } : null;
    },
  },
  watch: {
    show(open) {
      if (!open) return;
      this.reset();
      this.$nextTick(() => this.$refs.input?.focus());
    },
  },
  beforeDestroy() {
    clearTimeout(this.timer);
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    reset() {
      this.query = '';
      this.groups = emptyGroups();
      this.searched = false;
    },
    onInput() {
      clearTimeout(this.timer);
      this.timer = setTimeout(this.search, DEBOUNCE_MS);
    },
    async search() {
      const q = this.query.trim();
      if (q.length < MIN_CHARS) {
        this.groups = emptyGroups();
        this.searched = false;
        this.searching = false;
        return;
      }
      this.searching = true;
      try {
        const { data } = await GlobalSearchAPI.search(q);
        if (q !== this.query.trim()) return; // una respuesta vieja no pisa la actual
        this.groups = GROUPS.reduce(
          (acc, key) => ({ ...acc, [key]: { ...data[key], page: 1 } }),
          {}
        );
      } catch (_e) {
        this.groups = emptyGroups();
      } finally {
        if (q === this.query.trim()) {
          this.searching = false;
          this.searched = true;
        }
      }
    },
    // La primera vez «ver más» pide la página 1 de 20; después, la siguiente.
    async loadMore(key) {
      const group = this.groups[key];
      const page = group.items.length <= 5 ? 1 : group.page + 1;
      this.loadingMore = key;
      try {
        const { data } = await GlobalSearchAPI.search(this.query.trim(), {
          type: key,
          page,
        });
        const seen = new Set(page === 1 ? [] : group.items.map(i => i.id));
        const items = page === 1 ? [] : [...group.items];
        data[key].items.forEach(item => {
          if (!seen.has(item.id)) items.push(item);
        });
        this.groups[key] = { count: data[key].count, items, page };
      } finally {
        this.loadingMore = null;
      }
    },
    title(key, item) {
      if (key === 'cases') return `${item.folio || ''} · ${item.title}`;
      return item.name;
    },
    detail(key, item) {
      if (key === 'cases') return item.type || '';
      if (key === 'organizations') {
        const stage = item.stage
          ? this.$t(`ORGANIZATIONS.STAGES.${item.stage}`)
          : '';
        return [stage, item.detail].filter(Boolean).join(' · ');
      }
      return item.detail || '';
    },
    // [{ text, hit }] para resaltar la palabra sin usar v-html.
    parts(text) {
      const q = fold(this.query.trim());
      const source = String(text || '');
      const folded = fold(source);
      if (!q) return [{ text: source, hit: false }];
      const out = [];
      let from = 0;
      let at = folded.indexOf(q);
      while (at !== -1) {
        if (at > from) out.push({ text: source.slice(from, at), hit: false });
        out.push({ text: source.slice(at, at + q.length), hit: true });
        from = at + q.length;
        at = folded.indexOf(q, from);
      }
      if (from < source.length) {
        out.push({ text: source.slice(from), hit: false });
      }
      return out;
    },
    open(key, item) {
      const routes = {
        contacts: ['contact_profile_dashboard', { contactId: item.id }],
        organizations: ['organization_detail', { organizationId: item.id }],
        cases: ['gestorTickets_detail', { id: item.id }],
      };
      const [name, params] = routes[key];
      this.$emit('close');
      this.$router.push({
        name,
        params: { accountId: this.$route.params.accountId, ...params },
      });
    },
    openFirst() {
      if (this.first) this.open(this.first.key, this.first.item);
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')">
    <woot-modal-header :header-title="t('TITLE')" />
    <div class="px-6 pb-6 space-y-3">
      <input
        ref="input"
        v-model="query"
        type="search"
        class="w-full !mb-0"
        :aria-label="t('TITLE')"
        :placeholder="t('PLACEHOLDER')"
        @input="onInput"
        @keydown.enter.prevent="openFirst"
      />
      <p v-if="tooShort" class="m-0 text-sm text-slate-500 dark:text-slate-400">
        {{ t('MIN') }}
      </p>
      <p
        v-else-if="searching"
        class="m-0 text-sm text-slate-500 dark:text-slate-400"
      >
        {{ t('SEARCHING') }}
      </p>
      <p
        v-else-if="searched && !hasResults"
        class="m-0 text-sm text-slate-500 dark:text-slate-400"
      >
        {{ t('EMPTY') }}
      </p>
      <div class="space-y-3 overflow-y-auto max-h-[60vh]">
        <template v-for="key in GROUPS">
          <section v-if="groups[key].items.length" :key="key">
            <h4
              class="m-0 mb-1 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
            >
              {{ t(key.toUpperCase()) }} ({{ groups[key].count }})
            </h4>
            <button
              v-for="item in groups[key].items"
              :key="`${key}-${item.id}`"
              type="button"
              class="flex flex-col items-start w-full gap-0.5 px-2 py-2 text-sm text-left rounded-md hover:bg-slate-50 dark:hover:bg-slate-700"
              @click="open(key, item)"
            >
              <span class="flex items-center justify-between w-full gap-3">
                <span class="truncate text-slate-800 dark:text-slate-100">
                  <span
                    v-for="(part, i) in parts(title(key, item))"
                    :key="i"
                    :class="{ 'search-hit': part.hit }"
                    >{{ part.text }}</span
                  >
                </span>
                <span
                  class="flex-shrink-0 text-xs truncate text-slate-500 dark:text-slate-400"
                >
                  {{ detail(key, item) }}
                </span>
              </span>
              <span
                v-if="item.match"
                class="w-full text-xs text-left truncate text-slate-500 dark:text-slate-400"
              >
                {{ t(`FIELDS.${item.match.field}`) }}:
                <span
                  v-for="(part, i) in parts(item.match.snippet)"
                  :key="i"
                  :class="{ 'search-hit': part.hit }"
                  >{{ part.text }}</span
                >
              </span>
            </button>
            <button
              v-if="groups[key].items.length < groups[key].count"
              type="button"
              class="px-2 py-1 text-xs text-woot-600 hover:underline dark:text-woot-300"
              :disabled="loadingMore === key"
              @click="loadMore(key)"
            >
              {{
                t('MORE', {
                  count: groups[key].count - groups[key].items.length,
                })
              }}
            </button>
          </section>
        </template>
      </div>
    </div>
  </woot-modal>
</template>

<style scoped>
.search-hit {
  @apply font-semibold bg-yellow-100 rounded-sm dark:bg-yellow-700/40;
}
</style>
