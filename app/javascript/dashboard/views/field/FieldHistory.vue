<!--
  Plan-Trabajo-Campo — «Mis trabajos»: las órdenes que el técnico terminó en la
  semana o el mes, con sus horas y la calificación del cliente. Al tocar una se
  abre la visita (con su reporte de servicio).
-->
<script>
import FieldVisitsAPI from 'dashboard/api/fieldVisits';

const isoDay = date => {
  const d = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return d.toISOString().slice(0, 10);
};

const capitalize = text => text.charAt(0).toUpperCase() + text.slice(1);

// Lunes de la semana de `date`.
const weekStart = date => {
  const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  d.setDate(d.getDate() - ((d.getDay() + 6) % 7));
  return d;
};

export default {
  name: 'FieldHistory',
  data() {
    return {
      period: 'week',
      // 0 = la semana/mes actual, -1 = la anterior…
      offset: 0,
      orders: [],
      totals: {},
      loading: true,
    };
  },
  computed: {
    range() {
      const today = new Date();
      if (this.period === 'month') {
        const from = new Date(
          today.getFullYear(),
          today.getMonth() + this.offset,
          1
        );
        return {
          from,
          to: new Date(from.getFullYear(), from.getMonth() + 1, 0),
        };
      }
      const from = weekStart(today);
      from.setDate(from.getDate() + this.offset * 7);
      const to = new Date(from);
      to.setDate(to.getDate() + 6);
      return { from, to };
    },
    rangeLabel() {
      if (this.offset === 0) {
        return this.$t(
          this.period === 'month'
            ? 'FIELD.HISTORY.THIS_MONTH'
            : 'FIELD.HISTORY.THIS_WEEK'
        );
      }
      if (this.period === 'month') {
        return capitalize(
          this.range.from.toLocaleDateString(undefined, {
            month: 'long',
            year: 'numeric',
          })
        );
      }
      const short = { day: 'numeric', month: 'short' };
      return `${this.range.from.toLocaleDateString(
        undefined,
        short
      )} – ${this.range.to.toLocaleDateString(undefined, short)}`;
    },
    hoursTotal() {
      return this.hours(this.totals.minutes || 0);
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await FieldVisitsAPI.history(
          isoDay(this.range.from),
          isoDay(this.range.to)
        );
        this.orders = data.orders || [];
        this.totals = data.totals || {};
      } catch {
        this.orders = [];
        this.totals = {};
      } finally {
        this.loading = false;
      }
    },
    setPeriod(period) {
      this.period = period;
      this.offset = 0;
      this.fetch();
    },
    shift(step) {
      this.offset += step;
      this.fetch();
    },
    hours(minutes) {
      const h = Math.floor(minutes / 60);
      const m = minutes % 60;
      return m ? `${h} h ${m} min` : `${h} h`;
    },
    day(value) {
      return capitalize(
        new Date(value).toLocaleDateString(undefined, {
          weekday: 'short',
          day: 'numeric',
          month: 'short',
        })
      );
    },
    stars(rating) {
      return '★'.repeat(rating) + '☆'.repeat(5 - rating);
    },
    open(order) {
      this.$router.push({
        name: 'field_visit',
        params: { accountId: this.$route.params.accountId, ticketId: order.id },
        query: { from: 'history' },
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="grid grid-cols-2 p-1 bg-white rounded-lg">
      <button
        v-for="option in ['week', 'month']"
        :key="option"
        type="button"
        class="py-1.5 text-sm font-medium rounded-md focus:outline-none"
        :class="period === option ? 'bg-woot-500 text-white' : 'text-slate-600'"
        @click="setPeriod(option)"
      >
        {{ $t(`FIELD.HISTORY.${option.toUpperCase()}`) }}
      </button>
    </div>
    <div class="flex items-center justify-between">
      <woot-button
        size="small"
        variant="clear"
        icon="chevron-left"
        :title="$t('FIELD.HISTORY.PREV')"
        @click="shift(-1)"
      />
      <span class="text-base font-semibold text-slate-800">{{
        rangeLabel
      }}</span>
      <woot-button
        size="small"
        variant="clear"
        icon="chevron-right"
        :title="$t('FIELD.HISTORY.NEXT')"
        :disabled="offset >= 0"
        @click="shift(1)"
      />
    </div>
    <div class="grid grid-cols-3 gap-2">
      <div class="p-3 text-center bg-white shadow-sm rounded-xl">
        <p class="m-0 text-xl font-semibold text-slate-800">
          {{ totals.orders || 0 }}
        </p>
        <p class="m-0 text-xs text-slate-500">
          {{ $t('FIELD.HISTORY.ORDERS') }}
        </p>
      </div>
      <div class="p-3 text-center bg-white shadow-sm rounded-xl">
        <p class="m-0 text-xl font-semibold text-slate-800">
          {{ hoursTotal }}
        </p>
        <p class="m-0 text-xs text-slate-500">
          {{ $t('FIELD.HISTORY.HOURS') }}
        </p>
      </div>
      <div class="p-3 text-center bg-white shadow-sm rounded-xl">
        <p class="m-0 text-xl font-semibold text-slate-800">
          {{ totals.csat_average ? `${totals.csat_average} ★` : '—' }}
        </p>
        <p class="m-0 text-xs text-slate-500">
          {{ $t('FIELD.HISTORY.RATING') }}
        </p>
      </div>
    </div>
    <p v-if="loading" class="py-8 text-center text-slate-500">
      {{ $t('FIELD.LOADING') }}
    </p>
    <p v-else-if="!orders.length" class="py-8 text-center text-slate-500">
      {{ $t('FIELD.HISTORY.EMPTY') }}
    </p>
    <article
      v-for="order in orders"
      :key="order.id"
      class="p-4 bg-white shadow-sm rounded-xl"
      @click="open(order)"
    >
      <div class="flex items-start justify-between gap-2">
        <div class="min-w-0">
          <p class="m-0 text-sm font-semibold text-woot-600">
            {{ order.done_at && day(order.done_at) }}
          </p>
          <p class="m-0 text-base font-semibold truncate text-slate-800">
            {{ order.contact && order.contact.name }}
          </p>
          <p class="m-0 text-sm truncate text-slate-600">
            {{ order.folio }} · {{ order.title }}
          </p>
        </div>
        <div class="text-right shrink-0">
          <p class="m-0 text-sm font-medium text-slate-700">
            {{
              order.minutes
                ? hours(order.minutes)
                : $t('FIELD.HISTORY.NO_HOURS')
            }}
          </p>
          <p
            class="m-0 text-sm"
            :class="order.csat_rating ? 'text-amber-500' : 'text-slate-400'"
          >
            {{
              order.csat_rating
                ? stars(order.csat_rating)
                : $t('FIELD.HISTORY.NO_RATING')
            }}
          </p>
        </div>
      </div>
    </article>
  </div>
</template>
