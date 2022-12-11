# The whole simulated program
class Wireland::Circuit
  alias Point = NamedTuple(x: Int32, y: Int32)
  alias WC = Wireland::Component
  alias R = Raylib


  def self.load(filename, pallette : Wireland::Pallette = Wireland::Pallette::DEFAULT) : Array(WC)
    pallette.load_into_components

    image = R.load_image(filename)
    raise "No file - #{filename}" if image.width <= 0

    # List of pixels that are in our pallette
    component_points = {} of WC.class => Point
    image.width.times do |x|
      image.height.times do |y|
        color = R.get_image_color(image, x, y)
        if component = WC.all.find {|c| c.color == color}
        component_points[component] = {x: x, y: y}
        end
      end
    end

    diags = [
      {x: -1, y: -1},
      {x: -1, y: 1},
      {x: 1, y: -1},
      {x: 1, y: 1},
    ]

    adjacent = [
      {x: 0, y: -1},
      {x: -1, y: 0},
      {x: 0, y: 1},
      {x: 1, y: 0},
    ]

    components = [] of WC

    # Go through each component point
    component_points.each do |component_class, xy|
      # Does this component not connect itself as a shape? Things like Crossing, Tunnel.
      if !component_class.allow_adjacent? && !component_class.allow_diags?
        component = component_class.new
        component.shape = [xy]
        components << component
      else
        component = component_class.new
        component.shape = _get_component_shape(component_points, component_class, xy, {x: image.width, y: image.height})
        components << component

        if rs = component.as?(WC::RelaySwitch)
          relay_switches << rs
        elsif p = component.as?(Wireland::Pole)
          poles << p
        elsif no = component.as?(WC::NotOut)
          not_out << no
        elsif p = component.as?(WC::Pause)
          pauses << p
        end
      end
    end

    # Connect each of the components
    components.each do |component|
      # Select only components that are valid output destinations
      valid_components = components.select {|c| component.output_whitelist.includes? c.class}
      valid_components.each do |vc|
        # Is this component a neighbor for any point on our main component
        is_vc_neighbors = component.shape.any? do |c_point|
          vc.shape.any? do |vc_point|
            adjacent.any? { |a_p| { x: c_point[:x] + a_p[:x], x: c_point[:y] + a_p[:y]} == vc_point } 
          end
        end

         connects << vc.id if is_vc_neighbors
      end
    end

    # Crossing
    components.select(&.is_a?(WC::Crossing)).map(&.as(WC::Crossing)).each(&.setup)
    # Tunnel
    components.select(&.is_a?(WC::Tunnel)).map(&.as(WC::Tunnel)).each(&.setup)
    # Pause
    # Relay Switch
    # Relay NO
    # Relay NC


    components
  end

  private def self._get_component_shape(component_points : Hash(WC.class, Point), com : WC.class, xy : Point, max : Point) : Array(Point)
    shape = [] of Point
    neighbors = [xy]
    shape.concat neighbors

    until neighbors.empty?
      shape.concat(
        neighbors = neighbors.map do |n|
          _get_neighbors(component_points, com, n, max)
        end.flatten.uniq!.reject do |n|
          shape.includes? n
        end
      )
    end
    shape
  end

  private def self._get_neighbors(component_points : Hash(WC.class, Point), com : WC.class, xy : Point, max : Point) : Array(Point)
    neighbors = _make_neighborhood(com, xy, max)

    # If the neighbors are empty return nothing
    return [] of Point if neighbors.empty?

    component_points[com].select {|p| neighbors.includes? p}
  end

  private def self._make_neighborhood(xy : Point, com : WC.class, max : Point)
    r_points = [] of Point
    r_points += diags if com.allow_diags?
    r_points += adjacent if com.allow_adjacent?

    r_points.map {|r_p| {x: xy[:x] + r_p[:x], y: xy[:y] + r_p[:y]}}.reject do |a_p|
      a_p[:x] < 0 ||
      a_p[:y] < 0 ||
      a_p[:x] >= max[:x] ||
      a_p[:y] >= max[:y]
    end
  end

  property pallete : Wireland::Pallette = Wireland::Pallette::DEFAULT

  property components = [] of WC
  property cycles = 0_u128
  property relay_switches = [] of WC::RelaySwitch
  property poles = [] of Wireland::RelayPole

  property not_outs = [] of WC::NotOut
  property pauses = [] of WC::Pause

  def initialize(filename : String, @pallette : Wireland::Pallette = Wireland::Pallette::DEFAULT)
    # Read file in using load
    # Set palette colors
  end

  def initialize(@image : R::Image, @pallette : Wireland::Pallette = Wireland::Pallette::DEFAULT)
    components = load(image, pallette)
  end

  def [](index)
    components[index]
  end

  def []?(index)
    components[index]?
  end

  def tick
    @cycles += 1
  end

  def reset
    @cycles = 0
    @components.values.each(&.reset)
  end

  def turn_off_relay_poles
  end
end
