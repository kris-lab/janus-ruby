require 'eventmachine'
require 'faye/websocket'

module JanusGateway

  class Transport::WebSocket < Transport

    attr_reader :transaction_queue

    # @param [String] url
    # @param [String] protocol
    def initialize(url, protocol = 'janus-protocol')
      @client = nil
      @transaction_queue = Hash.new

      super
    end

    # @return [Faye::WebSocket::Client]
    def connect
      EventMachine.run do

        EM.error_handler { |e| raise(e) }

        @client = _create_client(@url, @protocol)

        _self = self

        @client.on :open do
          _self.emit :open
        end

        @client.on :message do |event|
          data = JSON.parse(event.data)

          transaction_list = _self.transaction_queue.clone

          transaction_id = data['transaction']
          unless transaction_id.nil?
            promise = transaction_list[transaction_id]
            unless promise.nil?
              if ['success', 'ack'].include?(data['janus'])
                promise.set(data)
                promise.execute
              else
                error_data = data['error']
                error = JanusGateway::Error.new(error_data['code'], error_data['reason'])
                promise.fail(error).execute
              end
            end
          end

          _self.emit :message, data
        end

        @client.on :close do
          _self.emit :close
        end
      end

      @client
    end

    # @param [String, Numeric, Array] data
    def send(data)
      @client.send(data)
    end

    # @param [Hash] data
    # @return [Concurrent::Promise]
    def send_transaction(data)
      promise = Concurrent::Promise.new
      transaction = transaction_id_new

      data[:transaction] = transaction
      @client.send(JSON.generate(data))

      @transaction_queue[transaction] = promise

      Thread.new do
        sleep(_transaction_timeout)
        error = JanusGateway::Error.new(0, "Transaction id `#{transaction}` has failed due to timeout!")
        promise.fail(error).execute
        @transaction_queue.remove(transaction)
      end

      promise
    end

    def disconnect
      @client.close
      EventMachine.stop
    end

    # @return [Faye::WebSocket::API::CONNECTING, Faye::WebSocket::API::OPEN, Faye::WebSocket::API::CLOSING, Faye::WebSocket::API::CLOSED]
    def ready_state
      @client.ready_state unless @client.nil?
    end

    # @return [TrueClass, FalseClass]
    def is_connected?
      (@client.nil? == false) and (@client.ready_state == Faye::WebSocket::API::OPEN)
    end

    # @return [Faye::WebSocket::Client]
    def client
      @client
    end

    private

    # @return [Faye::WebSocket::Client]
    def _create_client(url, protocol)
      Faye::WebSocket::Client.new(url, protocol)
    end

    # @return [Float, Integer]
    def _transaction_timeout
      30
    end

  end

end