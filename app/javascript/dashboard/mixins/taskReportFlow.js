// Reporte de cierre — antes de concluir, se pide el reporte; al mandarlo, sigue lo que
// quedó en espera. Va con <TaskReportModal :item="reportItem" @close @reported>.
export default {
  data() {
    return { reportItem: null, afterReport: null };
  },
  methods: {
    askReport(item, then) {
      this.reportItem = item;
      this.afterReport = then;
    },
    cancelReport() {
      this.reportItem = null;
      this.afterReport = null;
    },
    onReported() {
      const then = this.afterReport;
      this.cancelReport();
      if (then) then();
    },
  },
};
