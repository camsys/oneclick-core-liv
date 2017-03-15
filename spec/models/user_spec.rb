require 'rails_helper'

RSpec.describe User, type: :model do
  
  let!(:english_traveler) { FactoryGirl.create(:english_speaker, :eligible, :not_a_veteran, :needs_accommodation) }
  let!(:traveler) { FactoryGirl.create :user }

  it { should have_many :trips }
  it { should have_and_belong_to_many :accommodations }
  it { should respond_to :roles }
  it { should have_many(:user_eligibilities) }
  it { should have_many(:eligibilities).through(:user_eligibilities) }

  it 'returns a locale for a user' do
    expect(english_traveler.locale).to eq(english_traveler.preferred_locale) #This user has a preferred locale, so that one should be found
    expect(traveler.locale).to eq(Locale.find_by(name: "en")) #This user does not have a preferred locale, so English should be returned.
  end

  it 'returns the user_profile_hash' do
    expect(english_traveler.profile_hash[:email]).to eq(english_traveler.email) 	
    expect(english_traveler.profile_hash[:first_name]).to eq(english_traveler.first_name) 	
    expect(english_traveler.profile_hash[:last_name]).to eq(english_traveler.last_name)
    expect(english_traveler.profile_hash[:lang]).to eq(english_traveler.preferred_locale.name) 	
  end

  it 'returns the preferred trip types array' do
  	expect(english_traveler.preferred_trip_types).to eq(['transit', 'unicycle'])
  end

  it 'returns the eligibilities_hash' do
  	expect(english_traveler.eligibilities_hash.count).to eq(2)
  	expect(english_traveler.eligibilities_hash.first[:code]).to eq('over_65')
  	expect(english_traveler.eligibilities_hash.first[:name]).to eq('missing key over_65_name')
  	expect(english_traveler.eligibilities_hash.first[:note]).to eq('missing key over_65_note')
  end

  it 'returns the accommodations_hash' do
  	expect(english_traveler.accommodations_hash.count).to eq(2)
  	expect(english_traveler.accommodations_hash.first[:code]).to eq('wheelchair')
  	expect(english_traveler.accommodations_hash.first[:name]).to eq('missing key wheelchair_name')
  	expect(english_traveler.accommodations_hash.first[:note]).to eq('missing key wheelchair_note')
  end

  it 'updates basic attributes' do 
    params = {first_name: "George", last_name: "Burdell", email: "gpburdell@email.com", lang: "en", preferred_trip_types: ['recumbent_bicycle', 'roller_blades']}
    traveler.update_basic_attributes params
    expect(traveler.email).to eq('gpburdell@email.com')
    expect(traveler.first_name).to eq('George')
    expect(traveler.last_name).to eq('Burdell')
    expect(traveler.locale).to eq(Locale.find_by(name: "en"))
    expect(traveler.preferred_trip_types).to eq(['recumbent_bicycle', 'roller_blades'])
  end

  it 'updates eligibilities' do 
    params = {over_65: false, veteran: true}
    traveler.update_eligibilities params
    expect(traveler.eligibilities.count).to eq(2)
    veteran = Eligibility.find_by(code: "veteran")
    over_65 = Eligibility.find_by(code: "over_65")
    expect(traveler.user_eligibilities.find_by(eligibility: veteran).value).to eq(true)
    expect(traveler.user_eligibilities.find_by(eligibility: over_65).value).to eq(false)
  end

  it 'updates accommodations' do 
    params = {wheelchair: true, jacuzzi: false}
    traveler.update_accommodations params
    expect(traveler.accommodations.count).to eq(1)
    expect(traveler.accommodations.where(code: "wheelchair").count).to eq(1)
    expect(traveler.accommodations.where(code: "jacuzzi").count).to eq(0)
  end

end
