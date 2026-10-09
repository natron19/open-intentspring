require "rails_helper"

RSpec.describe "Intentions", type: :request do
  let(:user)      { create(:user) }
  let(:other)     { create(:user) }
  let(:intention) { create(:intention, user: user) }

  let(:valid_params) do
    { intention: { sentence: "Getting my hands back in the soil this spring.", length_minutes: "5", tone: "warm" } }
  end

  context "when not signed in" do
    it "redirects every page to sign in" do
      get intentions_path
      expect(response).to redirect_to(sign_in_path)
      get dashboard_path
      expect(response).to redirect_to(sign_in_path)
      post intentions_path, params: valid_params
      expect(response).to redirect_to(sign_in_path)
    end
  end

  context "when signed in" do
    before { sign_in_as(user) }

    it "shows the dashboard as My intentions with only the user's own intentions" do
      create(:intention, user: user, sentence: "Mine to practise")
      create(:intention, user: other, sentence: "Someone else's sentence")
      get dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My intentions", "Mine to practise")
      expect(response.body).not_to include("Someone else&#39;s sentence")
    end

    it "shows the latest script's title on the dashboard" do
      create(:guided_script, :completed, intention: intention)
      get intentions_path
      expect(response.body).to include("The long way, by the river", "written")
    end

    it "shows an empty state with no intentions" do
      get intentions_path
      expect(response.body).to include("Name your first intention")
    end

    it "renders the new form with the labels the UI journey fills" do
      get new_intention_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("What are you reaching for, in one sentence?", "Length", "Tone",
                                       "1 minute", "Plain: direct, everyday words", "Create Intention")
      expect(response.body).to include('for="intention_sentence"', 'for="intention_length_minutes"', 'for="intention_tone"')
    end

    it "creates an intention and redirects to it" do
      expect { post intentions_path, params: valid_params }.to change(user.intentions, :count).by(1)
      intention = Intention.last
      expect(response).to redirect_to(intention_path(intention))
      expect(intention.length_minutes).to eq(5)
      expect(intention.tone).to eq("warm")
    end

    it "re-renders the form with 422 on invalid input" do
      expect {
        post intentions_path, params: { intention: valid_params[:intention].merge(length_minutes: "7") }
      }.not_to change(Intention, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "shows the intention with the Write my script button" do
      get intention_path(intention)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(intention.sentence, "Write my script", "Only the sentence above")
    end

    it "updates an intention" do
      patch intention_path(intention), params: { intention: { tone: "plain" } }
      expect(response).to redirect_to(intention_path(intention))
      expect(intention.reload.tone).to eq("plain")
    end

    it "rejects an invalid update with 422" do
      patch intention_path(intention), params: { intention: { tone: "loud" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "deletes an intention" do
      intention
      expect { delete intention_path(intention) }.to change(Intention, :count).by(-1)
      expect(response).to redirect_to(intentions_path)
    end
  end

  # open-base's ApplicationController answers RecordNotFound with a redirect to root and an alert.
  context "when signed in as a different user" do
    before { sign_in_as(other) }

    it "cannot see, edit, update, or delete the intention" do
      get intention_path(intention)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("That record could not be found.")
      get edit_intention_path(intention)
      expect(response).to redirect_to(root_path)
      patch intention_path(intention), params: { intention: { sentence: "Hijacked" } }
      expect(response).to redirect_to(root_path)
      expect { delete intention_path(intention) }.not_to change(Intention, :count)
      expect(response).to redirect_to(root_path)
      expect(intention.reload.sentence).not_to eq("Hijacked")
    end
  end
end
