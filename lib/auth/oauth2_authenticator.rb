# frozen_string_literal: true

class Auth::OAuth2Authenticator < Auth::Authenticator

  def name
    @name
  end

  # only option at the moment is :trusted
  def initialize(name, opts = {})
    Discourse.deprecate("OAuth2Authenticator is deprecated. Use `ManagedAuthenticator` and `UserAssociatedAccount` instead. For more information, see https://meta.discourse.org/t/106695", drop_from: '2.9.0')
    @name = name
    @opts = opts
  end

  def after_authenticate(auth_token)

    result = Auth::Result.new

    oauth2_provider = auth_token[:provider]
    oauth2_uid = auth_token[:uid]
    data = auth_token[:info]
    result.email = email = data[:email]
    result.name = name = data[:name]

    oauth2_user_info = Oauth2UserInfo.find_by(uid: oauth2_uid, provider: oauth2_provider)

    if !oauth2_user_info && @opts[:trusted] && user = User.find_by_email(email)
      oauth2_user_info = Oauth2UserInfo.create(uid: oauth2_uid,
                                               provider: oauth2_provider,
                                               name: name,
                                               email: email,
                                               user: user)
    end

    result.user = oauth2_user_info.try(:user)
    result.email_valid = @opts[:trusted]

    result.extra_data = {
      uid: oauth2_uid,
      provider: oauth2_provider
    }

    result
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    association = Oauth2UserInfo.find_or_initialize_by(provider: data[:provider], uid: data[:uid])
    association.user = user
    association.email = auth[:email]
    association.save!
  end

  def description_for_user(user)
    info = Oauth2UserInfo.find_by(user_id: user.id, provider: @name)
    info&.email || info&.name || info&.uid || ""
  end
end
