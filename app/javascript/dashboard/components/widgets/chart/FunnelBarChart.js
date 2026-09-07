// proyecto@metricas_casos — barras horizontales CON ejes/grillas visibles (a
// diferencia de HorizontalBarChart.js, pensado para un mini-progreso apilado sin
// ejes). Acá cada barra es una etapa del embudo y el eje X importa (cuenta real).
import { HorizontalBar } from 'vue-chartjs';

const fontFamily =
  'PlusJakarta,-apple-system,system-ui,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif';

const defaultChartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  legend: {
    display: false,
    labels: {
      fontFamily,
    },
  },
  animation: {
    duration: 0,
  },
  scales: {
    xAxes: [
      {
        ticks: {
          fontFamily,
          beginAtZero: true,
          precision: 0,
        },
        gridLines: {
          drawOnChartArea: false,
        },
      },
    ],
    yAxes: [
      {
        ticks: {
          fontFamily,
        },
        gridLines: {
          drawOnChartArea: false,
        },
      },
    ],
  },
};

export default {
  extends: HorizontalBar,
  props: {
    collection: {
      type: Object,
      default: () => ({}),
    },
    chartOptions: {
      type: Object,
      default: () => ({}),
    },
  },
  watch: {
    collection() {
      this.renderChart(this.collection, {
        ...defaultChartOptions,
        ...this.chartOptions,
      });
    },
  },
  mounted() {
    this.renderChart(this.collection, {
      ...defaultChartOptions,
      ...this.chartOptions,
    });
  },
};
