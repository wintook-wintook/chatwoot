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
  - Teclado: ↑ ↓ para moverse, Enter abre, Esc cierra.
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
const PER_GROUP = 5;
const MAX_RECENT = 6;
const T = 'QUICK_ACTIONS.SEARCH';
// Nombres de las teclas (iguales en todos los idiomas).
const KEYS = { up: '↑', down: '↓', enter: 'Enter', esc: 'Esc' };

const TYPE_STYLE = {
  contacts: {
    icon: 'person',
    chip: 'bg-woot-75 text-woot-600 dark:bg-woot-800/60 dark:text-woot-200',
  },
  organizations: {
    icon: 'building-bank',
    chip: 'bg-amber-75 text-amber-700 dark:bg-amber-800/60 dark:text-amber-200',
  },
  cases: {
    icon: 'clipboard',
    chip: 'bg-teal-50 text-teal-700 dark:bg-teal-800/60 dark:text-teal-200',
  },
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
      TYPE_STYLE,
      KEYS,
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
    keyHints() {
      return [
        { keys: [KEYS.up, KEYS.down], label: this.t('KEY_MOVE') },
        { keys: [KEYS.enter], label: this.t('KEY_OPEN') },
        { keys: [KEYS.esc], label: this.t('KEY_CLOSE') },
      ];
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
    class="fixed inset-0 z-50 flex justify-center px-4 bg-slate-900/40 dark:bg-black/60"
    @mousedown.self="$emit('close')"
  >
    <div
      role="dialog"
      aria-modal="true"
      :aria-label="t('TITLE')"
      class="flex flex-col w-full max-w-2xl mt-[10vh] mb-auto overflow-hidden bg-white shadow-2xl max-h-[80vh] rounded-xl dark:bg-slate-900 ring-1 ring-slate-200 dark:ring-slate-700"
    >
      <!-- Caja de búsqueda -->
      <div
        class="flex items-center gap-3 px-4 border-b h-14 border-slate-100 dark:border-slate-800"
      >
        <fluent-icon
          icon="search"
          size="20"
          class="flex-shrink-0 text-slate-400"
        />
        <input
          ref="input"
          v-model="query"
          type="search"
          class="flex-1 min-w-0 !mb-0 !h-12 !p-0 text-base !bg-transparent !border-0 !shadow-none focus:!ring-0 placeholder:text-slate-400"
          :aria-label="t('TITLE')"
          :placeholder="t('PLACEHOLDER')"
          @input="onInput"
          @keydown="onKeydown"
        />
        <span v-if="searching" class="text-xs text-slate-400">
          {{ t('SEARCHING') }}
        </span>
        <kbd class="search-kbd">{{ KEYS.esc }}</kbd>
      </div>

      <!-- Pestañas por tipo -->
      <div
        v-if="searched && hasResults"
        class="flex gap-1 px-3 pt-2 pb-1 overflow-x-auto"
      >
        <button
          v-for="tabKey in ['all', ...GROUPS]"
          :key="tabKey"
          type="button"
          class="flex items-center gap-1.5 px-3 py-1 text-sm rounded-full whitespace-nowrap disabled:opacity-40 disabled:cursor-default"
          :disabled="tabKey !== 'all' && !groups[tabKey].count"
          :class="
            tab === tabKey
              ? 'bg-woot-50 text-woot-700 font-medium dark:bg-woot-900/40 dark:text-woot-200'
              : 'text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800'
          "
          @click="selectTab(tabKey)"
        >
          {{ tabKey === 'all' ? t('ALL') : t(tabKey.toUpperCase()) }}
          <span class="text-xs text-slate-400">
            {{ tabKey === 'all' ? total : groups[tabKey].count }}
          </span>
        </button>
      </div>

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
            <span class="search-icon" :class="TYPE_STYLE[entry.key].chip">
              <fluent-icon :icon="TYPE_STYLE[entry.key].icon" size="16" />
            </span>
            <span class="flex flex-col min-w-0">
              <span class="truncate text-slate-800 dark:text-slate-100">
                {{ title(entry.key, entry.item) }}
              </span>
              <span class="search-sub">{{
                detail(entry.key, entry.item)
              }}</span>
            </span>
            <fluent-icon
              icon="clock"
              size="14"
              class="flex-shrink-0 ml-auto text-slate-300"
            />
          </button>
          <p
            class="flex items-start gap-2 px-3 py-3 m-0 text-sm text-slate-500"
          >
            <fluent-icon icon="search" size="16" class="flex-shrink-0 mt-0.5" />
            {{ t('HINT') }}
          </p>
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
              {{ t(section.key.toUpperCase()) }} ({{ section.count }})
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
            <span class="search-icon" :class="TYPE_STYLE[section.key].chip">
              <fluent-icon :icon="TYPE_STYLE[section.key].icon" size="16" />
            </span>
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

      <!-- Pie: teclas y Dali -->
      <div
        class="flex items-center justify-between gap-3 px-4 py-2 text-xs border-t text-slate-500 border-slate-100 dark:border-slate-800 bg-slate-25 dark:bg-slate-800/50"
      >
        <span class="items-center hidden gap-3 sm:flex">
          <span v-for="hint in keyHints" :key="hint.label">
            <kbd v-for="k in hint.keys" :key="k" class="mr-0.5 search-kbd">
              {{ k }}
            </kbd>
            {{ hint.label }}
          </span>
        </span>
        <button
          type="button"
          class="flex items-center gap-1 ml-auto text-woot-600 hover:underline dark:text-woot-300"
          @click="askAssistant"
        >
          <fluent-icon icon="wand" size="14" />
          {{ t('ASK_DALI', { name: assistantName }) }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.search-hit {
  @apply font-semibold bg-yellow-100 rounded-sm dark:bg-yellow-700/40;
}
.search-heading {
  @apply m-0 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400;
}
.search-row {
  @apply flex items-center w-full gap-3 px-2 py-2 text-sm text-left rounded-lg;
}
.search-row[data-active='true'] {
  @apply bg-slate-100 dark:bg-slate-800;
}
.search-icon {
  @apply flex items-center justify-center flex-shrink-0 rounded-lg w-8 h-8;
}
.search-sub {
  @apply w-full text-xs truncate text-slate-500 dark:text-slate-400;
}
.search-note {
  @apply px-3 py-3 m-0 text-sm text-slate-500 dark:text-slate-400;
}
.search-kbd {
  @apply px-1.5 py-0.5 font-sans text-[11px] border rounded border-slate-200 bg-white text-slate-500 dark:bg-slate-800 dark:border-slate-600;
}
</style>
