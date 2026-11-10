<!--
  Tarea agendada → tarea sin hora (Cases::Conversion#to_task). Se quita de la agenda y de
  Google; si era la sesión de una tarea, queda esa tarea. Con cliente: avisarle.
  Emite `submit` con { notify_client } y `close`.
-->
<script>
const T = 'CONVERT_ITEM';

export default {
  name: 'ConvertToTaskModal',
  props: {
    show: { type: Boolean, default: false },
    // { title, case_task: { title }, has_client }
    item: { type: Object, default: null },
    busy: { type: Boolean, default: false },
    error: { type: String, default: '' },
  },
  emits: ['submit', 'close'],
  data() {
    return { notifyClient: true };
  },
  watch: {
    show(open) {
      if (open) this.notifyClient = true;
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    submit() {
      this.$emit('submit', {
        notify_client: !!this.item?.has_client && this.notifyClient,
      });
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="small">
    <div v-if="item" class="flex flex-col gap-3 p-6">
      <h3 class="m-0 text-lg font-semibold text-slate-800 dark:text-slate-100">
        {{ t('TO_TASK_TITLE', { title: item.title }) }}
      </h3>
      <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
        {{
          item.case_task
            ? t('TO_TASK_LINKED', { task: item.case_task.title })
            : t('TO_TASK_DESC')
        }}
      </p>
      <label v-if="item.has_client" class="flex items-center gap-2 text-sm">
        <input v-model="notifyClient" type="checkbox" class="!m-0" />
        {{ t('NOTIFY') }}
      </label>
      <p v-if="error" class="m-0 text-xs text-red-600">{{ error }}</p>
      <div class="flex justify-end gap-2">
        <woot-button variant="clear" @click="$emit('close')">
          {{ t('CANCEL') }}
        </woot-button>
        <woot-button :is-loading="busy" @click="submit">
          {{ t('CONFIRM') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
