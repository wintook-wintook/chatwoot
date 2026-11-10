<script>
// feat/plantillas_whatsapp_mejoras F10.3 — LOS BOTONES DE LA PLANTILLA
// ============================================================================
// Plan: docs/plantillas_whatsapp_mejoras_plan.md §7.12. Antes: «Agregar» siempre ponía una
// respuesta rápida, había que cambiarle el tipo, los campos no tenían etiqueta y las reglas
// de Meta (topes por tipo, respuestas rápidas primero) se descubrían por error.
//
// Ahora: un «+» por tipo que se apaga al llegar al tope de Meta (dice por qué), dos grupos
// fijos (Respuestas rápidas · Acciones: el orden que pide Meta sale solo), una tarjeta con
// etiquetas por botón, arrastrar ⋮⋮ dentro de cada grupo y la liga «fija» o «termina con
// un dato del cliente» (el {{1}} lo pone el editor). Lógica pura en templateEditor.js.
// ============================================================================
import draggable from 'vuedraggable';
import { COPY_CODE_MAX } from 'dashboard/helper/whatsappTemplateValidator';
import {
  BUTTON_LIMITS,
  BUTTON_TYPES,
  MAX_BUTTONS,
  MAX_BUTTON_TEXT,
  addButtonBlocker,
  buildUrl,
  buttonExample,
  isDynamicUrl,
  isQuickReply,
  newButton,
  phoneNeedsCountryCode,
  urlBase,
} from './templateEditor';

const ICONS = {
  QUICK_REPLY: 'arrow-reply',
  URL: 'open',
  PHONE_NUMBER: 'call',
  COPY_CODE: 'copy',
};

export default {
  components: { Draggable: draggable },
  props: {
    value: {
      type: Array,
      required: true,
    },
  },
  emits: ['input'],
  data() {
    return {
      buttonTypes: BUTTON_TYPES,
      maxText: MAX_BUTTON_TEXT,
      copyCodeMax: COPY_CODE_MAX,
      keys: new WeakMap(),
      nextKey: 1,
    };
  },
  computed: {
    quickReplies: {
      get() {
        return this.value.filter(isQuickReply);
      },
      set(lista) {
        this.$emit('input', [...lista, ...this.actions]);
      },
    },
    actions: {
      get() {
        return this.value.filter(b => !isQuickReply(b));
      },
      set(lista) {
        this.$emit('input', [...this.quickReplies, ...lista]);
      },
    },
    quickCount() {
      return `${this.quickReplies.length} / ${MAX_BUTTONS}`;
    },
    totalCount() {
      return `${this.value.length} / ${MAX_BUTTONS}`;
    },
  },
  methods: {
    // Llave estable por botón (para arrastrar) sin meter campos de más en lo que se guarda.
    keyOf(boton) {
      if (!this.keys.has(boton)) {
        this.keys.set(boton, this.nextKey);
        this.nextKey += 1;
      }
      return this.keys.get(boton);
    },
    icon(tipo) {
      return ICONS[tipo];
    },
    blocker(tipo) {
      return addButtonBlocker(this.value, tipo);
    },
    blockerText(tipo) {
      const motivo = this.blocker(tipo);
      if (!motivo) return '';
      return motivo === 'TOTAL'
        ? this.$t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.LIMIT_TOTAL', {
            max: MAX_BUTTONS,
          })
        : this.$t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.LIMIT_TYPE', {
            max: BUTTON_LIMITS[tipo],
            type: this.typeLabel(tipo),
          });
    },
    typeLabel(tipo) {
      return this.$t(`WHATSAPP_TEMPLATE_EDITOR.BUTTONS.TYPES.${tipo}`);
    },
    add(tipo) {
      if (this.blocker(tipo)) return;
      const boton = newButton(tipo);
      this.$emit(
        'input',
        isQuickReply(boton)
          ? [...this.quickReplies, boton, ...this.actions]
          : [...this.quickReplies, ...this.actions, boton]
      );
    },
    remove(boton) {
      this.$emit(
        'input',
        this.value.filter(b => b !== boton)
      );
    },
    update(boton, cambios) {
      this.$emit(
        'input',
        this.value.map(b => (b === boton ? Object.assign(b, cambios) : b))
      );
    },
    textCount(boton) {
      return `${(boton.text || '').length} / ${MAX_BUTTON_TEXT}`;
    },
    isDynamicUrl,
    urlBase,
    setUrlBase(boton, base) {
      this.update(boton, { url: buildUrl(base, isDynamicUrl(boton)) });
    },
    setUrlMode(boton, dynamic) {
      this.update(boton, {
        url: buildUrl(urlBase(boton), dynamic),
        example: dynamic ? boton.example || [] : [],
      });
    },
    buttonExample,
    setExample(boton, valor) {
      this.update(boton, { example: [valor] });
    },
    phoneNeedsCountryCode,
  },
};
</script>

<template>
  <div>
    <div class="flex flex-wrap items-center gap-2">
      <span
        v-for="tipo in buttonTypes"
        :key="tipo"
        :title="blockerText(tipo)"
        class="inline-block"
      >
        <woot-button
          variant="smooth"
          size="small"
          :icon="icon(tipo)"
          :is-disabled="Boolean(blocker(tipo))"
          @click="add(tipo)"
        >
          {{ typeLabel(tipo) }}
        </woot-button>
      </span>
      <span class="ml-auto text-xs text-slate-400">{{ totalCount }}</span>
    </div>

    <p
      v-if="!value.length"
      class="py-8 mb-0 text-sm text-center text-slate-400"
    >
      {{ $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.EMPTY') }}
    </p>

    <div v-else class="grid grid-cols-1 gap-4 mt-4 xl:grid-cols-2">
      <!-- Respuestas rápidas: siempre primero (regla de Meta) -->
      <div v-if="quickReplies.length">
        <p class="mb-2 text-xs font-medium text-slate-500 dark:text-slate-300">
          {{ $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.GROUP_QUICK') }}
          <span class="font-normal text-slate-400">· {{ quickCount }}</span>
        </p>
        <Draggable
          v-model="quickReplies"
          handle=".drag-handle"
          :animation="150"
        >
          <div
            v-for="boton in quickReplies"
            :key="keyOf(boton)"
            class="button-card"
          >
            <fluent-icon icon="drag" size="16" class="drag-handle" />
            <fluent-icon :icon="icon(boton.type)" size="14" class="mt-2.5" />
            <div class="flex-1 min-w-0">
              <woot-input
                :value="boton.text"
                :label="$t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.TEXT')"
                :placeholder="
                  $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.TEXT_PLACEHOLDER_QUICK')
                "
                :help-text="textCount(boton)"
                class="!mb-0"
                @input="update(boton, { text: $event })"
              />
            </div>
            <woot-button
              variant="clear"
              size="small"
              color-scheme="alert"
              icon="delete"
              :title="$t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.REMOVE')"
              @click="remove(boton)"
            />
          </div>
        </Draggable>
      </div>

      <!-- Acciones: liga, teléfono, copiar código -->
      <div v-if="actions.length">
        <p class="mb-2 text-xs font-medium text-slate-500 dark:text-slate-300">
          {{ $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.GROUP_ACTIONS') }}
        </p>
        <Draggable v-model="actions" handle=".drag-handle" :animation="150">
          <div v-for="boton in actions" :key="keyOf(boton)" class="button-card">
            <fluent-icon icon="drag" size="16" class="drag-handle" />
            <fluent-icon :icon="icon(boton.type)" size="14" class="mt-2.5" />
            <div class="flex flex-col flex-1 min-w-0 gap-2">
              <span
                class="text-xs font-medium text-slate-600 dark:text-slate-300"
              >
                {{ typeLabel(boton.type) }}
              </span>

              <woot-input
                v-if="boton.type !== 'COPY_CODE'"
                :value="boton.text"
                :label="$t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.TEXT')"
                :placeholder="
                  $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.TEXT_PLACEHOLDER')
                "
                :help-text="textCount(boton)"
                class="!mb-0"
                @input="update(boton, { text: $event })"
              />

              <template v-if="boton.type === 'URL'">
                <woot-input
                  :value="urlBase(boton)"
                  :label="$t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.URL')"
                  placeholder="https://"
                  class="!mb-0"
                  @input="setUrlBase(boton, $event)"
                />
                <div class="flex flex-wrap gap-x-4 gap-y-1 text-sm">
                  <label class="inline-flex items-center gap-1 !mb-0">
                    <input
                      type="radio"
                      class="!mb-0"
                      :checked="!isDynamicUrl(boton)"
                      @change="setUrlMode(boton, false)"
                    />
                    {{ $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.URL_FIXED') }}
                  </label>
                  <label class="inline-flex items-center gap-1 !mb-0">
                    <input
                      type="radio"
                      class="!mb-0"
                      :checked="isDynamicUrl(boton)"
                      @change="setUrlMode(boton, true)"
                    />
                    {{ $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.URL_DYNAMIC') }}
                  </label>
                </div>
                <woot-input
                  v-if="isDynamicUrl(boton)"
                  :value="buttonExample(boton)"
                  :label="$t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.URL_EXAMPLE')"
                  :placeholder="
                    $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.EXAMPLE_URL')
                  "
                  :help-text="
                    $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.URL_DYNAMIC_HINT')
                  "
                  class="!mb-0"
                  @input="setExample(boton, $event)"
                />
              </template>

              <woot-input
                v-if="boton.type === 'PHONE_NUMBER'"
                :value="boton.phone_number"
                :label="$t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.PHONE')"
                :placeholder="
                  $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.PHONE_PLACEHOLDER')
                "
                :error="
                  phoneNeedsCountryCode(boton.phone_number)
                    ? $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.PHONE_HINT')
                    : ''
                "
                class="!mb-0"
                @input="update(boton, { phone_number: $event })"
              />

              <woot-input
                v-if="boton.type === 'COPY_CODE'"
                :value="buttonExample(boton)"
                :label="
                  $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.EXAMPLE_CODE', {
                    max: copyCodeMax,
                  })
                "
                :help-text="$t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.CODE_HINT')"
                class="!mb-0"
                @input="setExample(boton, $event)"
              />
            </div>
            <woot-button
              variant="clear"
              size="small"
              color-scheme="alert"
              icon="delete"
              :title="$t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.REMOVE')"
              @click="remove(boton)"
            />
          </div>
        </Draggable>
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.button-card {
  @apply flex items-start gap-2 p-3 mb-2 rounded-lg border border-solid border-slate-100 dark:border-slate-700 bg-slate-25 dark:bg-slate-800;
}

.drag-handle {
  @apply mt-2.5 cursor-grab text-slate-400 shrink-0;
}
</style>
