// Motor 2.0 — base de cada sección de la ficha: recibe la ficha entera (v-model) y emite una
// copia con el cambio, sin mutar la prop.
export default {
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, required: true },
    options: { type: Object, default: () => ({}) },
  },
  emits: ['input'],
  computed: {
    m2() {
      return this.value.motor2;
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`MOTOR2.${key}`, args);
    },
    set(field, val) {
      this.$emit('input', { ...this.value, [field]: val });
    },
    setM2(field, val) {
      this.set('motor2', { ...this.m2, [field]: val });
    },
    skill(key) {
      return this.m2.skills[key] || {};
    },
    setSkill(key, patch) {
      this.setM2('skills', {
        ...this.m2.skills,
        [key]: { ...this.skill(key), ...patch },
      });
    },
  },
};
