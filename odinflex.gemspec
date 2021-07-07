Gem::Specification.new do |s|
  s.name        = "odinflex"
  s.version     = "1.0.0"
  s.summary     = "Parse AR or Mach-O files"
  s.description = "Do you need to parse an AR file or a Mach-O file? If so, then this is the library for you!"
  s.authors     = ["Aaron Patterson"]
  s.email       = "tenderlove@ruby-lang.org"
  s.files       = `git ls-files -z`.split("\x0")
  s.test_files  = s.files.grep(%r{^test/})
  s.homepage    = "https://github.com/tenderlove/odinflex"
  s.license     = "Apache-2.0"
end
