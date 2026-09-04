# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CustomFilter do
  # @tickets_cases F1 — el enum se guarda como entero, asi que su valor numerico
  # es parte del contrato con la base, no un detalle interno. Este spec existe
  # para que agregar un tipo en medio rompa aqui y no en produccion: insertarlo
  # le cambiaria el tipo a todos los filtros guardados que ya existen.
  describe 'filter_type' do
    it 'conserva el valor numerico de cada tipo' do
      expect(described_class.filter_types).to eq(
        'conversation' => 0, 'contact' => 1, 'report' => 2, 'case_ticket' => 3
      )
    end

    it 'agrega case_ticket al final, sin mover los tres anteriores' do
      expect(described_class.filter_types.keys.first(3)).to eq(%w[conversation contact report])
      expect(described_class.filter_types.keys.last).to eq('case_ticket')
    end

    it 'acepta un filtro de tipo case_ticket' do
      filter = create(:custom_filter, filter_type: :case_ticket)

      expect(filter.reload).to be_case_ticket
      expect(filter.read_attribute_before_type_cast(:filter_type)).to eq(3)
    end
  end

  describe 'shared' do
    it 'nace en false cuando no se indica' do
      expect(create(:custom_filter).reload.shared).to be(false)
    end

    it 'se puede marcar como compartida' do
      expect(create(:custom_filter, shared: true).reload.shared).to be(true)
    end

    # La seguridad del cambio de scope de F2 depende de esto: si ninguna fila
    # vieja quedo compartida, "mias + compartidas" devuelve lo mismo que "mias"
    # para las carpetas de Conversaciones, Contactos e Informes.
    it 'deja sin compartir a los filtros de los tres tipos previos' do
      previos = %i[conversation contact report].map { |t| create(:custom_filter, filter_type: t) }

      expect(previos.map { |f| f.reload.shared }).to all(be(false))
    end
  end
end
