# frozen_string_literal: true

require 'rails_helper'

# Dali — lo que el modelo ve de la plática anterior.
RSpec.describe Assistant::History do
  let(:thread) { instance_double(AssistantThread, messages: messages) }

  def msg(role, content, extra = {}) = { 'role' => role, 'content' => content }.merge(extra)

  context 'when a question was left unanswered' do
    let(:messages) do
      [msg('user', '¿qué tiene hoy Mariana?'), msg('user', '¿cómo instalo la app?'), msg('assistant', 'Así: …')]
    end

    it 'la salta para que no la conteste días después' do
      expect(described_class.messages(thread, 12).pluck(:content)).to eq(['¿cómo instalo la app?', 'Así: …'])
    end
  end

  context 'when the last question has no answer' do
    let(:messages) { [msg('user', 'hola'), msg('assistant', '¡Hola!'), msg('user', 'falló esta')] }

    it 'tampoco la manda' do
      expect(described_class.messages(thread, 12).pluck(:content)).to eq(%w[hola ¡Hola!])
    end
  end

  context 'with guides and proposals in the reply' do
    let(:messages) do
      [msg('user', '¿cómo la instalo?'),
       msg('assistant', 'Está en la guía', 'guides' => %w[dali_telefono dali],
                                           'proposals' => [{ 'type' => 'task', 'labels' => { 't' => 'Llamar' }, 'status' => 'pending' }])]
    end

    it 'las anota entre corchetes' do
      content = described_class.messages(thread, 12).last[:content]
      expect(content).to include('[Propuse task: Llamar — pending]', '[Guías: dali_telefono, dali]')
    end
  end

  describe '.clean' do
    it 'quita los datos de la plática que el modelo copió al final' do
      text = "1. Abre /dali.\n2. Instálala.\n\nDatos de la conversación:\n- Usuario: John\n- Pantalla: inbox"
      expect(described_class.clean(text)).to eq("1. Abre /dali.\n2. Instálala.")
    end

    it 'quita las notas del historial que el modelo copió' do
      text = "No, no está en Play Store.\n\n[Guías: dali_telefono]\n[Propuse task: Llamar — pending]"
      expect(described_class.clean(text)).to eq('No, no está en Play Store.')
    end

    it 'quita la firma corta con la pantalla' do
      text = "No encontré a Jane en el equipo.\n\nJohn, 2026-11-14, viendo: my_summary."
      expect(described_class.clean(text)).to eq('No encontré a Jane en el equipo.')
    end

    it 'quita la firma larga con la fecha y la pantalla en palabras' do
      text = "Pulsa «Llamar».\n\nJohn, sábado 14 de noviembre de 2026, 20:30. Estás viendo: mi resumen."
      expect(described_class.clean(text)).to eq('Pulsa «Llamar».')
    end

    it 'no toca un texto normal' do
      expect(described_class.clean('Los datos de la conversación están en la ficha.')).to eq('Los datos de la conversación están en la ficha.')
    end
  end
end
