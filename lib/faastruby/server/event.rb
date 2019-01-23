module FaaStRuby
  class Event
    attr_accessor :body, :query_params, :headers, :context
    def initialize(body:, query_params:, headers:, context:)
      @body = body
      @query_params = query_params
      @headers = headers
      @context = context
    end
  end
end