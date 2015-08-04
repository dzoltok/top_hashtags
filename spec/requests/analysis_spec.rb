require "rails_helper"

RSpec.describe "Analysis", type: :request do

  describe "valid Twitter handle, no limit specified" do
    before(:all) do
      get '/analysis.json?handle=davezoltok'
    end

    it "returns successfully" do
      expect(response).to be_success
    end

    it "returns the correct content type" do
      expect(response.content_type).to eq("application/json")
    end

    it "returns a collection of 10 objects containing both a hashtag and a count" do
      body = JSON.parse(response.body)
      expect(body.count).to eq(10)
      expect(body.all? { |item| item.key?('hashtag') }).to be true
      expect(body.all? { |item| item.key?('count') }).to be true
    end
  end

  describe "valid Twitter handle, limit specified" do
    before(:all) do
      get '/analysis.json?handle=davezoltok&limit=100'
    end

    it "returns successfully" do
      expect(response).to be_success
    end

    it "returns a collection of 8 objects containing both a hashtag and a count" do
      body = JSON.parse(response.body)
      expect(body.count).to eq(8)
      expect(body.all? { |item| item.key?('hashtag') }).to be true
      expect(body.all? { |item| item.key?('count') }).to be true
    end
  end

  describe "valid Twitter handle, invalid limit specified" do
    it "returns an error if limit is non-numeric" do
      get '/analysis.json?handle=davezoltok&limit=abc'
      # expect(response.status).to eq(500)
      expect(response).to be_error
    end

    it "returns an error if limit is not a non-negative integer" do
      get '/analysis.json?handle=davezoltok&limit=-10'
      expect(response).to be_error
      # expect(response.status).to eq(500)
    end

    it "returns an error if limit is greater than 2000" do
      get '/analysis.json?handle=davezoltok&limit=3000'
      expect(response).to be_error
      # expect(response.status).to eq(500)
    end
  end

  describe "invalid Twitter handle" do
    it "returns an error if the Twitter handle does not exist" do
      get '/analysis.json?handle=dzoltok'
      expect(response).to be_error
      # expect(response.status).to eq(500)
    end
  end
end
