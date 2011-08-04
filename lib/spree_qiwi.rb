require 'spree_core'
require 'array_ext'
require 'nokogiri_ext'

module SpreeQiwi
  class Engine < Rails::Engine

    config.autoload_paths += %W(#{config.root}/lib)

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.env.production? ? require(c) : load(c)
      end
      Gateway::Qiwi.register
    end

    config.to_prepare &method(:activate).to_proc
  end
end
