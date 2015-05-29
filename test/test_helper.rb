ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start

  # for coverage we need to load all ruby files
  src_location = File.expand_path("../../src", __FILE__)
  # note that clients/ are excluded because they run too eagerly by design
  Dir["#{src_location}/{include,modules}/**/*.rb"].each do |f|
    require_relative f
  end
end
