<!-- DEV0002 -->
<script>
export default {
  name: 'MessageContactModal',
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    message: {
      type: String,
      default: 'El email ya existe en el sistema',
    },
    title: {
      type: String,
      default: 'Email ya existe',
    },
    acceptButtonText: {
      type: String,
      default: 'Aceptar',
    },
    showCancelButton: {
      type: Boolean,
      default: false,
    },
    cancelButtonText: {
      type: String,
      default: 'Cancelar',
    },
  },
  emits: ['close', 'cancel', 'accept'],
  methods: {
    onClose() {
      this.$emit('close');
    },
    onCancel() {
      this.$emit('cancel');
    },
    onAccept() {
      this.$emit('accept');
    },
    onBackdropClick() {
      this.onClose();
    },
    handleKeydown(event) {
      if (event.key === 'Escape' && this.show) {
        this.onClose();
      }
    },
  },
  mounted() {
    document.addEventListener('keydown', this.handleKeydown);
    if (this.show) {
      document.body.style.overflow = 'hidden';
    }
  },
  beforeUnmount() {
    document.removeEventListener('keydown', this.handleKeydown);
    document.body.style.overflow = '';
  },
  watch: {
    show(newVal) {
      if (newVal) {
        document.body.style.overflow = 'hidden';
      } else {
        document.body.style.overflow = '';
      }
    },
  },
};
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition-all duration-200 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-all duration-150 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="show"
        class="modal-overlay fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center p-4"
        @click="onBackdropClick"
        role="dialog"
        aria-modal="true"
        :aria-labelledby="`modal-title-${$attrs.id || 'default'}`"
      >
        <Transition
          enter-active-class="transition-all duration-200 ease-out"
          enter-from-class="opacity-0 transform scale-95"
          enter-to-class="opacity-100 transform scale-100"
          leave-active-class="transition-all duration-150 ease-in"
          leave-from-class="opacity-100 transform scale-100"
          leave-to-class="opacity-0 transform scale-95"
        >
          <div
            v-if="show"
            class="bg-white rounded-lg shadow-lg w-full max-w-sm relative"
            @click.stop
          >
            <!-- Close button -->
            <button
              @click="onClose"
              class="absolute top-3 right-3 text-gray-400 hover:text-gray-600 transition-colors duration-150"
              aria-label="Cerrar modal"
              type="button"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>

            <!-- Content -->
            <div class="p-6">
              <!-- Title -->
              <h3 
                :id="`modal-title-${$attrs.id || 'default'}`"
                class="text-lg font-semibold text-gray-900 mb-2 pr-6"
              >
                {{ title }}
              </h3>
              
              <!-- Message -->
              <p class="text-sm text-gray-600 leading-5 mb-6">
                {{ message }}
              </p>
              
              <!-- Buttons -->
              <div class="flex items-center justify-end gap-2">
                <button
                  v-if="showCancelButton"
                  @click="onCancel"
                  class="px-3 py-1.5 text-sm font-medium text-blue-600 bg-transparent rounded hover:bg-blue-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-1 transition-colors duration-150"
                  type="button"
                >
                  {{ cancelButtonText }}
                </button>
                <button
                  @click="onAccept"
                  class="px-3 py-1.5 text-sm font-medium text-white bg-blue-500 rounded hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-1 transition-colors duration-150"
                  type="button"
                >
                  {{ acceptButtonText }}
                </button>
              </div>
            </div>
          </div>
        </Transition>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
/* Z-index personalizado para máximo control */
.modal-overlay {
  z-index: 99999 !important;
}
</style>