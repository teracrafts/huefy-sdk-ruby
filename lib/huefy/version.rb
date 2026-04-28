# frozen_string_literal: true

module Huefy
  VERSION = "1.0.0"
end

module Teracrafts
  Huefy = ::Huefy unless const_defined?(:Huefy, false)
end
