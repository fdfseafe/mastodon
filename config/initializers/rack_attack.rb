# frozen_string_literal: true

class Rack::Attack
  # Always allow requests from localhost
  # (blocklist & throttles are skipped)
  Rack::Attack.safelist('allow from localhost') do |req|
    # Requests are allowed if the return value is truthy
    '127.0.0.1' == req.ip || '::1' == req.ip
  end

  # Rate limits for the API
  throttle('api', limit: 3_000_000, period: 5.minutes) do |req|
    req.ip if req.path =~ /\A\/api\/v/
  end

  throttle('toot', limit: 150, period: 5.minutes) do |req|
    req.env['HTTP_AUTHORIZATION'].split(' ').last if req.path == '/api/v1/statuses' && req.post?
  end

  # Rate limit logins
  throttle('login', limit: 500, period: 5.minutes) do |req|
    req.ip if req.path == '/auth/sign_in' && req.post?
  end

  # Rate limit sign-ups
  throttle('register', limit: 50, period: 5.minutes) do |req|
    req.ip if req.path == '/auth' && req.post?
  end

  # Rate limit forgotten passwords
  throttle('reminder', limit: 5, period: 5.minutes) do |req|
    req.ip if req.path == '/auth/password' && req.post?
  end

  self.throttled_response = lambda do |env|
    now        = Time.now.utc
    match_data = env['rack.attack.match_data']

    headers = {
      'X-RateLimit-Limit'     => match_data[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset'     => (now + (match_data[:period] - now.to_i % match_data[:period])).iso8601(6),
    }

    [429, headers, [{ error: I18n.t('errors.429') }.to_json]]
  end
end
