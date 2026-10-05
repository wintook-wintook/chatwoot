# frozen_string_literal: true

require 'rails_helper'

# proyecto@publicar_prompts (F5)
RSpec.describe PublishedPrompts::Installer do
  let(:author_account) { create(:account) }
  let(:author) { create(:user, account: author_account, role: :administrator) }
  let(:source) do
    create(:tracking_template, account: author_account, name: 'Grúas', complementary_prompt: 'Cotiza con {{hoja:precios}}',
                               retry_interval_value: 3, inbox: create(:inbox, account: author_account), tags: ['vip'])
  end
  let(:publication) { PublishedPrompts::Publisher.new(source, author).publish!(title: 'Agente de grúas') }
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  def install
    described_class.new(publication, account, admin).install!
  end

  it 'creates one agent copy in the account and counts the download' do
    template = install

    expect(template).to have_attributes(
      account_id: account.id, user_id: admin.id, published_prompt_id: publication.id, name: 'Agente de grúas',
      complementary_prompt: 'Cotiza con {{hoja:precios}}', retry_interval_value: 3, inbox_id: nil, tags: []
    )
    expect(publication.reload.downloads_count).to eq(1)
    expect(source.reload.account_id).to eq(author_account.id)
  end

  it 'picks a free name when the title is taken' do
    install
    expect(install.name).to eq('Agente de grúas (2)')
  end
end
