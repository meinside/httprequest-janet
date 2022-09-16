(declare-project
  :name "httprequest"
  :description ```HTTP Request Helper Library for Janet ```
  :version "0.0.2"
  :dependencies ["https://github.com/andrewchambers/janet-uri"
                 "https://github.com/joy-framework/http"
                 "https://github.com/janet-lang/spork"])

(declare-source
  :prefix "httprequest"
  :source ["src/init.janet"])
