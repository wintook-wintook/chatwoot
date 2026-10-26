<!--
  @tickets_cases — «Tienes avisos importantes» en Mi día
  Botón tipo globo (como el de SLA vencido): rojo si hay algo de peso alto, ámbar
  si no; no se ve si no hay nada. Al presionarlo despliega los avisos sin leer
  ordenados por peso, cada uno con su folio y «Enterado» (lo marca leído también
  en la campanita). Se refresca solo cuando cambia el contador de la campanita.
-->
<script>
import { mapGetters } from 'vuex';
import CaseNoticesAPI from 'dashboard/api/caseNotices';

const T = 'CASE_TICKETS.TASKS.MY_DAY.NOTICES';

export default {
  name: 'MyDayNotices',
  data() {
    return { notices: [], open: false, markingId: null };
  },
  computed: {
    ...mapGetters({ notificationMeta: 'notifications/getMeta' }),
    unreadCount() {
      return (this.notificationMeta && this.notificationMeta.unreadCount) || 0;
    },
    hasHigh() {
      return this.notices.some(n => n.weight === 'high');
    },
  },
  watch: {
    unreadCount() {
      this.load();
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async load() {
      try {
        const { data } = await CaseNoticesAPI.get();
        this.notices = data.notices || [];
      } catch (_e) {
        this.notices = [];
      }
      if (!this.notices.length) this.open = false;
    },
    async acknowledge(notice) {
      this.markingId = notice.id;
      try {
        await CaseNoticesAPI.markRead(notice.id);
        this.notices = this.notices.filter(n => n.id !== notice.id);
        this.$store.dispatch('notifications/unReadCount');
      } finally {
        this.markingId = null;
      }
    },
    go(notice) {
      const { link } = notice;
      const accountId = this.$route.params.accountId;
      if (link.kind === 'case') {
        this.$router.push({
          name: 'gestorTickets_detail',
          params: { id: link.id },
        });
      } else if (link.kind === 'conversation') {
        this.$router.push(
          `/app/accounts/${accountId}/conversations/${link.id}`
        );
      }
    },
    when(ts) {
      return new Date(ts * 1000).toLocaleString();
    },
  },
};
</script>

<template>
  <div v-if="notices.length" class="flex flex-col gap-2">
    <button
      type="button"
      class="flex items-center self-start h-8 gap-1.5 px-3 text-xs font-medium border rounded-full"
      :class="
        hasHigh
          ? 'bg-red-100 text-red-800 border-red-200 dark:bg-red-900/40 dark:text-red-300 dark:border-red-800'
          : 'bg-amber-50 text-amber-800 border-amber-200 dark:bg-amber-900/30 dark:text-amber-200 dark:border-amber-800'
      "
      :aria-expanded="open"
      @click="open = !open"
    >
      <fluent-icon icon="alert" size="12" />
      {{ t('BUTTON', { count: notices.length }) }}
      <fluent-icon :icon="open ? 'chevron-up' : 'chevron-down'" size="12" />
    </button>

    <ul
      v-if="open"
      class="flex flex-col gap-1 p-0 m-0 list-none border rounded-lg border-slate-200 dark:border-slate-700"
    >
      <li
        v-for="n in notices"
        :key="n.id"
        class="flex items-start gap-3 px-3 py-2 border-b last:border-b-0 border-slate-100 dark:border-slate-800"
      >
        <span
          class="flex-shrink-0 w-2 h-2 mt-1.5 rounded-full"
          :class="n.weight === 'high' ? 'bg-red-500' : 'bg-amber-400'"
        />
        <div
          role="button"
          tabindex="0"
          class="flex flex-col items-start flex-1 min-w-0 text-left cursor-pointer"
          @click="go(n)"
          @keydown.enter="go(n)"
        >
          <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
            {{ n.title }}
          </span>
          <span
            v-if="n.body"
            class="text-xs truncate text-slate-500 dark:text-slate-400"
          >
            {{ n.body }}
          </span>
          <span class="text-[11px] text-slate-400 dark:text-slate-500">
            {{ when(n.created_at) }}
          </span>
        </div>
        <woot-button
          size="tiny"
          variant="smooth"
          color-scheme="secondary"
          icon="checkmark"
          :is-loading="markingId === n.id"
          @click="acknowledge(n)"
        >
          {{ t('ACK') }}
        </woot-button>
      </li>
    </ul>
  </div>
</template>
