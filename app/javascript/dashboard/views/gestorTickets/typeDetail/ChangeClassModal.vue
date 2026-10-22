<!--
  @tickets_cases — «Cambiar de clase» un tipo de caso.
  Sin casos: cambia directo (sus etapas pasan a las de la clase nueva). Con casos:
  crea el tipo en la otra clase con el mismo nombre, prefijo y campos, y retira el
  de antes como «(anterior)» — sus casos se quedan en su clase con todo igual y los
  nuevos nacen en la nueva. Las automatizaciones «Asignar Caso» pasan al nuevo.
-->
<script>
import { mapGetters } from 'vuex';
import CaseTypesAPI from 'dashboard/api/caseTypes';
import { enabledCaseClasses } from 'dashboard/helper/caseClasses';

const T = 'CASE_TICKETS.TYPES.CHANGE_CLASS';

export default {
  name: 'ChangeClassModal',
  props: {
    show: { type: Boolean, default: false },
    type: { type: Object, required: true },
  },
  emits: ['close', 'changed'],
  data() {
    return { target: '', isSaving: false };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
    }),
    current() {
      return this.type.case_class || 'support';
    },
    options() {
      return enabledCaseClasses(flag =>
        this.isFeatureEnabledonAccount(this.accountId, flag)
      ).filter(c => c.key !== this.current);
    },
    count() {
      return this.type.cases_count || 0;
    },
    params() {
      const entry = this.options.find(c => c.key === this.target);
      return {
        name: this.type.name,
        count: this.count,
        from: this.className(this.current),
        to: entry ? this.$t(`${entry.i18n}.NAME`) : '',
      };
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    className(key) {
      const map = {
        support: 'SUPPORT',
        commercial: 'COMMERCIAL',
        work_order: 'WORK_ORDER',
        project: 'PROJECT',
      };
      return this.$t(`CASE_TICKETS.CLASSES.${map[key]}.NAME`);
    },
    async confirm() {
      if (!this.target) return;
      this.isSaving = true;
      try {
        const { data } = await CaseTypesAPI.changeClass(
          this.type.id,
          this.target
        );
        const moved = (data.automations || []).length;
        const rules = (data.rules || []).length;
        this.$emitter.emit('newToastMessage', {
          message: data.retired
            ? this.t('DONE_REPLACED', { ...this.params, moved, rules })
            : this.t('DONE_DIRECT', this.params),
        });
        this.$emit('changed', data);
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            (e.response && e.response.data && e.response.data.error) ||
            this.t('ERROR'),
        });
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="small">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="t('TITLE', { name: type.name })"
        :header-content="t('CURRENT', { from: className(current) })"
      />
      <div class="flex flex-col gap-4 px-8 pb-8">
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ t('TARGET') }}
          </span>
          <select v-model="target" class="!mb-0">
            <option value="">{{ t('CHOOSE') }}</option>
            <option v-for="c in options" :key="c.key" :value="c.key">
              {{ $t(`${c.i18n}.NAME`) }}
            </option>
          </select>
        </label>

        <div
          v-if="target"
          class="flex flex-col gap-2 p-3 text-sm rounded-lg bg-slate-50 text-slate-700 dark:bg-slate-800 dark:text-slate-200"
        >
          <template v-if="count">
            <p class="m-0">{{ t('WITH_CASES_KEEP', params) }}</p>
            <p class="m-0">{{ t('WITH_CASES_NEW', params) }}</p>
            <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
              {{ t('WITH_CASES_MOVE') }}
            </p>
          </template>
          <p v-else class="m-0">{{ t('NO_CASES', params) }}</p>
        </div>

        <div class="flex justify-end gap-2">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            @click="$emit('close')"
          >
            {{ t('CANCEL') }}
          </woot-button>
          <woot-button
            :disabled="!target"
            :is-loading="isSaving"
            @click="confirm"
          >
            {{ t('CONFIRM') }}
          </woot-button>
        </div>
      </div>
    </div>
  </woot-modal>
</template>
