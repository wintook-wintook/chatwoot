<!--
  La lupa de la barra de arriba (también Ctrl + K) — buscar una palabra en contactos,
  organizaciones y casos (todos sus campos: nombre, folio, RFC, descripción, notas,
  atributos…) y abrir el registro. El servidor (GlobalSearch) respeta los permisos.

  - Ventana ancha arriba, como el buscador del sistema.
  - Pestañas Todo · Contactos · Organizaciones · Casos con cuántos hay de cada uno.
    En «Todo» van 5 por tipo; en una pestaña, la lista completa por páginas.
  - Cada resultado: ícono del tipo, nombre, una línea de datos (organización, folio,
    estado, responsable, etapa) y, si la palabra no está en el nombre, el campo y el
    pedacito de texto donde apareció, resaltado.
  - Sin escribir: los últimos abiertos desde aquí (en este navegador) y una ayuda.
  - Teclado: ↑ ↓ para moverse, Enter abre, Esc cierra (sin indicaciones en pantalla).
  - Al final, «¿No lo encuentras? Pregúntale a Dali» le pasa la palabra al asistente.
-->
<script>
import GlobalSearchAPI from 'dashboard/api/globalSearch';
import {
  assistantState,
  toggleAssistant,
  DEFAULT_ASSISTANT_NAME,
} from 'dashboard/helper/assistantState';

const MIN_CHARS = 3;
const DEBOUNCE_MS = 300;
const GROUPS = ['contacts', 'organizations', 'cases'];
const TAB_KEYS = ['all', ...GROUPS];
const PER_GROUP = 5;
const MAX_RECENT = 6;
const T = 'QUICK_ACTIONS.SEARCH';

// Un ícono gris por tipo, sin colores (diseño minimalista).
const TYPE_ICON = {
  contacts: 'person',
  organizations: 'building-bank',
  cases: 'clipboard',
};

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

// Los últimos abiertos viven solo en este navegador; si no hay almacenamiento, no pasa nada.
const recentKey = accountId => `kontrolya.search.recent.${accountId}`;
const readRecent = accountId => {
  try {
    return JSON.parse(localStorage.getItem(recentKey(accountId)) || '[]');
  } catch {
    return [];
  }
};
const writeRecent = (accountId, list) => {
  try {
    localStorage.setItem(recentKey(accountId), JSON.stringify(list));
  } catch {
    // sin almacenamiento: no se recuerdan
  }
};

export default {
  name: 'QuickSearchModal',
  props: {
    show: { type: Boolean, default: false },
  },
  emits: ['close'],
  data() {
    return {
      query: '',
      tab: 'all',
      groups: emptyGroups(),
      searching: false,
      searched: false,
      loadingMore: false,
      timer: null,
      active: 0,
      recent: [],
      GROUPS,
      TYPE_ICON,
      TAB_KEYS,
    };
  },
  computed: {
    accountId() {
      return this.$route.params.accountId;
    },
    total() {
      return GROUPS.reduce((sum, key) => sum + this.groups[key].count, 0);
    },
    hasResults() {
      return GROUPS.some(key => this.groups[key].items.length);
    },
    tooShort() {
      const q = this.query.trim();
      return q.length > 0 && q.length < MIN_CHARS;
    },
    showRecent() {
      return !this.query.trim();
    },
    // Secciones visibles: en «Todo» los tres tipos (5 de cada uno); en una pestaña, ese.
    sections() {
      if (this.showRecent) return [];
      const keys = this.tab === 'all' ? GROUPS : [this.tab];
      return keys
        .map(key => {
          const group = this.groups[key];
          const items =
            this.tab === 'all' ? group.items.slice(0, PER_GROUP) : group.items;
          return { key, count: group.count, items };
        })
        .filter(section => section.items.length);
    },
    // Lista plana para moverse con el teclado.
    flat() {
      if (this.showRecent) {
        return this.recent.map(entry => ({
          key: entry.key,
          item: entry.item,
        }));
      }
      return this.sections.flatMap(section =>
        section.items.map(item => ({ key: section.key, item }))
      );
    },
    canLoadMore() {
      if (this.tab === 'all') return false;
      const group = this.groups[this.tab];
      return group.items.length < group.count;
    },
    assistantName() {
      return assistantState.name || DEFAULT_ASSISTANT_NAME;
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(open) {
        if (!open) return;
        this.reset();
        this.$nextTick(() => this.$refs.input?.focus());
      },
    },
    flat() {
      if (this.active >= this.flat.length) this.active = 0;
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
      this.tab = 'all';
      this.groups = emptyGroups();
      this.searched = false;
      this.active = 0;
      this.recent = readRecent(this.accountId);
    },
    onInput() {
      clearTimeout(this.timer);
      this.timer = setTimeout(this.search, DEBOUNCE_MS);
    },
    async search() {
      const q = this.query.trim();
      this.active = 0;
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
          (acc, key) => ({ ...acc, [key]: { ...data[key], page: 0 } }),
          {}
        );
        if (this.tab !== 'all') await this.loadMore();
      } catch (_e) {
        this.groups = emptyGroups();
      } finally {
        if (q === this.query.trim()) {
          this.searching = false;
          this.searched = true;
        }
      }
    },
    async selectTab(tab) {
      if (!tab || (tab !== 'all' && !this.groups[tab].count)) return;
      this.tab = tab;
      this.active = 0;
      if (tab !== 'all' && this.groups[tab].page === 0) await this.loadMore();
      this.$refs.input?.focus();
    },
    // Página 0 = solo los 5 de «Todo»; la 1 trae 20 y así sucesivamente.
    async loadMore() {
      const key = this.tab;
      const group = this.groups[key];
      if (!group.count) return;
      const page = group.page + 1;
      this.loadingMore = true;
      try {
        const { data } = await GlobalSearchAPI.search(this.query.trim(), {
          type: key,
          page,
        });
        const items = page === 1 ? [] : [...group.items];
        const seen = new Set(items.map(i => i.id));
        data[key].items.forEach(item => {
          if (!seen.has(item.id)) items.push(item);
        });
        this.groups[key] = { count: data[key].count, items, page };
      } finally {
        this.loadingMore = false;
      }
    },
    title(key, item) {
      if (key === 'cases') return `${item.folio || ''} · ${item.title}`;
      return item.name;
    },
    // La línea de datos de cada tipo.
    detail(key, item) {
      if (key === 'contacts') {
        return [
          item.organization,
          item.detail,
          item.detail !== item.email && item.email,
        ]
          .filter(Boolean)
          .join(' · ');
      }
      if (key === 'organizations') {
        const stage = item.stage
          ? this.$t(`ORGANIZATIONS.STAGES.${item.stage}`)
          : '';
        const owner = item.owner ? this.t('OWNER', { name: item.owner }) : '';
        return [stage, item.detail, owner].filter(Boolean).join(' · ');
      }
      const status = item.outcome
        ? this.t(`OUTCOMES.${item.outcome}`)
        : this.$t(`CASE_TICKETS.STATUSES.${item.status}`);
      return [
        item.type,
        status,
        item.contact,
        item.assignee || this.t('NO_ASSIGNEE'),
      ]
        .filter(Boolean)
        .join(' · ');
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
    indexOf(key, item) {
      return this.flat.findIndex(
        entry => entry.key === key && entry.item.id === item.id
      );
    },
    remember(key, item) {
      const rest = this.recent.filter(
        entry => !(entry.key === key && entry.item.id === item.id)
      );
      const { match, ...plain } = item;
      this.recent = [{ key, item: plain }, ...rest].slice(0, MAX_RECENT);
      writeRecent(this.accountId, this.recent);
    },
    clearRecent() {
      this.recent = [];
      writeRecent(this.accountId, []);
      this.$refs.input?.focus();
    },
    open(key, item) {
      const routes = {
        contacts: ['contact_profile_dashboard', { contactId: item.id }],
        organizations: ['organization_detail', { organizationId: item.id }],
        cases: ['gestorTickets_detail', { id: item.id }],
      };
      const [name, params] = routes[key];
      this.remember(key, item);
      this.$emit('close');
      this.$router.push({
        name,
        params: { accountId: this.accountId, ...params },
      });
    },
    move(step) {
      if (!this.flat.length) return;
      const size = this.flat.length;
      this.active = (this.active + step + size) % size;
      this.$nextTick(() => {
        this.$el
          .querySelector('[data-active="true"]')
          ?.scrollIntoView({ block: 'nearest' });
      });
    },
    openActive() {
      const entry = this.flat[this.active];
      if (entry) this.open(entry.key, entry.item);
    },
    askAssistant() {
      const q = this.query.trim();
      this.$emit('close');
      toggleAssistant(true);
      if (!q) return;
      this.$nextTick(() =>
        this.$emitter.emit('assistant:ask', this.t('DALI_QUESTION', { q }))
      );
    },
    onKeydown(event) {
      if (event.key === 'ArrowDown') {
        event.preventDefault();
        this.move(1);
      } else if (event.key === 'ArrowUp') {
        event.preventDefault();
        this.move(-1);
      } else if (event.key === 'Enter') {
        event.preventDefault();
        this.openActive();
      } else if (event.key === 'Escape') {
        event.preventDefault();
        this.$emit('close');
      }
    },
  },
};
</script>

<template>
  <div
    v-if="show"
    class="fixed inset-0 z-50 flex justify-center px-4 bg-slate-900/10 dark:bg-black/30"
    @mousedown.self="$emit('close')"
  >
    <div
      role="dialog"
      aria-modal="true"
      :aria-label="t('TITLE')"
      class="flex flex-col w-full max-w-2xl mt-[10vh] mb-auto overflow-hidden bg-white border shadow-lg max-h-[80vh] rounded-xl border-slate-100 dark:bg-slate-900 dark:border-slate-800"
    >
      <!-- Caja de búsqueda -->
      <div
        class="flex items-center gap-3 px-4 border-b h-14 border-slate-100 dark:border-slate-800"
      >
        <fluent-icon
          icon="search"
          size="18"
          class="flex-shrink-0 text-slate-400"
        />
        <input
          ref="input"
          v-model="query"
          type="text"
          class="flex-1 min-w-0 !mb-0 !h-12 !p-0 text-base !bg-transparent !border-0 !shadow-none focus:!ring-0 placeholder:text-slate-400"
          :aria-label="t('TITLE')"
          :placeholder="t('PLACEHOLDER')"
          @input="onInput"
          @keydown="onKeydown"
        />
        <span v-if="searching" class="text-xs text-slate-400">
          {{ t('SEARCHING') }}
        </span>
      </div>

      <!-- Pestañas por tipo (las mismas de Mi resumen) -->
      <woot-tabs
        v-if="searched && hasResults"
        class="px-4 search-tabs"
        :index="TAB_KEYS.indexOf(tab)"
        @change="index => selectTab(TAB_KEYS[index])"
      >
        <woot-tabs-item
          v-for="(tabKey, index) in TAB_KEYS"
          :key="tabKey"
          :index="index"
          :name="tabKey === 'all' ? t('ALL') : t(tabKey.toUpperCase())"
          :count="tabKey === 'all' ? total : groups[tabKey].count"
          :disabled="tabKey !== 'all' && !groups[tabKey].count"
        />
      </woot-tabs>

      <div class="flex-1 px-2 py-2 overflow-y-auto">
        <!-- Antes de escribir: los últimos abiertos y la ayuda -->
        <template v-if="showRecent">
          <div
            v-if="recent.length"
            class="flex items-center justify-between px-2 pt-1 pb-1"
          >
            <h4 class="search-heading">{{ t('RECENT') }}</h4>
            <button
              type="button"
              class="text-xs text-slate-400 hover:text-slate-600 dark:hover:text-slate-200"
              @click="clearRecent"
            >
              {{ t('CLEAR_RECENT') }}
            </button>
          </div>
          <button
            v-for="(entry, index) in recent"
            :key="`recent-${entry.key}-${entry.item.id}`"
            type="button"
            class="search-row"
            :data-active="active === index"
            @mouseenter="active = index"
            @click="open(entry.key, entry.item)"
          >
            <fluent-icon
              :icon="TYPE_ICON[entry.key]"
              size="16"
              class="search-icon"
            />
            <span class="flex flex-col min-w-0">
              <span class="truncate text-slate-800 dark:text-slate-100">
                {{ title(entry.key, entry.item) }}
              </span>
              <span class="search-sub">{{
                detail(entry.key, entry.item)
              }}</span>
            </span>
          </button>
          <p class="search-note">{{ t('HINT') }}</p>
        </template>

        <p v-else-if="tooShort" class="search-note">{{ t('MIN') }}</p>
        <p v-else-if="searched && !hasResults" class="search-note">
          {{ t('EMPTY') }}
        </p>

        <!-- Resultados -->
        <section v-for="section in sections" :key="section.key" class="mb-2">
          <div
            v-if="tab === 'all'"
            class="flex items-center justify-between px-2 pt-1 pb-1"
          >
            <h4 class="search-heading">
              {{ t(section.key.toUpperCase()) }} · {{ section.count }}
            </h4>
            <button
              v-if="section.count > section.items.length"
              type="button"
              class="text-xs text-woot-600 hover:underline dark:text-woot-300"
              @click="selectTab(section.key)"
            >
              {{ t('SEE_ALL', { count: section.count }) }}
            </button>
          </div>
          <button
            v-for="item in section.items"
            :key="`${section.key}-${item.id}`"
            type="button"
            class="search-row"
            :data-active="active === indexOf(section.key, item)"
            @mouseenter="active = indexOf(section.key, item)"
            @click="open(section.key, item)"
          >
            <fluent-icon
              :icon="TYPE_ICON[section.key]"
              size="16"
              class="search-icon"
            />
            <span class="flex flex-col min-w-0">
              <span class="truncate text-slate-800 dark:text-slate-100">
                <span
                  v-for="(part, i) in parts(title(section.key, item))"
                  :key="i"
                  :class="{ 'search-hit': part.hit }"
                  >{{ part.text }}</span
                >
              </span>
              <span class="search-sub">{{ detail(section.key, item) }}</span>
              <span v-if="item.match" class="search-sub">
                {{ t(`FIELDS.${item.match.field}`) }}:
                <span
                  v-for="(part, i) in parts(item.match.snippet)"
                  :key="i"
                  :class="{ 'search-hit': part.hit }"
                  >{{ part.text }}</span
                >
              </span>
            </span>
          </button>
        </section>
        <button
          v-if="canLoadMore"
          type="button"
          class="px-3 py-1 text-xs text-woot-600 hover:underline dark:text-woot-300"
          :disabled="loadingMore"
          @click="loadMore"
        >
          {{
            t('MORE', {
              count: groups[tab].count - groups[tab].items.length,
            })
          }}
        </button>
      </div>

      <!-- Pie: solo Dali -->
      <div class="flex justify-end px-4 py-2">
        <button
          type="button"
          class="text-xs text-slate-400 hover:text-woot-600 dark:hover:text-woot-300"
          @click="askAssistant"
        >
          {{ t('ASK_DALI', { name: assistantName }) }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.search-tabs ::v-deep .tabs {
  @apply mb-0 border-b border-slate-100 dark:border-slate-800;
}
.search-hit {
  @apply font-medium text-slate-900 bg-yellow-100/70 rounded-sm dark:text-white dark:bg-yellow-700/30;
}
.search-heading {
  @apply m-0 text-xs font-normal text-slate-400;
}
.search-row {
  @apply flex items-start w-full gap-3 px-2 py-1.5 text-sm text-left rounded-md;
}
.search-row[data-active='true'] {
  @apply bg-slate-50 dark:bg-slate-800/60;
}
.search-icon {
  @apply flex-shrink-0 mt-0.5 text-slate-400;
}
.search-sub {
  @apply w-full text-xs truncate text-slate-400;
}
.search-note {
  @apply px-2 py-3 m-0 text-sm text-slate-400;
}
</style>
