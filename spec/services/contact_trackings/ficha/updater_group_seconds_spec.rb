# frozen_string_literal: true

require 'rails_helper'

# Recursos › Canal y seguimiento: «Esperar mensajes seguidos (segundos)» (ContactTrackings::MessageBurst).
RSpec.describe ContactTrackings::Ficha::Updater do
  let(:template) { create(:tracking_template, resources: { 'group_seconds' => 8 }) }

  def segundos(params)
    described_class.new(template, ActionController::Parameters.new(params), items: []).send(:group_seconds)
  end

  it 'guarda los segundos con tope, 0 la apaga y sin el campo deja lo que tenía' do
    expect(segundos(group_seconds: 12)).to eq(12)
    expect(segundos(group_seconds: 99)).to eq(30)
    expect(segundos(group_seconds: 0)).to be_nil
    expect(segundos({})).to eq(8)
  end
end
