<!-- Cobranza › Promesas de pago: las que registró el agente, vigentes, cumplidas e incumplidas. -->
<script>
import CollectionsAPI from 'dashboard/api/collections';
import { money, shortDate } from './money';

export default {
  name: 'PromisesPanel',
  data() {
    return { status: 'pending', rows: [], loading: false };
  },
  mounted() {
    this.load();
  },
  methods: {
    money,
    shortDate,
    t(key, params) {
      return this.$t(`COLLECTIONS.PROMISES.${key}`, params);
    },
    async load() {
      this.loading = true;
      try {
        const { data } = await CollectionsAPI.promises({ status: this.status });
        this.rows = data;
      } finally {
        this.loading = false;
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
        v-for="s in ['pending', 'kept', 'broken']"
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
    <p v-if="loading" class="m-0 text-sm text-slate-500">{{ t('LOADING') }}</p>
    <p v-else-if="!rows.length" class="m-0 text-sm text-slate-500">
      {{ t('EMPTY') }}
    </p>
    <table v-else class="w-full text-sm">
      <thead>
        <tr class="text-xs text-left text-slate-500">
          <th class="py-1 pr-2">{{ t('COLS.CUSTOMER') }}</th>
          <th class="py-1 pr-2">{{ t('COLS.DATE') }}</th>
          <th class="py-1 pr-2">{{ t('COLS.AMOUNT') }}</th>
          <th class="py-1 pr-2">{{ t('COLS.NOTE') }}</th>
          <th class="py-1" />
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="row in rows"
          :key="row.id"
          class="border-t border-slate-100 dark:border-slate-700"
        >
          <td class="py-2 pr-2 font-medium">{{ row.customer.name }}</td>
          <td class="py-2 pr-2">{{ shortDate(row.promised_on) }}</td>
          <td class="py-2 pr-2">{{ row.amount ? money(row.amount) : '—' }}</td>
          <td class="py-2 pr-2 text-xs">{{ row.note }}</td>
          <td class="py-2 text-right">
            <woot-button
              v-if="row.conversation_id"
              size="tiny"
              variant="clear"
              icon="chat"
              @click="openConversation(row.conversation_id)"
            />
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
