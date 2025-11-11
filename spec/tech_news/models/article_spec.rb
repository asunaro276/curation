# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TechNews::Models::Article do
  let(:valid_attributes) do
    {
      title: 'Test Article',
      url: 'https://example.com/article',
      source: 'Test Source',
      published_at: Time.now,
      description: 'A test article description'
    }
  end

  describe '#initialize' do
    it 'creates an article with valid attributes' do
      article = described_class.new(**valid_attributes)
      expect(article.title).to eq('Test Article')
      expect(article.url).to eq('https://example.com/article')
      expect(article.source).to eq('Test Source')
    end

    it 'raises error when title is missing' do
      expect do
        described_class.new(**valid_attributes.merge(title: nil))
      end.to raise_error(ArgumentError, /title is required/)
    end

    it 'raises error when url is missing' do
      expect do
        described_class.new(**valid_attributes.merge(url: nil))
      end.to raise_error(ArgumentError, /url is required/)
    end

    it 'raises error when url is invalid' do
      expect do
        described_class.new(**valid_attributes.merge(url: 'not-a-url'))
      end.to raise_error(ArgumentError, /url is invalid/)
    end

    it 'raises error when source is missing' do
      expect do
        described_class.new(**valid_attributes.merge(source: nil))
      end.to raise_error(ArgumentError, /source is required/)
    end

    it 'accepts nil description' do
      article = described_class.new(**valid_attributes.merge(description: nil))
      expect(article.description).to be_nil
    end

    it 'parses string time to Time object' do
      article = described_class.new(**valid_attributes.merge(published_at: '2024-01-01T10:00:00Z'))
      expect(article.published_at).to be_a(Time)
    end
  end

  describe '#valid?' do
    it 'returns true for valid article' do
      article = described_class.new(**valid_attributes)
      expect(article.valid?).to be true
    end
  end

  describe '#to_h' do
    it 'converts article to hash' do
      article = described_class.new(**valid_attributes)
      hash = article.to_h
      expect(hash[:title]).to eq('Test Article')
      expect(hash[:url]).to eq('https://example.com/article')
      expect(hash[:source]).to eq('Test Source')
    end
  end

  describe '#metadata' do
    it 'stores additional metadata' do
      article = described_class.new(**valid_attributes.merge(metadata: { language: 'ruby' }))
      expect(article.metadata[:language]).to eq('ruby')
    end
  end
end
