<script>
// ================================================================================
// proyecto@ai_agent_assistant - F2
// ================================================================================
// Componente: LintBadges
// Descripción: Semáforo del linter. Muestra el recuento por nivel y el detalle de
//              cada hallazgo, con el texto ya traducido desde los `params` que
//              devuelve el backend.
//
// Los ⛔ bloquean el guardado (decisión del usuario): por eso van primero, con el
// mensaje explicando qué va a pasar, no solo qué está mal.
// ================================================================================

export default {
  props: {
    findings: {
      type: Array,
      default: () => [],
    },
    isLoading: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    errors() {
      return this.findings.filter(f => f.level === 'error');
    },
    warnings() {
      return this.findings.filter(f => f.level === 'warning');
    },
    infos() {
      return this.findings.filter(f => f.level === 'info');
    },
    // Los errores primero: son los que impiden guardar.
    ordered() {
      return [...this.errors, ...this.warnings, ...this.infos];
    },
  },
  methods: {
    // El backend manda `params` con listas y cifras; se aplanan para que la
    // traducción los interpole sin que el .json tenga que saber de arrays.
    message(finding) {
      const params = Object.entries(finding.params || {}).reduce(
        (acc, [key, value]) => ({
          ...acc,
          [key]: Array.isArray(value) ? value.join(', ') : value,
        }),
        {}
      );
      return this.$t(`AI_AGENT_ASSISTANT.LINT.${finding.rule}`, params);
    },
    levelClasses(level) {
      if (level === 'error') {
        return 'bg-red-50 border-red-200 dark:bg-red-800/20 dark:border-red-800';
      }
      if (level === 'warning') {
        return 'bg-amber-50 border-amber-200 dark:bg-amber-800/20 dark:border-amber-800';
      }
      return 'bg-slate-50 border-slate-200 dark:bg-slate-800 dark:border-slate-700';
    },
    levelTextClasses(level) {
      if (level === 'error') return 'text-red-700 dark:text-red-300';
      if (level === 'warning') return 'text-amber-700 dark:text-amber-300';
      return 'text-slate-600 dark:text-slate-300';
    },
    levelIcon(level) {
      if (level === 'error') return 'dismiss-circle';
      if (level === 'warning') return 'warning';
      return 'info';
    },
  },
};
</script>

<template>
  <div>
    <!-- Recuento -->
    <div class="flex items-center gap-3 text-xs">
      <span v-if="isLoading" class="text-slate-400 dark:text-slate-500">
        {{ $t('AI_AGENT_ASSISTANT.LINT_CHECKING') }}
      </span>
      <template v-else>
        <span
          class="font-semibold"
          :class="
            errors.length
              ? 'text-red-600 dark:text-red-400'
              : 'text-slate-400 dark:text-slate-500'
          "
        >
          {{ $t('AI_AGENT_ASSISTANT.LINT_ERRORS', { count: errors.length }) }}
        </span>
        <span
          class="font-semibold"
          :class="
            warnings.length
              ? 'text-amber-600 dark:text-amber-400'
              : 'text-slate-400 dark:text-slate-500'
          "
        >
          {{
            $t('AI_AGENT_ASSISTANT.LINT_WARNINGS', { count: warnings.length })
          }}
        </span>
        <span class="text-slate-400 dark:text-slate-500">
          {{ $t('AI_AGENT_ASSISTANT.LINT_INFOS', { count: infos.length }) }}
        </span>
        <span
          v-if="!findings.length"
          class="text-green-600 dark:text-green-400"
        >
          {{ $t('AI_AGENT_ASSISTANT.LINT_CLEAN') }}
        </span>
      </template>
    </div>

    <!-- Detalle -->
    <ul v-if="ordered.length" class="mt-2 space-y-1.5 list-none">
      <li
        v-for="finding in ordered"
        :key="finding.rule"
        class="flex items-start gap-2 px-3 py-2 border rounded-md"
        :class="levelClasses(finding.level)"
      >
        <fluent-icon
          :icon="levelIcon(finding.level)"
          size="14"
          class="mt-0.5 shrink-0"
          :class="levelTextClasses(finding.level)"
        />
        <p
          class="m-0 text-xs leading-snug"
          :class="levelTextClasses(finding.level)"
        >
          {{ message(finding) }}
        </p>
      </li>
    </ul>
  </div>
</template>
