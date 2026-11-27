<!--
  Campaña con Vendedor IA — «A quién»: los contadores (que filtran), la lista por páginas con buscador, quitar o
  regresar a varios a la vez y «Descargar lista» (Motor2CampaignsAPI.preview / previewCsv → TrackingCampaigns::AudiencePage).
  Sirve para todos los tipos de campaña.
    reloadKey   al cambiar, vuelve a contar (la pantalla lo sube cuando cambia la audiencia o el canal)
    payload, inboxId, excluded (.sync), facts, isWhatsapp, factLine (lo último que compró / lo que le vence)
  emit loaded (la respuesta: sus counts) · loading
-->
<script>
import { useAlert } from 'dashboard/composables';
import Motor2CampaignsAPI from 'dashboard/api/motor2Campaigns';

const BUCKETS = ['ready', 'in_tracking', 'unreachable', 'excluded'];
const PER_PAGE = 50;

export default {
  name: 'AudienceList',
  props: {
    reloadKey: { type: Number, default: 0 },
    payload: { type: Array, default: () => [] },
    inboxId: { type: [Number, String], default: '' },
    excluded: { type: Array, default: () => [] },
    facts: { type: Boolean, default: false },
    isWhatsapp: { type: Boolean, default: false },
    factLine: { type: Function, default: () => '' },
  },
  emits: ['update:excluded', 'loaded', 'loading'],
  data() {
    return {
      buckets: BUCKETS,
      bucket: 'all',
      q: '',
      page: 1,
      result: null,
      loading: false,
      working: false,
      timer: null,
    };
  },
  computed: {
    counts() {
      return this.result?.counts || {};
    },
    rows() {
      return this.result?.contacts || [];
    },
    matching() {
      return this.result?.matching ?? 0;
    },
    pages() {
      return Math.max(1, Math.ceil(this.matching / PER_PAGE));
    },
    from() {
      return this.matching ? (this.page - 1) * PER_PAGE + 1 : 0;
    },
    to() {
      return Math.min(this.page * PER_PAGE, this.matching);
    },
    filtered() {
      return this.bucket !== 'all' || !!this.q.trim();
    },
  },
  watch: {
    reloadKey: {
      immediate: true,
      handler() {
        this.fetch();
      },
    },
    q() {
      clearTimeout(this.timer);
      this.timer = setTimeout(() => {
        this.page = 1;
        this.fetch();
      }, 300);
    },
  },
  beforeDestroy() {
    clearTimeout(this.timer);
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.AUDIENCE.${key}`, params);
    },
    body(extra = {}) {
      return {
        payload: this.payload,
        template_id: null,
        inbox_id: this.inboxId,
        excluded_contact_ids: this.excluded,
        bucket: this.bucket,
        q: this.q.trim(),
        page: this.page,
        per_page: PER_PAGE,
        facts: this.facts ? 1 : undefined,
        ...extra,
      };
    },
    async fetch() {
      this.loading = true;
      this.$emit('loading', true);
      try {
        const { data } = await Motor2CampaignsAPI.preview(this.body());
        this.result = data;
        if (this.page > 1 && !data.contacts?.length && data.matching) {
          this.page = Math.ceil(data.matching / PER_PAGE);
          this.fetch();
          return;
        }
        this.$emit('loaded', data);
      } catch (e) {
        this.result = null;
        this.$emit('loaded', null);
      } finally {
        this.loading = false;
        this.$emit('loading', false);
      }
    },
    setBucket(bucket) {
      this.bucket = this.bucket === bucket ? 'all' : bucket;
      this.page = 1;
      this.fetch();
    },
    go(page) {
      this.page = Math.min(Math.max(page, 1), this.pages);
      this.fetch();
    },
    reasonText(c) {
      return c.reason
        ? this.t(`REASON.${c.reason}`)
        : this.t(`BUCKETS.${c.bucket}`);
    },
    toggle(id) {
      const list = this.excluded.includes(id)
        ? this.excluded.filter(x => x !== id)
        : [...this.excluded, id];
      this.$emit('update:excluded', list);
    },
    // Quitar o regresar a TODOS los de este filtro o búsqueda (no solo la página).
    async bulk(remove) {
      this.working = true;
      try {
        const { data } = await Motor2CampaignsAPI.preview(
          this.body({ ids: 1, page: 1 })
        );
        const ids = data.ids || [];
        const list = remove
          ? [...new Set([...this.excluded, ...ids])]
          : this.excluded.filter(id => !ids.includes(id));
        this.$emit('update:excluded', list);
      } catch (e) {
        useAlert(this.t('BULK_ERROR'));
      } finally {
        this.working = false;
      }
    },
    async download() {
      this.working = true;
      try {
        const { data } = await Motor2CampaignsAPI.previewCsv(
          this.body({ page: 1 })
        );
        const url = URL.createObjectURL(data);
        const link = document.createElement('a');
        link.href = url;
        link.download = this.t('CSV_NAME');
        link.click();
        URL.revokeObjectURL(url);
      } catch (e) {
        useAlert(this.t('BULK_ERROR'));
      } finally {
        this.working = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <p v-if="loading && !result" class="m-0 text-xs text-slate-500">
      {{ t('COUNTING') }}
    </p>
    <p
      v-else-if="result && result.counts_only"
      class="m-0 text-xs text-amber-700"
    >
      {{ t('TOO_MANY', { n: counts.total || 0 }) }}
    </p>
    <template v-else-if="result">
      <!-- Los contadores filtran la lista (otro clic, todos) -->
      <div class="grid grid-cols-2 gap-2 sm:grid-cols-4">
        <button
          v-for="b in buckets"
          :key="b"
          type="button"
          class="p-2 text-left bg-white border rounded-md dark:bg-slate-900"
          :class="
            bucket === b
              ? 'border-woot-500 ring-1 ring-woot-500'
              : 'border-transparent hover:border-slate-200 dark:hover:border-slate-600'
          "
          @click="setBucket(b)"
        >
          <span class="block text-lg font-semibold">{{ counts[b] || 0 }}</span>
          <span class="block text-xs text-slate-500">
            {{ t(`BUCKETS.${b}`) }}
          </span>
        </button>
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <input
          v-model="q"
          type="text"
          class="!mb-0 !w-64 max-w-full text-sm"
          :placeholder="t('SEARCH')"
        />
        <span class="text-xs text-slate-500">
          {{
            filtered
              ? t('SHOWING_FILTERED', { from, to, n: matching })
              : t('SHOWING', { from, to, n: matching })
          }}
        </span>
        <span class="flex flex-wrap gap-2 ml-auto">
          <woot-button
            v-if="matching && bucket !== 'excluded'"
            size="small"
            variant="smooth"
            color-scheme="alert"
            :is-loading="working"
            @click="bulk(true)"
          >
            {{ t('REMOVE_ALL', { n: matching }) }}
          </woot-button>
          <woot-button
            v-if="matching && (bucket === 'excluded' || counts.excluded)"
            size="small"
            variant="smooth"
            color-scheme="secondary"
            :is-loading="working"
            @click="bulk(false)"
          >
            {{ t('RESTORE_ALL', { n: matching }) }}
          </woot-button>
          <woot-button
            v-if="matching"
            size="small"
            variant="smooth"
            color-scheme="secondary"
            icon="arrow-download"
            :is-loading="working"
            @click="download"
          >
            {{ t('DOWNLOAD') }}
          </woot-button>
        </span>
      </div>

      <div
        class="overflow-y-auto bg-white border rounded-md max-h-96 dark:bg-slate-900 border-slate-100 dark:border-slate-700"
        :class="loading ? 'opacity-60' : ''"
      >
        <table class="w-full text-sm">
          <thead class="sticky top-0 bg-slate-25 dark:bg-slate-800">
            <tr class="text-xs text-left text-slate-500">
              <th class="w-8 py-1 pl-2" />
              <th class="py-1 font-normal">{{ t('COL.NAME') }}</th>
              <th class="py-1 font-normal">{{ t('COL.COMPANY') }}</th>
              <th class="py-1 font-normal">
                {{ isWhatsapp ? t('COL.PHONE') : t('COL.EMAIL') }}
              </th>
              <th class="py-1 pr-2 font-normal">{{ t('COL.STATUS') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="c in rows"
              :key="c.id"
              class="border-t border-slate-50 dark:border-slate-800"
              :class="c.excluded ? 'text-slate-400' : ''"
            >
              <td class="py-1 pl-2">
                <input
                  type="checkbox"
                  class="!m-0"
                  :checked="!c.excluded"
                  :aria-label="c.name"
                  @change="toggle(c.id)"
                />
              </td>
              <td class="py-1">
                {{ c.name }}
                <span
                  v-if="factLine(c)"
                  class="block text-xs text-woot-700 dark:text-woot-300"
                >
                  {{ factLine(c) }}
                </span>
              </td>
              <td class="py-1 text-xs text-slate-500">
                {{ c.company || '—' }}
              </td>
              <td class="py-1 text-xs text-slate-500">
                {{ (isWhatsapp ? c.phone_number : c.email) || '—' }}
              </td>
              <td class="py-1 pr-2 text-xs">
                <span v-if="c.excluded" class="text-slate-500">
                  {{ t('BUCKETS.excluded') }}
                </span>
                <span v-else-if="c.bucket !== 'ready'" class="text-amber-700">
                  {{ reasonText(c) }}
                </span>
                <span v-else class="text-green-700 dark:text-green-400">
                  {{ t('READY') }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!rows.length" class="m-0 p-3 text-xs text-slate-500">
          {{ t('NO_MATCH') }}
        </p>
      </div>

      <div v-if="pages > 1" class="flex items-center justify-end gap-2 text-xs">
        <woot-button
          size="tiny"
          variant="smooth"
          color-scheme="secondary"
          :disabled="page <= 1"
          @click="go(page - 1)"
        >
          {{ t('PREV') }}
        </woot-button>
        <span>{{ t('PAGE', { page, pages }) }}</span>
        <woot-button
          size="tiny"
          variant="smooth"
          color-scheme="secondary"
          :disabled="page >= pages"
          @click="go(page + 1)"
        >
          {{ t('NEXT') }}
        </woot-button>
      </div>
    </template>
  </div>
</template>
