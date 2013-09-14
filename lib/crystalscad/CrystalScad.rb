#    This file is part of CrystalScad.
#
#    CrystalScad is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    CrystalScad is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with CrystalScad.  If not, see <http://www.gnu.org/licenses/>.

require "rubygems"
require "rubyscad"

module CrystalScad 
	include CrystalScad::BillOfMaterial
	include CrystalScad::Hardware
	include CrystalScad::LinearBearing
	
	
	class ScadObject
		attr_accessor :args		
    attr_accessor :transformations
		def initialize(*args)
			@transformations = []
			@args = args.flatten
			if @args[0].kind_of? Hash
				@args = @args[0]			
			end		
		end		


		def walk_tree
			res = ""			
			
			@transformations.reverse.each{|trans|
				res += trans.walk_tree 
			}
			res += self.to_rubyscad.to_s+ "\n"
			res
		end
		alias :scad_output :walk_tree		
		
		def to_rubyscad
			""
		end
	
	end

	class Primitive < ScadObject

		def rotate(args)
		  # always make sure we have a z parameter; otherwise RubyScad will produce a 2-dimensional output
		  # which can result in openscad weirdness
		  if args[:z] == nil
		    args[:z] = 0
		  end
			@transformations << Rotate.new(args)	
			self
		end

		def translate(args)
			@transformations << Translate.new(args)		
			self			
		end
		
		def union(args)
			@transformations << Union.new(args)		
			self			
		end

		def mirror(args)
			@transformations << Mirror.new(args)		
			self			
		end

  end

	class TransformedObject < Primitive
		attr_accessor :scad
		def initialize(string)
			@scad = string
			@transformations = []
		end		
	
		def to_rubyscad
			return @scad		
		end
		alias :output :walk_tree
	
	end

	class Transformation < ScadObject
	end

	class Rotate < Transformation
		def to_rubyscad
			return RubyScadBridge.new.rotate(@args)		
		end	
	end

 	class Translate < Transformation
		def to_rubyscad
			return RubyScadBridge.new.translate(@args)		
		end	
	end
	
 	class Mirror < Transformation
		def to_rubyscad
			return RubyScadBridge.new.mirror(@args)		
		end	
	end
	
	
	class Cylinder < Primitive
		def to_rubyscad	
			return RubyScadBridge.new.cylinder(@args)		
		end	
	end

	def cylinder(args)
		Cylinder.new(args)		
	end
	
	class Cube < Primitive
	  attr_accessor :x,:y,:z
	  
	  def initialize(*args)
	    super(args)
	    @x,@y,@z = args[0][:size].map{|l| l.to_f}
    
	  end
	
		def to_rubyscad
			return RubyScadBridge.new.cube(@args)		
		end	
	end

	def cube(args)
		if args.kind_of? Array
			args = {size:args}
		end	
		Cube.new(args)	
	end

	#	2d primitives
	class Square < Primitive
		def to_rubyscad
			return RubyScadBridge.new.square(@args)		
		end			
	end

	def square(args)
		Square.new(args)	
	end

	class Circle < Primitive
		def to_rubyscad
			return RubyScadBridge.new.circle(@args)		
		end			
	end

	def circle(args)
		Circle.new(args)	
	end

	class Polygon < Primitive
		def to_rubyscad
			return RubyScadBridge.new.polygon(@args)		
		end			
	end

	def polygon(args)
		Polygon.new(args)	
	end

	
	class RubyScadBridge
		include RubyScad

		def raw_output(str)
			return str
		end

		def format_output(str)
			return str
		end

		def format_block(output_str)
			return output_str
		end
	end

  	
	def csg_operation(operation, code1, code2)
		ret = "#{operation}(){"
		ret +=code1
		ret +=code2
		ret +="}"
		return TransformedObject.new(ret)
	end

	def +(args)	
		return args	 if self == nil		
		csg_operation("union",self.walk_tree,args.walk_tree)
	end

	def -(args)
		return args	 if self == nil		
		csg_operation("difference",self.walk_tree,args.walk_tree)		
	end
	
	def *(args)
		return args	 if self == nil		
		csg_operation("intersection",self.walk_tree,args.walk_tree)		
	end
	
	def hull(part1,part2)
	  csg_operation("hull",part1.walk_tree,part2.walk_tree)		  
	end
	
	# Fixme: currently just accepting named colors
	def color(args)
	  ret = "color(\"#{args}\"){"
		ret +=self.walk_tree
		ret +="}"
		return TransformedObject.new(ret)		
	end

	def linear_extrude(args)
		args = args.collect { |k, v| "#{k} = #{v}" }.join(', ')
		ret = "linear_extrude(#{args}){"
		ret +=self.walk_tree
		ret +="}"
		return TransformedObject.new(ret)				
	end
	

	#	Stacks parts along the Z axis
	# works on all Assemblies that have a @height definition
	def stack(args={}, *parts)
		args[:method] ||= "show"
		args[:additional_spacing] ||= 0
		@assembly = nil		
		z = 0
		parts.each do |part|
			@assembly += (part.send args[:method]).translate(z:z)
			z+= part.height	+ args[:additional_spacing]
		end
		@assembly
	end

end


