// @tickets_cases — Plan-Metricas-Comercial: período de calendario compartido por
// las Métricas de todas las clases (Soporte, Comercial, Órdenes, Proyectos), con
// CalendarPeriodPicker. Quien lo usa define `fetch()` y guarda `periodState()`
// junto a sus filtros; al montar llama `restorePeriod(saved)`.
import {
  CALENDAR_PERIODS,
  DEFAULT_CALENDAR_PERIOD,
  dayString,
  periodRange,
} from 'dashboard/helper/caseMetricsPeriod';

export default {
  data() {
    return {
      period: DEFAULT_CALENDAR_PERIOD,
      customFrom: '',
      customTo: '',
    };
  },
  methods: {
    // { from, to (exclusivo), prevFrom, prevTo } del período elegido.
    periodRangeOf(state = this) {
      return periodRange(state.period, {
        from: state.customFrom,
        to: state.customTo,
      });
    },
    periodState() {
      return {
        period: this.period,
        customFrom: this.customFrom,
        customTo: this.customTo,
      };
    },
    // Los períodos viejos (7/30/90 días, Todo) y un personalizado roto caen en
    // «Este mes».
    restorePeriod(saved = {}) {
      this.customFrom = saved.customFrom || '';
      this.customTo = saved.customTo || '';
      this.period = CALENDAR_PERIODS.includes(saved.period)
        ? saved.period
        : DEFAULT_CALENDAR_PERIOD;
      if (this.period === 'custom' && !this.periodRangeOf()) {
        this.period = DEFAULT_CALENDAR_PERIOD;
      }
    },
    setPeriod(key) {
      this.period = key;
      // «Personalizado» arranca con este mes a la fecha; se ajusta con las fechas.
      if (key === 'custom' && !this.periodRangeOf()) {
        const now = new Date();
        this.customFrom = dayString(
          new Date(now.getFullYear(), now.getMonth(), 1)
        );
        this.customTo = dayString(now);
      }
      this.fetch();
    },
    setCustom({ from, to }) {
      this.customFrom = from;
      this.customTo = to;
      this.fetch();
    },
  },
};
