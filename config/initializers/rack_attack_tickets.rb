# Company fork: throttle the customer portal sign-in (loads after rack_attack.rb)
Rack::Attack.throttle('premium-support/auth/ip', limit: 10, period: 10.minutes) do |req|
  req.ip if req.post? && %w[/premium-support/login /premium-support/password].include?(req.path)
end
