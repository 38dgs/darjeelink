# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/darjeelink/api', type: :request do
  subject(:request) { post(darjeelink.api_index_path, params: params, headers: headers) }

  let(:api_token) { Darjeelink::ApiToken.create!(username: 'rspec', active: true) }
  let(:headers) { {} }
  let(:params) { {} }

  before { allow(Darjeelink).to receive(:domain).and_return('darjeelink.com') }

  describe '#create' do
    context 'when no token sent' do
      it 'returns an unauthorized error' do
        request
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when bad token sent' do
      let(:headers) { { Authorization: "Token token=Hacker:#{api_token.token}" } }

      it 'returns an unauthorized error' do
        request
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      let(:headers) { { Authorization: "Token token=#{api_token.username}:#{api_token.token}" } }

      context 'when required params are missing' do
        it 'returns bad request' do
          request
          expect(response).to have_http_status(:bad_request)
        end

        it 'returns the correct error' do
          request
          expect(response.body).to eq({ error: 'Missing required params' }.to_json)
        end
      end

      context 'when the short path is already taken' do
        let(:params) { { short_link: { url: 'https://www.example.com', shortened_path: 'test' } } }

        before { Darjeelink::ShortLink.create!(url: 'https://www.example.co.uk', shortened_path: 'test') }

        it 'returns bad request' do
          request
          expect(response).to have_http_status(:bad_request)
        end

        it 'returns the correct error' do
          request
          expect(response.body).to eq({ error: 'test already used! Choose a different custom path' }.to_json)
        end
      end

      context 'when required params are passed' do
        let(:params) { { short_link: { url: 'https://www.example.com', shortened_path: 'test' } } }

        it 'returns created' do
          request
          expect(response).to have_http_status(:created)
        end

        it 'creates a shortlink' do
          expect { request }.to change(Darjeelink::ShortLink, :count).by(1)
          expect(Darjeelink::ShortLink.last).to have_attributes(url: 'https://www.example.com', shortened_path: 'test')
        end

        it 'returns the shortlink details' do
          request
          expect(response.body).to eq({ short_link: 'darjeelink.com/test' }.to_json)
        end
      end

      context 'when no shortened path is provided' do
        let(:params) { { short_link: { url: 'https://www.example.com' } } }

        it 'returns created' do
          request
          expect(response).to have_http_status(:created)
        end

        it 'creates a shortlink with a generated shortened path' do
          expect { request }.to change(Darjeelink::ShortLink, :count).by(1)
          expect(Darjeelink::ShortLink.last).to have_attributes(url: 'https://www.example.com')
        end

        it 'returns the shortlink details' do
          request
          expect(response.body).to eq(
            { short_link: "darjeelink.com/#{Darjeelink::ShortLink.last.shortened_path}" }.to_json
          )
        end
      end
    end
  end
end