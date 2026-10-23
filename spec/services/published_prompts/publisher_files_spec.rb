# frozen_string_literal: true

require 'rails_helper'

# proyecto@publicar_prompts (F6): los archivos del agente que viajan con el prompt.
RSpec.describe PublishedPrompts::Publisher do
  let(:account) { create(:account) }
  let(:author) { create(:user, account: account, role: :administrator) }
  let(:template) { create(:tracking_template, account: account, complementary_prompt: 'Manda {{catalogo}} si lo piden.') }
  let!(:catalogo) { attachment('catalogo', '%PDF catalogo') }
  let!(:logo) { attachment('logo', 'PNG') }

  def attachment(name, content)
    adjunto = template.ai_agent_attachments.new(name: name, account: account)
    adjunto.file.attach(io: StringIO.new(content), filename: "#{name}.bin", content_type: 'application/octet-stream')
    adjunto.save!
    adjunto
  end

  def publish(**args)
    described_class.new(template, author).publish!(**args)
  end

  it 'copies only the chosen files and stops asking for them' do
    pub = publish(attachment_ids: [catalogo.id])

    expect(pub.files.map(&:name)).to eq(['catalogo'])
    expect(pub.files.first.file.blob_id).not_to eq(catalogo.file.blob_id)
    expect(pub.requirements).not_to include(hash_including('kind' => 'attachment'))
  end

  it 'keeps the same file names when republishing without attachment_ids' do
    publish(attachment_ids: [catalogo.id, logo.id])

    expect(publish.files.map(&:name)).to contain_exactly('catalogo', 'logo')
  end

  it 'publishes no files when the author unchecks them all' do
    publish(attachment_ids: [catalogo.id])
    pub = publish(attachment_ids: [])

    expect(pub.files).to be_empty
    expect(pub.requirements).to include({ 'kind' => 'attachment', 'name' => 'catalogo' })
  end

  it 'gives the downloaded agent its own copy of the files' do
    pub = publish(attachment_ids: [catalogo.id])
    other = create(:account)
    copy = PublishedPrompts::Installer.new(pub, other, create(:user, account: other, role: :administrator)).install!

    expect(copy.ai_agent_attachments.map(&:name)).to eq(['catalogo'])
    expect(copy.ai_agent_attachments.first.account_id).to eq(other.id)
  end
end
