require "rails_helper"

RSpec.describe "Home", type: :request do
  it "shows the pitch and the fictional example to visitors" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Mornings, again: ten minutes at the kitchen table", "[pause, 8 seconds]",
                                     "Something to make afterwards", "https://intentspring.com")
    expect(response.body).to include("Try it free", "not therapy or medical advice")
  end

  it "sends a signed-in member to their intentions" do
    sign_in_as(create(:user))
    get root_path
    expect(response.body).to include("Go to my intentions")
  end
end
