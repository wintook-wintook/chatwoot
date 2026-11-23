<!--
  Cobranza › Comprobantes: los «ya pagué» que registró el agente, con el archivo que mandó el cliente. El cobrador los
  valida (sus facturas no se cobran hasta que el corte las traiga pagadas) o los rechaza (se le vuelve a cobrar).
-->
<script>
import { useAlert } from 'dashboard/composables';
import CollectionsAPI from 'dashboard/api/collections';
import { money, shortDate } from './money';

export default {
  name: 'ClaimsPanel',
  emits: ['changed'],
  data() {
    return { status: 'pending', rows: [], loading: false, busy: null };
  },
  mounted() {
    this.load();
  },
  methods: {
    money,
    shortDate,
    t(key, params) {
      return this.$t(`COLLECTIONS.CLAIMS.${key}`, params);
    },
    async load() {
      this.loading = true;
      try {
        const { data } = await CollectionsAPI.claims({ status: this.status });
        this.rows = data;
      } finally {
        this.loading = false;
      }
    },
    async review(row, decision) {
      // eslint-disable-next-line no-alert
      const note =
        decision === 'reject' ? window.prompt(this.t('REJECT_NOTE')) : '';
      if (note === null) return;
      this.busy = row.id;
      try {
        await CollectionsAPI.reviewClaim(row.id, decision, note);
        await this.load();
        this.$emit('changed');
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ERROR'));
      } finally {
        this.busy = null;
      }
    },
    openConversation(id) {
      this.$router.push({
        name: 'inbox_conversation',
        params: { conversation_id: id },
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex gap-2">
      <button
        v-for="s in ['pending', 'validated', 'rejected']"
        :key="s"
        type="button"
        class="px-3 py-1 text-sm border rounded-full"
        :class="
          status === s
            ? 'border-woot-500 text-woot-700'
            : 'border-slate-200 dark:border-slate-600 text-slate-600'
        "
        @click="
          status = s;
          load();
        "
      >
        {{ t(`STATUS.${s}`) }}
      </button>
    </div>
    <p class="m-0 text-xs text-slate-500">{{ t('HINT') }}</p>
    <p v-if="loading" class="m-0 text-sm text-slate-500">{{ t('LOADING') }}</p>
    <p v-else-if="!rows.length" class="m-0 text-sm text-slate-500">
      {{ t('EMPTY') }}
    </p>
    <div
      v-for="row in rows"
      :key="row.id"
      class="flex flex-wrap items-start justify-between gap-3 p-3 border rounded-lg border-slate-100 dark:border-slate-700"
    >
      <div class="flex flex-col gap-1 text-sm">
        <span class="font-medium">{{ row.customer.name }}</span>
        <span class="text-xs text-slate-500">
          {{ shortDate(row.created_at) }}
          <template v-if="row.amount">· {{ money(row.amount) }}</template>
        </span>
        <span class="text-xs">{{ row.note }}</span>
        <span class="flex flex-wrap gap-2">
          <a
            v-for="f in row.files"
            :key="f.url"
            :href="f.url"
            target="_blank"
            rel="noopener noreferrer"
            class="text-xs text-woot-600 hover:underline"
          >
            {{ f.name }}
          </a>
          <span v-if="!row.files.length" class="text-xs text-amber-700">
            {{ t('NO_FILE') }}
          </span>
        </span>
      </div>
      <div class="flex flex-wrap gap-2">
        <woot-button
          v-if="row.conversation_id"
          size="tiny"
          variant="clear"
          icon="chat"
          @click="openConversation(row.conversation_id)"
        >
          {{ t('CONVERSATION') }}
        </woot-button>
        <template v-if="row.status === 'pending'">
          <woot-button
            size="tiny"
            icon="checkmark"
            :is-loading="busy === row.id"
            @click="review(row, 'validate')"
          >
            {{ t('VALIDATE') }}
          </woot-button>
          <woot-button
            size="tiny"
            variant="smooth"
            color-scheme="alert"
            :is-loading="busy === row.id"
            @click="review(row, 'reject')"
          >
            {{ t('REJECT') }}
          </woot-button>
        </template>
      </div>
    </div>
  </div>
</template>
