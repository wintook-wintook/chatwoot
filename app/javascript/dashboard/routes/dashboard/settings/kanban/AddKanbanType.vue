<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { getRandomColor } from 'dashboard/helper/labelColor';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import kanbanMixin from 'dashboard/mixins/kanbanMixin';

const validations = {
  name: {
    required,
    minLength: minLength(2),
  },
  description: {},
};

export default {
  mixins: [kanbanMixin],
  
  props: {
    prefillName: {
      type: String,
      default: '',
    },
    kanbanType: {
      type: Object,
      default: null,
    },
  },
  
  setup() {
    return { v$: useVuelidate() };
  },
  
  data() {
    return {
      color: '#3b82f6',
      description: '',
      name: '',
      isDefault: false,
      isLoading: false,
    };
  },
  
  validations,
  
  computed: {
    isEditing() {
      return this.kanbanType && this.kanbanType.id;
    },
    
    modalTitle() {
      return this.isEditing ? 'Editar Tipo de Proceso' : 'Crear Tipo de Proceso';
    },
    
    modalDescription() {
      return this.isEditing 
        ? 'Actualiza la información del tipo de proceso'
        : 'Crea un nuevo tipo de proceso para organizar tu kanban';
    },
    
    submitButtonText() {
      return this.isEditing ? 'Actualizar Tipo de Proceso' : 'Crear Tipo de Proceso';
    },
  },
  
  mounted() {
    this.initializeForm();
  },
  
  watch: {
    kanbanType: {
      handler() {
        this.initializeForm();
      },
      immediate: true,
    },
  },
  
  methods: {
    initializeForm() {
      if (this.isEditing && this.kanbanType) {
        this.name = this.kanbanType.process_name || '';
        this.description = this.kanbanType.description || '';
        this.color = this.kanbanType.color || '#3b82f6';
        this.isDefault = this.kanbanType.default || false;
      } else {
        this.name = this.prefillName || '';
        this.description = '';
        this.color = getRandomColor();
        this.isDefault = false;
      }
    },

    async saveKanbanType() {
      if (this.isLoading) return;
      
      console.log('🔄 Guardando tipo de proceso...');
      
      this.isLoading = true;
      
      try {
        const payload = {
          process_name: this.name,
          description: this.description,
          color: this.color,
          default: this.isDefault,
        };

        if (this.isEditing) {
          console.log('📝 Actualizando tipo existente...');
          await this.updateKanbanTypeProcess({
            id: this.kanbanType.id,
            ...payload,
          });
          this.showSuccessMessage('Tipo de proceso actualizado exitosamente');
        } else {
          console.log('➕ Creando nuevo tipo...');
          await this.createKanbanTypeProcess(payload);
          this.showSuccessMessage('Tipo de proceso creado exitosamente');
          this.$emit('close'); // Emitir que se cerró
        }

        console.log('✅ Guardado exitoso, cerrando modal...');
        this.closeModal();
        
      } catch (error) {
        console.error('❌ Error guardando:', error);
        this.showErrorMessage('Error: ' + (error.message || 'No se pudo guardar'));
      } finally {
        this.isLoading = false;
      }
    },

    closeModal() {
      console.log('🔄 Cerrando modal...');
      this.$emit('saved'); // Emitir que se guardó
      this.$emit('close'); // Emitir que se cerró
    },

    cancelModal() {
      console.log('❌ Cancelando modal...');
      this.$emit('close');
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="modalTitle"
      :header-content="modalDescription"
    />
    <form class="flex flex-wrap mx-0" @submit.prevent="saveKanbanType">
      <woot-input
        v-model.trim="name"
        :class="{ error: v$.name.$error }"
        class="w-full kanban-type-name--input"
        label="Nombre del Tipo de Proceso"
        placeholder="Ej: Ventas, Soporte, Desarrollo"
        :error="v$.name.$error ? (v$.name.required ? 'El nombre es requerido' : 'Mínimo 2 caracteres') : ''"
        data-testid="kanban-type-name"
        @input="v$.name.$touch"
      />
      <woot-input
        v-model.trim="description"
        :class="{ error: v$.description.$error }"
        class="w-full"
        label="Descripción"
        placeholder="Describe el propósito de este tipo de proceso"
        data-testid="kanban-type-description"
        @input="v$.description.$touch"
      />
      <div class="w-full">
        <label>
          Color
          <woot-color-picker v-model="color" />
        </label>
      </div>
      <div class="flex items-center w-full gap-2">
        <input 
          v-model="isDefault" 
          type="checkbox" 
          :value="true" 
          :id="`default_kanban_type_${isEditing ? kanbanType.id : 'new'}`"
        />
        <label :for="`default_kanban_type_${isEditing ? kanbanType.id : 'new'}`">
          Establecer como tipo de proceso por defecto
        </label>
      </div>
      <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
        <woot-button
          :is-disabled="v$.name.$invalid || isLoading"
          :is-loading="isLoading"
          data-testid="kanban-type-submit"
          type="submit"
        >
          {{ submitButtonText }}
        </woot-button>
        <woot-button 
          class="button clear" 
          @click.prevent="cancelModal"
          :disabled="isLoading"
        >
          Cancelar
        </woot-button>
      </div>
    </form>
  </div>
</template>

<style lang="scss" scoped>
.kanban-type-name--input {
  ::v-deep {
    input {
      @apply capitalize;
    }
  }
}
</style>