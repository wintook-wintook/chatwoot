<script setup>
import { computed } from 'vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  isDisabled: {
    type: Boolean,
    default: false,
  },
  submitText: {
    type: String,
    default: 'Guardar',
  },
  cancelText: {
    type: String,
    default: 'Cancelar',
  },
  submitColor: {
    type: String,
    default: 'primary',
  },
});

const emit = defineEmits(['close', 'submit']);

const handleClose = () => {
  emit('close');
};

const handleSubmit = () => {
  emit('submit');
};
</script>

<template>
  <woot-modal :show="show" :on-close="handleClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header 
        :header-title="title"
        :header-content="description"
      />
      
      <form class="flex flex-wrap mx-0" @submit.prevent="handleSubmit">
        <!-- Slot para el contenido del formulario -->
        <slot name="form-content"></slot>
        
        <!-- Botones de acción -->
        <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
          <woot-button
            :is-disabled="isDisabled"
            :is-loading="isLoading"
            :color-scheme="submitColor"
            type="submit"
          >
            {{ submitText }}
          </woot-button>
          
          <woot-button 
            class="button clear" 
            @click.prevent="handleClose"
          >
            {{ cancelText }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>