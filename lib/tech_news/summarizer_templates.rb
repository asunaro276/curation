# frozen_string_literal: true

module TechNews
  module SummarizerTemplates
    # テンプレート定義
    TEMPLATES = {
      'default' => {
        name: 'default',
        description: '標準形式（2-3文の要約 + 最大3点の箇条書き）',
        system_prompt: 'あなたは技術ニュースのキュレーターです。以下の記事を日本語で要約してください。',
        output_format: <<~FORMAT
          以下の形式で出力してください:
          1. 2-3文の簡潔な要約
          2. 重要なポイント（箇条書き、最大3点）
        FORMAT
      },
      'concise' => {
        name: 'concise',
        description: '超簡潔版（1-2文のみ）',
        system_prompt: 'あなたは技術ニュースのキュレーターです。以下の記事を極めて簡潔に日本語で要約してください。',
        output_format: <<~FORMAT
          以下の形式で出力してください:
          - 1-2文の超簡潔な要約
        FORMAT
      },
      'detailed' => {
        name: 'detailed',
        description: '詳細版（4-5文の要約 + 5点程度の箇条書き）',
        system_prompt: 'あなたは技術ニュースのキュレーターです。以下の記事を詳細に日本語で要約してください。',
        output_format: <<~FORMAT
          以下の形式で出力してください:
          1. 4-5文の詳細な要約
          2. 重要なポイント（箇条書き、5点程度）
        FORMAT
      },
      'technical' => {
        name: 'technical',
        description: '技術特化版（アーキテクチャ、技術スタック、パフォーマンスなどに焦点）',
        system_prompt: 'あなたは技術ニュースのキュレーターです。以下の記事を技術的な観点から日本語で要約してください。',
        output_format: <<~FORMAT
          以下の形式で出力してください:
          1. 2-3文の技術的な要約
          2. 技術的な詳細（箇条書き、最大5点）
             - アーキテクチャの特徴
             - 使用技術・技術スタック
             - パフォーマンスへの影響
             - セキュリティへの配慮
             - その他の技術的なポイント
        FORMAT
      },
      'bullet_points' => {
        name: 'bullet_points',
        description: '箇条書きのみ（5-7点）',
        system_prompt: 'あなたは技術ニュースのキュレーターです。以下の記事を箇条書き形式で日本語で要約してください。',
        output_format: <<~FORMAT
          以下の形式で出力してください:
          - 箇条書きのみ（5-7点）
          - 各項目は簡潔に1文で記述
        FORMAT
      }
    }.freeze

    # テンプレート取得メソッド
    def self.get_template(name)
      template = TEMPLATES[name]
      if template.nil?
        raise TemplateNotFoundError,
              "Template '#{name}' not found. Available templates: #{available_templates.join(', ')}"
      end

      template
    end

    # 利用可能なテンプレート一覧
    def self.available_templates
      TEMPLATES.keys
    end

    # テンプレートが存在するかチェック
    def self.template_exists?(name)
      TEMPLATES.key?(name)
    end

    # テンプレート一覧を説明付きで取得
    def self.list_templates
      TEMPLATES.map { |name, template| { name: name, description: template[:description] } }
    end

    # カスタム例外クラス
    class TemplateNotFoundError < StandardError; end
  end
end
