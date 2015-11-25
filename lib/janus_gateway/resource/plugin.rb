module JanusGateway

  class Resource::Plugin < Resource

    # @param [JanusGateway::Resource::Session] session
    # @param [String] name
    def initialize(session, name)
      @session = session
      @name = name

      super()
    end

    # @return [String, NilClass]
    def name
      @name
    end

    # @return [Concurrent::Promise]
    def create
      promise = Concurrent::Promise.new

      janus_client.send_transaction(
        {
          :janus => 'attach',
          :plugin => name,
          :session_id => @session.id
        }
      ).then do |*args|
        _on_created(*args)

        promise.set(self)
        promise.execute
      end.rescue do |error|
        promise.fail(error).execute
      end

      promise
    end

    def destroy
      promise = Concurrent::Promise.new

      _on_destroyed

      promise.set(self)
      promise.execute

      promise
    end

    # @return [JanusGateway::Resource::Session]
    def session
      @session
    end

    # @return [JanusGateway::Client]
    def janus_client
      @session.janus_client
    end

    private

    def _on_created(data)
      @id = data['data']['id']

      session.on :destroy do |data|
        destroy
      end

      self.emit :create, @id
    end

    def _on_destroyed
      self.emit :destroy, @id
    end

  end
end
