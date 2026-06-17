# frozen_string_literal: true

require 'rails_helper'

# proyecto@bot_seguimiento_calendar
RSpec.describe TrackingTemplate do
  let(:account) { create(:account) }

  describe 'validación de timezone' do
    it 'acepta una zona horaria válida' do
      template = build(:tracking_template, account: account, timezone: 'America/Mexico_City')
      expect(template).to be_valid
    end

    it 'permite dejar la zona horaria vacía (hereda del inbox)' do
      template = build(:tracking_template, account: account, timezone: nil)
      expect(template).to be_valid
    end

    it 'rechaza una zona horaria inválida' do
      template = build(:tracking_template, account: account, timezone: 'Marte/Olympus')
      expect(template).not_to be_valid
      expect(template.errors[:timezone]).to be_present
    end
  end
end
