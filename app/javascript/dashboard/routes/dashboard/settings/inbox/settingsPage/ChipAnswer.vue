<template>
    <div class="flex flex-wrap gap-2">
      <div v-for="(answer, index) in dataRow.answers" :key="answer.answer_id"
        class="flex items-center bg-gray-100 border border-gray-300 rounded-full px-3 py-1 m-1 text-sm">
        <!-- Botón para editar -->
        <a class="text-blue-500 hover:text-blue-700 cursor-pointer" @click="onEdit(answer)">
          {{ answer.answer }}
        </a>
        <!-- Botón para eliminar -->
        <button class="ml-2 text-gray-400 hover:text-red-500 focus:outline-none" @click="onRemove(index)">
          ×
        </button>
      </div>
    </div>
  </template>
  
  <script>
  export default {
    props: {
      dataRow: {
        type: Object, // Cambiado a Object porque esperas un objeto
        default: () => ({}), // Proveer un objeto vacío por defecto
      },
    },
    methods: {
      onEdit(answer) {
        // Emitir evento con el dato a editar
        this.$emit('edit', answer);
      },
      onRemove(index) {
        // Emitir evento con el índice para eliminar
        this.$emit('remove', index);
      },
    },
    mounted() {
      console.log('Componente ChipAnswer montado. dataAnswers:', this.dataRow);
    },
  };
  </script>
  
  <style scoped>
  /* Estilos adicionales opcionales */
  </style>