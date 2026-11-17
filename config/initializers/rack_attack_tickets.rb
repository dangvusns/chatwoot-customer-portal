# Company fork: throttle the public ticket portal (loads after rack_attack.rb)
Rack::Attack.throttle('tickets/submit/ip', limit: 10, period: 10.minutes) do |req|
  req.ip if req.post? && req.path == '/support'
end

Rack::Attack.throttle('tickets/reply/ip', limit: 30, period: 10.minutes) do |req|
  req.ip if req.post? && req.path.match?(%r{\A/tickets/[^/]+/replies\z})
end

Rack::Attack.throttle('premium-support/auth/ip', limit: 10, period: 10.minutes) do |req|
  req.ip if req.post? && %w[/premium-support/login /premium-support/password].include?(req.path)
end
