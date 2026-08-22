module Discogs
  Error = Class.new(StandardError)
  NotConfigured = Class.new(Error)
  Unauthorized = Class.new(Error)
  NotFound = Class.new(Error)
  RateLimited = Class.new(Error)
end
