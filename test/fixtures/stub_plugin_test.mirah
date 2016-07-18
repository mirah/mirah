package org.foo

 /**
    java doc
 */
class AOne
  CONST = 1
  def call:void;end

  def call(a:int, b:String):int
    @a = 1
  end

  def call(a:int[], b:String):Integer
    1
  end
 /**
    static method
 */
  def self.call(a:int[]):void
  end

 /**
    @throws RuntimeException
 */
  def call(a:int, b:int=1):void
  end

 /**
    constructor
 */
  def initialize
  end

  class << self
    def initialize
      @@test = "x"
    end
 /**
    static method
 */
    def method
    end
  end
end

interface AOneX
end