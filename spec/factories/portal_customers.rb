FactoryBot.define do
  factory :portal_customer do
    account
    contact { association(:contact, :with_email, account: account) }
    locale { 'en' }
    status { :invited }
    session_version { 0 }

    trait :active do
      status { :active }
      password { 'Customer test password 123!' }
      password_confirmation { password }
    end
  end
end
