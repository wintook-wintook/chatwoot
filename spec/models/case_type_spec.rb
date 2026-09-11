# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — ITIL pasó de ser un ajuste global de cuenta (CaseSetting) a
# ser una propiedad del tipo de caso. Este spec cubre que la siembra de columnas
# por defecto usa el `itil_enabled` propio del tipo, sin mirar la cuenta.
RSpec.describe CaseType do
  let(:account) { create(:account) }

  describe '#seed_default_columns (after_create)' do
    it 'siembra la plantilla ITIL (6 columnas) cuando el tipo nace con itil_enabled: true' do
      type = described_class.create!(account: account, name: 'Tickets', color: '#3b82f6', itil_enabled: true)

      expect(type.case_type_columns.count).to eq(6)
      expect(type.case_type_columns.ordered.map(&:label)).to include('Asignado / Diagnóstico')
    end

    it 'siembra la plantilla simple (5 columnas) cuando el tipo nace con itil_enabled: false' do
      type = described_class.create!(account: account, name: 'Soporte', color: '#3b82f6', itil_enabled: false)

      expect(type.case_type_columns.count).to eq(5)
    end

    it 'no depende del CaseSetting de la cuenta: una cuenta ITIL puede tener un tipo simple y viceversa' do
      CaseSetting.for_account(account).update!(reopen_window_days: 15) # crea el registro, sin tocar itil
      account.case_setting.update_column(:itil_enabled, true) # rubocop:disable Rails/SkipsModelValidations

      type = described_class.create!(account: account, name: 'Simple a propósito', color: '#3b82f6', itil_enabled: false)

      expect(type.case_type_columns.count).to eq(5)
    end
  end
end
