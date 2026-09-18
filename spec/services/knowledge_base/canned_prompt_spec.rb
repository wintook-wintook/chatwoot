# frozen_string_literal: true

require 'rails_helper'

# proyecto@predefinidas_prompt — docs/predefinidas_prompt_plan.md §3.7
RSpec.describe KnowledgeBase::CannedPrompt do
  let(:account) { create(:account) }
  let(:source)  { create(:knowledge_source, account: account, source_type: 'canned_response') }

  def canned(**attrs)
    create(:canned_response, account: account, short_code: 'COTIZACION', content: 'Equipos Dell y HP.', **attrs)
  end

  def item_for(canned_response)
    build(:knowledge_item, account: account, knowledge_source: source, source_type: 'canned_response',
                           source_id: canned_response.id, title: canned_response.short_code)
  end

  describe '.detect' do
    it 'el mensaje es el prompt aunque también tenga Prompt de Contenido' do
      prompt = described_class.detect(account, [item_for(canned(content_is_prompt: true, content_prompts: 'otra cosa'))])

      expect(prompt.mode).to eq(:message_is_prompt)
      expect(prompt.instructions).to eq('Equipos Dell y HP.')
      expect(prompt.information).to eq('')
    end

    it 'con Prompt de Contenido, el mensaje es la información' do
      prompt = described_class.detect(account, [item_for(canned(content_prompts: 'Pedí la cantidad.'))])

      expect(prompt.mode).to eq(:content_prompt)
      expect(prompt.instructions).to eq('Pedí la cantidad.')
      expect(prompt.information).to eq('Equipos Dell y HP.')
    end

    it 'sin prompt (o solo espacios), como siempre' do
      expect(described_class.detect(account, [item_for(canned)])).to be_nil
      expect(described_class.detect(account, [item_for(canned(short_code: 'ESPACIOS', content_prompts: "  \n"))])).to be_nil
    end

    it 'solo cuenta la primera: el prompt de la segunda no aplica' do
      items = [item_for(canned), item_for(canned(short_code: 'OTRA', content_is_prompt: true))]

      expect(described_class.detect(account, items)).to be_nil
    end

    it 'no aplica a otras fuentes ni a respuestas de otra cuenta' do
      article = build(:knowledge_item, account: account, knowledge_source: source, source_type: 'article', source_id: 1)
      ajena   = create(:canned_response, content_is_prompt: true)

      expect(described_class.detect(account, [article])).to be_nil
      expect(described_class.detect(account, [item_for(ajena)])).to be_nil
      expect(described_class.detect(account, [])).to be_nil
    end
  end

  describe '#leaks?' do
    let(:prompt) do
      described_class.new(:content_prompt, canned(content_prompts: <<~TXT))
        Esta es la respuesta que darás si alguien te pregunta por el precio de equipo de cómputo.
        Respondé: "Con gusto te preparo una cotización con los equipos que necesitas hoy mismo"
      TXT
    end

    it 'descarta la respuesta que copia las instrucciones (sin importar tildes ni mayúsculas)' do
      expect(prompt.leaks?('Claro. ESTA ES LA RESPUESTA QUE DARAS si alguien te pregunta por el precio.')).to be(true)
    end

    it 'lo que va entre comillas es para decirlo: copiarlo no es filtrar' do
      expect(prompt.leaks?('Hola Ana, con gusto te preparo una cotización con los equipos que necesitas hoy mismo.'))
        .to be(false)
    end

    it 'una respuesta propia no es filtración' do
      expect(prompt.leaks?('¿Qué equipo necesitas y cuántas unidades?')).to be(false)
    end
  end
end
