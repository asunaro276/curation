# frozen_string_literal: true

require 'spec_helper'
require 'tech_news/summarizer_templates'

RSpec.describe TechNews::SummarizerTemplates do
  describe '.get_template' do
    context '有効なテンプレート名を指定した場合' do
      it 'defaultテンプレートを取得できる' do
        template = described_class.get_template('default')
        expect(template[:name]).to eq('default')
        expect(template[:system_prompt]).to be_a(String)
        expect(template[:output_format]).to be_a(String)
        expect(template[:description]).to be_a(String)
      end

      it 'conciseテンプレートを取得できる' do
        template = described_class.get_template('concise')
        expect(template[:name]).to eq('concise')
        expect(template[:system_prompt]).to include('極めて簡潔')
      end

      it 'detailedテンプレートを取得できる' do
        template = described_class.get_template('detailed')
        expect(template[:name]).to eq('detailed')
        expect(template[:output_format]).to include('4-5文')
      end

      it 'technicalテンプレートを取得できる' do
        template = described_class.get_template('technical')
        expect(template[:name]).to eq('technical')
        expect(template[:output_format]).to include('技術的な詳細')
      end

      it 'bullet_pointsテンプレートを取得できる' do
        template = described_class.get_template('bullet_points')
        expect(template[:name]).to eq('bullet_points')
        expect(template[:output_format]).to include('箇条書きのみ')
      end
    end

    context '無効なテンプレート名を指定した場合' do
      it 'TemplateNotFoundErrorを発生させる' do
        expect { described_class.get_template('invalid') }
          .to raise_error(TechNews::SummarizerTemplates::TemplateNotFoundError)
          .with_message(/Template 'invalid' not found/)
      end

      it 'エラーメッセージに利用可能なテンプレート一覧を含む' do
        expect { described_class.get_template('unknown') }
          .to raise_error(TechNews::SummarizerTemplates::TemplateNotFoundError)
          .with_message(/Available templates:/)
      end
    end
  end

  describe '.available_templates' do
    it '5種類のテンプレート名を返す' do
      templates = described_class.available_templates
      expect(templates).to contain_exactly('default', 'concise', 'detailed', 'technical', 'bullet_points')
    end
  end

  describe '.template_exists?' do
    it '存在するテンプレートに対してtrueを返す' do
      expect(described_class.template_exists?('default')).to be true
      expect(described_class.template_exists?('concise')).to be true
    end

    it '存在しないテンプレートに対してfalseを返す' do
      expect(described_class.template_exists?('invalid')).to be false
      expect(described_class.template_exists?('unknown')).to be false
    end
  end

  describe '.list_templates' do
    it 'すべてのテンプレートの名前と説明を返す' do
      templates = described_class.list_templates
      expect(templates).to be_an(Array)
      expect(templates.length).to eq(5)

      templates.each do |template|
        expect(template).to have_key(:name)
        expect(template).to have_key(:description)
        expect(template[:name]).to be_a(String)
        expect(template[:description]).to be_a(String)
      end
    end

    it '正しい説明を持つ' do
      templates = described_class.list_templates
      default_template = templates.find { |t| t[:name] == 'default' }
      expect(default_template[:description]).to include('標準形式')
    end
  end

  describe 'テンプレート構造の検証' do
    it 'すべてのテンプレートが必須フィールドを持つ' do
      described_class.available_templates.each do |name|
        template = described_class.get_template(name)
        expect(template).to have_key(:name)
        expect(template).to have_key(:description)
        expect(template).to have_key(:system_prompt)
        expect(template).to have_key(:output_format)
      end
    end

    it 'すべてのテンプレートのsystem_promptが日本語を含む' do
      described_class.available_templates.each do |name|
        template = described_class.get_template(name)
        expect(template[:system_prompt]).to match(/日本語/)
      end
    end
  end
end
