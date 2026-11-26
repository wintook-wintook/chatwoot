import CreateEventModal from '../CreateEventModal.vue';

// fix/calendario_eliminar F2 — «Cancelar tarea agendada» y «Cerrar».
const { methods, computed } = CreateEventModal;

const can = agendaItem => methods.canCancelItem.call({ agendaItem });

describe('CreateEventModal · Cancelar tarea agendada', () => {
  it('lo ve el responsable mientras siga agendada', () => {
    expect(can({ status: 'scheduled', participating: false })).toBe(true);
  });

  it('no lo ve el participante (tiene «No puedo ir») ni en tareas cerradas', () => {
    expect(can({ status: 'scheduled', participating: true })).toBe(false);
    ['held', 'no_show', 'cancelled'].forEach(status =>
      expect(can({ status, participating: false })).toBe(false)
    );
  });

  it('no sale en eventos de Google sin tarea', () => {
    expect(can(null)).toBe(false);
  });

  it('al editar el botón de abajo dice «Cerrar»; al crear, «Cancelar»', () => {
    const $t = key => key;
    expect(computed.closeLabel.call({ isEditing: true, $t })).toBe(
      'GOOGLE_CALENDAR.EDIT_EVENT.CLOSE'
    );
    expect(computed.closeLabel.call({ isEditing: false, $t })).toBe(
      'GOOGLE_CALENDAR.CREATE_EVENT.CANCEL'
    );
  });
});
