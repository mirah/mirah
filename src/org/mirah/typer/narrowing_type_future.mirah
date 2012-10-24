package org.mirah.typer

import mirah.lang.ast.*

class NarrowingTypeFuture < BaseTypeFuture
  def initialize(position:Position, wide:ResolvedType, narrow:ResolvedType)
    super(position)
    @wide = wide
    @narrow = narrow
    resolved(wide)
  end

  def narrow
    resolved(@narrow)
  end

  def widen
    resolved(@wide)
  end

  def narrow_future
    @narrow_future ||= BaseTypeFuture.new(self.position).resolved(@narrow)
  end

  def wide_future
    @wide_future ||= BaseTypeFuture.new(self.position).resolved(@wide)
  end
end
