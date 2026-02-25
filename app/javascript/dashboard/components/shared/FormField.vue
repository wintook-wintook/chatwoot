<script setup>
import { computed } from 'vue';

const props = defineProps({
  modelValue: {
    type: [String, Number, Boolean],
    default: '',
  },
  type: {
    type: String,
    default: 'text',
  },
  label: {
    type: String,
    required: true,
  },
  placeholder: {
    type: String,
    default: '',
  },
  error: {
    type: String,
    default: '',
  },
  required: {
    type: Boolean,
    default: false,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
  options: {
    type: Array,
    default: () => [],
  },
  // Para campos específicos
  min: {
    type: Number,
    default: undefined,
  },
  max: {
    type: Number,
    default: undefined,
  },
});

const emit = defineEmits(['update:modelValue', 'input', 'change']);

const hasError = computed(() => !!props.error);

const handleInput = (event) => {
  let value = event.target.value;
  
  // Convertir a número si es necesario
  if (props.type === 'number') {
    value = parseInt(value, 10) || 0;
  }
  
  emit('update:modelValue', value);
  emit('input', value);
};

const handleChange = (event) => {
  let value = event.target.checked !== undefined ? event.target.checked : event.target.value;
  
  if (props.type === 'number') {
    value = parseInt(value, 10) || 0;
  }
  
  emit('update:modelValue', value);
  emit('change', value);
};
</script>

<template>
  <div class="w-full mb-4">
    <!-- Input regular -->
    <woot-input
      v-if="type === 'text' || type === 'number'"
      :model-value="modelValue"
      :type="type"
      :class="{ error: hasError }"
      :label="label"
      :placeholder="placeholder"
      :error="error"
      :disabled="disabled"
      :min="min"
      :max="max"
      @input="handleInput"
    />
    
    <!-- Checkbox -->
    <div v-else-if="type === 'checkbox'" class="flex items-center gap-2">
      <input
        :id="label.toLowerCase().replace(/\s+/g, '_')"
        :checked="modelValue"
        type="checkbox"
        :disabled="disabled"
        @change="handleChange"
      />
      <label :for="label.toLowerCase().replace(/\s+/g, '_')">
        {{ label }}
      </label>
    </div>
    
    <!-- Select -->
    <div v-else-if="type === 'select'" class="flex flex-col">
      <label class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
        {{ label }}
        <span v-if="required" class="text-red-500">*</span>
      </label>
      <select
        :value="modelValue"
        :disabled="disabled"
        :class="[
          'border rounded-md px-3 py-2 text-sm bg-white dark:bg-slate-800',
          hasError 
            ? 'border-red-500 dark:border-red-400' 
            : 'border-slate-300 dark:border-slate-600',
          'text-slate-700 dark:text-slate-300'
        ]"
        @change="handleChange"
      >
        <option value="" disabled>{{ placeholder }}</option>
        <option 
          v-for="option in options" 
          :key="option.value || option.id" 
          :value="option.value || option.id"
        >
          {{ option.label || option.name || option.text }}
        </option>
      </select>
      <span v-if="hasError" class="text-red-500 text-xs mt-1">{{ error }}</span>
    </div>
    
    <!-- Textarea -->
    <woot-input
      v-else-if="type === 'textarea'"
      :model-value="modelValue"
      :class="{ error: hasError }"
      :label="label"
      :placeholder="placeholder"
      :error="error"
      :disabled="disabled"
      input-type="textarea"
      @input="handleInput"
    />
  </div>
</template>