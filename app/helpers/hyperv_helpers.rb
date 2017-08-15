module HypervHelpers
  def hyperv_switches(compute)
    compute.switches.map do |sw|
      [sw.name, sw.name]
    end
  end
end
