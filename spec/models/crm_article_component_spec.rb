# frozen_string_literal: true

require 'rails_helper'

# CrmZeus A3 — componentes de los kits (JUEGOS_DET).
RSpec.describe CrmArticleComponent do
  let(:account) { create(:account) }
  let(:kit) { account.crm_articles.create!(name: 'Kit de seguridad', is_kit: true) }
  let(:helmet) { account.crm_articles.create!(name: 'Casco', catalog_status: :catalogued) }
  let(:gloves) { account.crm_articles.create!(name: 'Guantes') } # no catalogado: también puede ir en un kit

  it 'guarda componentes catalogados y no catalogados con sus unidades, en orden' do
    kit.update!(components_attributes: [{ component_id: gloves.id, quantity: 2, position: 1, replaceable: true },
                                        { component_id: helmet.id, quantity: 1, position: 0, units_editable: true }])
    expect(kit.reload.components.map { |row| [row.component.name, row.quantity.to_f] }).to eq([['Casco', 1.0], ['Guantes', 2.0]])
    expect(kit.components.last).to have_attributes(replaceable: true, units_editable: false, account_id: account.id)
  end

  it 'rechaza el mismo kit, otro kit, uno de otra cuenta, uno repetido y unidades en cero' do
    other_kit = account.crm_articles.create!(name: 'Otro kit', is_kit: true)
    foreign = create(:account).crm_articles.create!(name: 'Ajeno')
    { kit => 'no puede ser el mismo kit', other_kit => 'no puede ser otro kit', foreign => 'no pertenece a la cuenta' }.each do |item, message|
      row = kit.components.new(component: item)
      expect(row).not_to be_valid
      expect(row.errors[:component]).to include(message)
    end
    kit.components.create!(component: helmet)
    expect(kit.components.new(component: helmet)).not_to be_valid
    expect(kit.components.new(component: gloves, quantity: 0)).not_to be_valid
  end

  it 'un artículo que es componente no puede volverse kit' do
    kit.components.create!(component: helmet)
    expect(helmet.update(is_kit: true)).to be(false)
    expect(helmet.errors[:is_kit].first).to include('«Kit de seguridad»')
  end

  it 'al dejar de ser kit se borran sus componentes' do
    kit.components.create!(component: helmet)
    kit.update!(is_kit: false)
    expect(kit.reload.components).to be_empty
  end

  it 'no se borra un artículo que es componente; el kit sí, con sus renglones' do
    kit.components.create!(component: helmet)
    expect(helmet.destroy).to be(false)
    expect(helmet.errors[:base].first).to eq('No se puede eliminar: es componente de «Kit de seguridad»')
    kit.destroy!
    expect(described_class.count).to eq(0)
    expect(helmet.reload.destroy).to be_truthy
  end

  # Al borrar la cuenta, los renglones se van antes que los artículos (si no, el FK restrict lo impide).
  it 'la cuenta borra los componentes antes que los artículos' do
    names = Account.reflect_on_all_associations(:has_many).map(&:name)
    expect(names.index(:crm_article_components)).to be < names.index(:crm_articles)
  end
end
