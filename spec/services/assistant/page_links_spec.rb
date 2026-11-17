# frozen_string_literal: true

require 'rails_helper'

# Dali — las pantallas que menciona salen como liga ([[clave]] → [[ruta|Nombre]]).
RSpec.describe Assistant::PageLinks do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:tools) { Assistant::Tools.new(account: account, user: user, grant: Access::Grant.new(nil, nil), zone: Time.zone) }
  let(:prefix) { "/app/accounts/#{account.id}" }

  def links(text) = described_class.new(tools).call(text)

  it 'liga la pantalla con su nombre del menú' do
    expect(links('Entra a [[opportunities]] y pulsa «Nueva».'))
      .to eq("Entra a [[#{prefix}/tickets/commercial/board|Ventas › Oportunidades]] y pulsa «Nueva».")
  end

  it 'usa el texto que escribió el modelo' do
    expect(links('[[profile|tu perfil]]')).to eq("[[#{prefix}/profile/settings|tu perfil]]")
  end

  it 'mi perfil y la configuración de la cuenta son pantallas distintas' do
    expect(tools.page_path('profile')).to eq("#{prefix}/profile/settings")
    expect(tools.page_path('account_settings')).to eq("#{prefix}/settings/general")
  end

  it 'una clave que no existe queda como texto, sin liga rota' do
    expect(links('Ve a [[no_existe|esa pantalla]] o [[tampoco]].')).to eq('Ve a esa pantalla o .')
  end

  it 'un registro que el usuario no puede ver queda como texto' do
    expect(links('Revisa [[case:999999|OPB-99999]].')).to eq('Revisa OPB-99999.')
  end

  it 'read_guide trae las pantallas con su nombre' do
    guide = tools.call('read_guide', { 'key' => 'contratos' })[:result]
    expect(guide[:pages]['contracts']).to eq('Clientes › Contratos')
  end
end
