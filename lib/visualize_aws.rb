require 'aws-sdk'
require 'graphviz'
require_relative 'groups.rb'
require 'set'

class VisualizeAws
  def initialize(access_key, secret_key)
    AWS.config(access_key_id: access_key, secret_access_key: secret_key)
    @ec2 = AWS.ec2
  end

  def parse
    groups = @ec2.security_groups.to_a
    g = GraphViz::new( "G" )
    nodes = groups.collect {|group| group.name}
    nodes.each {|n| g.add_node(n)}
    GroupIngress.new(groups).each { |from, to, port_range| 
      g.add_edge( from, to, :color => "blue", :style => "bold", :label => port_range )
    }
    CidrIngress.new(groups, CidrGroupMapping.new).each { |from, to, port_range| 
      g.add_edge( from, to, :color => "green", :style => "bold", :label => port_range )
    }
    g
  end

  def unleash(output_file)
    g = parse
    extension = File.extname(output_file)
    g.output( extension[1..-1].to_sym => output_file )
  end

  class GroupIngress
    def initialize(groups)
      @groups = groups
    end
    def each
      @groups.each do |group|
        ingress = group.ingress_ip_permissions.to_a
        ingress.each do |ig|
          ig.groups.each do |igrp|
            igrp_name = igrp.name rescue igrp.id
            yield igrp_name, group.name, ig.port_range.minmax.uniq.join(" - ")
          end
        end
      end
    end
  end

  class CidrIngress
    def initialize(groups, filter)
      @groups = groups
      @filter = filter
    end

    def each
      @groups.each do |group|
        ingress = group.ingress_ip_permissions.to_a
        ingress.each do |ig|
          ig.ip_ranges.each { |ip_range|
             yield group.name, ip_range, ig.port_range.minmax.uniq.join(" - ")
          }
        end
      end
    end
  end

  class CidrGroupMapping 
    def initialize user_groups = USER_GROUPS
      @seen = Set.new
      @user_groups = user_groups
    end
    def map args, &block
      mapped_args = [mapping(args[0])] + args[1..-1]
      return if @seen.include? mapped_args 
      @seen.add(mapped_args)
      block.call(mapped_args)
    end 
    def mapping(val)
      @user_groups[val]? @user_groups[val] : val
    end
  end
end

if __FILE__ == $0
  access_key = ARGV[0]
  secret_key = ARGV[1]
  output_file = ARGV[2] || "aws-security-viz.png"
  VisualizeAws.new(access_key, secret_key).unleash(output_file)
end
