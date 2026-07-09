import { Doughnut } from 'vue-chartjs';

const fontFamily =
  'PlusJakarta,-apple-system,system-ui,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif';

const defaultChartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  cutoutPercentage: 62,
  legend: {
    display: true,
    position: 'right',
    labels: {
      fontFamily,
      boxWidth: 12,
      padding: 12,
      usePointStyle: true,
    },
  },
  animation: {
    duration: 400,
  },
  tooltips: {
    bodyFontFamily: fontFamily,
    titleFontFamily: fontFamily,
  },
};

export default {
  extends: Doughnut,
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
