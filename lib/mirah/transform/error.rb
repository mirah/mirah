module Mirah
  module Transform
    class Error < Mirah::MirahError
      attr_reader :position
      def initialize(msg, position, cause=nil)
        position = position.position if position.respond_to? :position
        super(msg, position)
        self.cause = cause
      end
    end
  end
  TransformError = Transform::Error
end