<script>
// @tickets_cases — Toast propio del módulo de tickets (asignación/completado de
// ticket y tarea). Aislado del Snackbar global (que es centrado y oscuro) para
// poder mostrarlo a la DERECHA y en color success sin afectar al resto del producto.
// Se alimenta del evento 'caseToastMessage' emitido desde actionCable.js.
export default {
  name: 'CaseToastNotification',
  data() {
    return {
      toasts: [],
      duration: 4000,
    };
  },
  mounted() {
    this.$emitter.on('caseToastMessage', this.onToast);
  },
  beforeDestroy() {
    this.$emitter.off('caseToastMessage', this.onToast);
  },
  methods: {
    onToast({ message, icon }) {
      const key = `${Date.now()}-${Math.random()}`;
      this.toasts.push({ key, message, icon: icon || 'checkmark-circle' });
      window.setTimeout(() => this.dismiss(key), this.duration);
    },
    dismiss(key) {
      this.toasts = this.toasts.filter(t => t.key !== key);
    },
  },
};
</script>

<template>
  <transition-group
    name="case-toast-fade"
    tag="div"
    class="fixed z-[9999] flex flex-col items-end gap-2 top-4 right-4"
  >
    <div
      v-for="toast in toasts"
      :key="toast.key"
      class="flex items-center gap-2 px-4 py-3 text-sm font-medium text-white rounded-lg shadow-lg max-w-[24rem] bg-green-600 dark:bg-green-700"
    >
      <fluent-icon :icon="toast.icon" size="18" class="flex-shrink-0" />
      <span class="flex-1">{{ toast.message }}</span>
      <button
        type="button"
        class="flex-shrink-0 opacity-80 hover:opacity-100"
        @click="dismiss(toast.key)"
      >
        <fluent-icon icon="dismiss" size="14" />
      </button>
    </div>
  </transition-group>
</template>

<style scoped>
.case-toast-fade-enter-active,
.case-toast-fade-leave-active {
  transition: all 0.25s ease;
}
.case-toast-fade-enter,
.case-toast-fade-leave-to {
  opacity: 0;
  transform: translateX(1rem);
}
</style>
