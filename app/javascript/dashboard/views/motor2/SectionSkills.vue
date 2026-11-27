<script>
// Motor 2.0 › Qué hace: las habilidades, cada una con su interruptor, una línea de lo que hace
// y sus campos. Las reglas las pone el código (Motor2::Skills): aquí solo se llenan los datos.
// Archivos usa la misma regla por archivo que el 1.0 (FileRule, sin cambios).
import { useAlert } from 'dashboard/composables';
import AiAgentAttachmentsAPI from 'dashboard/api/aiAgentAttachments';
import formSection from './formSection';
import FileRule from '../contactTrackings/ficha/FileRule.vue';

const KINDS = ['llamada', 'videollamada', 'visita', 'oficina'];
const PRIORITIES = ['', 'low', 'medium', 'high', 'urgent'];
const slug = text =>
  (text || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '')
    .slice(0, 40);

export default {
  components: { FileRule },
  mixins: [formSection],
  props: {
    templateId: { type: Number, default: null },
    attachments: { type: Array, default: () => [] },
  },
  emits: ['uploaded'],
  data() {
    return {
      open: 'data',
      kinds: KINDS,
      priorities: PRIORITIES,
      uploading: false,
    };
  },
  computed: {
    cards() {
      return ['data', 'offers', 'appointments', 'tickets', 'files', 'handoff'];
    },
    ticketOptions() {
      return [
        { value: '*', label: this.t('SKILLS.ANY_TICKET') },
        ...(this.options.case_types || []).map(c => ({
          value: c.name,
          label: c.name,
        })),
      ];
    },
  },
  methods: {
    isOn(key) {
      return key === 'files'
        ? this.attachments.length > 0
        : !!this.skill(key).on;
    },
    toggle(key) {
      this.setSkill(key, { on: !this.skill(key).on });
      this.open = key;
    },
    // Listas de una habilidad: agregar, cambiar y quitar renglones.
    rows(key, list) {
      return this.skill(key)[list] || [];
    },
    setRow(key, list, index, patch) {
      const rows = [...this.rows(key, list)];
      rows[index] = { ...rows[index], ...patch };
      this.setSkill(key, { [list]: rows });
    },
    addRow(key, list, row) {
      this.setSkill(key, { [list]: [...this.rows(key, list), row] });
    },
    removeRow(key, list, index) {
      this.setSkill(key, {
        [list]: this.rows(key, list).filter((_, i) => i !== index),
      });
    },
    setFieldLabel(index, label) {
      this.setRow('data', 'fields', index, { label, key: slug(label) });
    },
    setFieldValues(index, text) {
      const values = text
        .split(',')
        .map(v => v.trim())
        .filter(Boolean);
      this.setRow('data', 'fields', index, { values });
    },
    toggleCalendar(id) {
      const ids = this.value.calendarIds.includes(id)
        ? this.value.calendarIds.filter(item => item !== id)
        : [...this.value.calendarIds, id];
      this.set('calendarIds', ids);
    },
    setRule(name, rule) {
      this.set('fileRules', { ...this.value.fileRules, [name]: rule });
    },
    async upload(event) {
      const file = event.target.files[0];
      event.target.value = '';
      if (!file || !this.templateId) return;
      this.uploading = true;
      try {
        const name = slug(file.name.replace(/\.[^.]+$/, '')) || 'archivo';
        await AiAgentAttachmentsAPI.upload(this.templateId, { name, file });
        this.setRule(name, { ask: true });
        this.$emit('uploaded');
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('SKILLS.UPLOAD_ERROR'));
      } finally {
        this.uploading = false;
      }
    },
  },
};
</script>

<template>
  <div class="space-y-3">
    <p class="m2-hint">{{ t('SKILLS.HINT') }}</p>
    <div
      v-for="key in cards"
      :key="key"
      class="border rounded-lg border-slate-100 dark:border-slate-700"
      :data-skill="key"
    >
      <div class="flex items-center gap-3 p-3">
        <button
          type="button"
          class="flex-1 min-w-0 text-left"
          @click="open = open === key ? null : key"
        >
          <span class="block text-sm font-medium">
            {{ t(`SKILLS.${key.toUpperCase()}.TITLE`) }}
          </span>
          <span class="block text-xs text-slate-500">
            {{ t(`SKILLS.${key.toUpperCase()}.LINE`) }}
          </span>
        </button>
        <woot-switch
          v-if="key !== 'files'"
          :value="isOn(key)"
          @input="toggle(key)"
        />
      </div>

      <div
        v-if="open === key"
        class="p-3 space-y-3 border-t border-slate-100 dark:border-slate-700"
      >
        <!-- Preguntas y datos del cliente -->
        <template v-if="key === 'data'">
          <div
            v-for="(field, i) in rows('data', 'fields')"
            :key="i"
            class="grid gap-2 md:grid-cols-[1fr_1fr_auto_auto] items-center"
          >
            <input
              :value="field.label"
              type="text"
              :placeholder="t('SKILLS.DATA.LABEL')"
              @input="setFieldLabel(i, $event.target.value)"
            />
            <input
              :value="(field.values || []).join(', ')"
              type="text"
              :placeholder="t('SKILLS.DATA.VALUES')"
              @change="setFieldValues(i, $event.target.value)"
            />
            <label class="flex items-center gap-1 text-xs">
              <input
                type="checkbox"
                class="!mb-0"
                :checked="field.ask"
                @change="setRow('data', 'fields', i, { ask: !field.ask })"
              />
              {{ t('SKILLS.DATA.ASK') }}
            </label>
            <woot-button
              variant="clear"
              color-scheme="secondary"
              size="tiny"
              icon="dismiss"
              @click="removeRow('data', 'fields', i)"
            />
          </div>
          <woot-button
            variant="link"
            size="small"
            icon="add"
            @click="
              addRow('data', 'fields', {
                label: '',
                key: '',
                ask: true,
                values: [],
              })
            "
          >
            {{ t('SKILLS.DATA.ADD') }}
          </woot-button>
        </template>

        <!-- Ofertas escalonadas -->
        <template v-else-if="key === 'offers'">
          <label class="block">
            <span class="m2-label">{{ t('SKILLS.OFFERS.OBJECTION') }}</span>
            <input
              :value="skill('offers').objection"
              type="text"
              :placeholder="t('SKILLS.OFFERS.OBJECTION_PH')"
              @input="setSkill('offers', { objection: $event.target.value })"
            />
          </label>
          <div
            v-for="(step, i) in rows('offers', 'steps')"
            :key="i"
            class="grid gap-2 md:grid-cols-[auto_1fr_160px_auto] items-start"
          >
            <span class="pt-2 text-xs font-medium text-slate-500">
              {{ i + 1 }}
            </span>
            <textarea
              :value="step.text"
              rows="2"
              :placeholder="t('SKILLS.OFFERS.STEP_PH')"
              @input="
                setRow('offers', 'steps', i, { text: $event.target.value })
              "
            />
            <select
              :value="step.file || ''"
              @change="
                setRow('offers', 'steps', i, { file: $event.target.value })
              "
            >
              <option value="">{{ t('SKILLS.OFFERS.NO_FILE') }}</option>
              <option v-for="a in attachments" :key="a.id" :value="a.name">
                {{ a.name }}
              </option>
            </select>
            <woot-button
              variant="clear"
              color-scheme="secondary"
              size="tiny"
              icon="dismiss"
              @click="removeRow('offers', 'steps', i)"
            />
          </div>
          <woot-button
            variant="link"
            size="small"
            icon="add"
            @click="addRow('offers', 'steps', { text: '', file: '' })"
          >
            {{ t('SKILLS.OFFERS.ADD') }}
          </woot-button>
        </template>

        <!-- Citas -->
        <template v-else-if="key === 'appointments'">
          <p v-if="!(options.calendars || []).length" class="m2-hint">
            {{ t('SKILLS.APPOINTMENTS.NO_CALENDARS') }}
          </p>
          <label
            v-for="cal in options.calendars || []"
            :key="cal.id"
            class="flex items-center gap-2 text-sm"
          >
            <input
              type="checkbox"
              class="!mb-0"
              :checked="value.calendarIds.includes(cal.id)"
              @change="toggleCalendar(cal.id)"
            />
            {{ cal.name }}
            <span v-if="cal.warning" class="text-xs text-amber-600">
              {{ cal.warning }}
            </span>
          </label>
          <div class="grid gap-2 md:grid-cols-3">
            <label class="block">
              <span class="m2-label">{{ t('SKILLS.APPOINTMENTS.KIND') }}</span>
              <select
                :value="skill('appointments').kind"
                @change="
                  setSkill('appointments', { kind: $event.target.value })
                "
              >
                <option v-for="k in kinds" :key="k" :value="k">
                  {{ t(`SKILLS.APPOINTMENTS.KINDS.${k}`) }}
                </option>
              </select>
            </label>
            <label class="block">
              <span class="m2-label">{{
                t('SKILLS.APPOINTMENTS.MINUTES')
              }}</span>
              <input
                :value="value.duration"
                type="number"
                min="15"
                max="240"
                step="15"
                @input="set('duration', Number($event.target.value))"
              />
            </label>
            <label class="block">
              <span class="m2-label">{{
                t('SKILLS.APPOINTMENTS.LOCATION')
              }}</span>
              <input
                :value="skill('appointments').location"
                type="text"
                @input="
                  setSkill('appointments', { location: $event.target.value })
                "
              />
            </label>
          </div>
          <label class="block">
            <span class="m2-label">{{ t('SKILLS.APPOINTMENTS.WHEN') }}</span>
            <input
              :value="skill('appointments').when"
              type="text"
              :placeholder="t('SKILLS.APPOINTMENTS.WHEN_PH')"
              @input="setSkill('appointments', { when: $event.target.value })"
            />
          </label>
        </template>

        <!-- Casos -->
        <template v-else-if="key === 'tickets'">
          <div
            v-for="(type, i) in rows('tickets', 'types')"
            :key="i"
            class="grid gap-2 md:grid-cols-[200px_1fr_auto] items-center"
          >
            <select
              :value="type.case_type_id || ''"
              @change="
                setRow('tickets', 'types', i, {
                  case_type_id: Number($event.target.value),
                })
              "
            >
              <option value="">{{ t('SKILLS.TICKETS.TYPE') }}</option>
              <option
                v-for="c in options.case_types || []"
                :key="c.id"
                :value="c.id"
              >
                {{ c.name }}
              </option>
            </select>
            <input
              :value="type.when"
              type="text"
              :placeholder="t('SKILLS.TICKETS.WHEN_PH')"
              @input="
                setRow('tickets', 'types', i, { when: $event.target.value })
              "
            />
            <woot-button
              variant="clear"
              color-scheme="secondary"
              size="tiny"
              icon="dismiss"
              @click="removeRow('tickets', 'types', i)"
            />
          </div>
          <woot-button
            variant="link"
            size="small"
            icon="add"
            @click="
              addRow('tickets', 'types', { case_type_id: null, when: '' })
            "
          >
            {{ t('SKILLS.TICKETS.ADD') }}
          </woot-button>
          <label class="block max-w-xs">
            <span class="m2-label">{{ t('SKILLS.TICKETS.PRIORITY') }}</span>
            <select
              :value="skill('tickets').priority || ''"
              @change="setSkill('tickets', { priority: $event.target.value })"
            >
              <option v-for="p in priorities" :key="p" :value="p">
                {{ t(`SKILLS.TICKETS.PRIORITIES.${p || 'auto'}`) }}
              </option>
            </select>
          </label>
        </template>

        <!-- Archivos con regla -->
        <template v-else-if="key === 'files'">
          <p v-if="!templateId" class="m2-hint">
            {{ t('SKILLS.FILES.SAVE_FIRST') }}
          </p>
          <div v-for="a in attachments" :key="a.id" class="space-y-1">
            <span class="text-sm font-medium">{{ a.name }}</span>
            <FileRule
              :value="value.fileRules[a.name]"
              :attempts="value.channel.attempts"
              :ticket-options="ticketOptions"
              :show-booking="value.calendarIds.length > 0"
              @input="rule => setRule(a.name, rule)"
            />
          </div>
          <label
            v-if="templateId"
            class="inline-flex items-center gap-2 text-sm cursor-pointer text-woot-600"
          >
            <input
              type="file"
              class="hidden"
              :disabled="uploading"
              @change="upload"
            />
            <fluent-icon icon="attach" size="14" />
            {{
              uploading ? t('SKILLS.FILES.UPLOADING') : t('SKILLS.FILES.UPLOAD')
            }}
          </label>
        </template>

        <!-- Pasar a una persona -->
        <template v-else-if="key === 'handoff'">
          <label class="block">
            <span class="m2-label">{{ t('SKILLS.HANDOFF.WHEN') }}</span>
            <input
              :value="skill('handoff').when"
              type="text"
              :placeholder="t('SKILLS.HANDOFF.WHEN_PH')"
              @input="setSkill('handoff', { when: $event.target.value })"
            />
          </label>
          <div class="grid gap-2 md:grid-cols-2">
            <label class="block">
              <span class="m2-label">{{ t('SKILLS.HANDOFF.USER') }}</span>
              <select
                :value="skill('handoff').user_id || ''"
                @change="
                  setSkill('handoff', {
                    user_id: Number($event.target.value) || null,
                  })
                "
              >
                <option value="">{{ t('SKILLS.HANDOFF.NOBODY') }}</option>
                <option
                  v-for="u in options.users || []"
                  :key="u.id"
                  :value="u.id"
                >
                  {{ u.name }}
                </option>
              </select>
            </label>
            <label class="block">
              <span class="m2-label">{{ t('SKILLS.HANDOFF.TEAM') }}</span>
              <select
                :value="skill('handoff').team_id || ''"
                @change="
                  setSkill('handoff', {
                    team_id: Number($event.target.value) || null,
                  })
                "
              >
                <option value="">{{ t('SKILLS.HANDOFF.NOBODY') }}</option>
                <option
                  v-for="tm in options.teams || []"
                  :key="tm.id"
                  :value="tm.id"
                >
                  {{ tm.name }}
                </option>
              </select>
            </label>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>
