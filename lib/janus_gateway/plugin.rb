module JanusGateway
  class Plugin

    # @return [String]
    def self.plugin_name
      raise("`#{__method__}` is not implemented for `#{self.class.name}`")
    end
  end
end