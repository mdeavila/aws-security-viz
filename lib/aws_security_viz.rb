require_relative 'ec2/security_groups'
require_relative 'provider/json'
require_relative 'provider/ec2'
require_relative 'renderer/graphviz'
require_relative 'renderer/json'
require_relative 'graph'
require_relative 'exclusions'
require_relative 'debug_graph'
require_relative 'color_picker'
require_relative 'aws_config'

class VisualizeAws
  def initialize(config, options={})
    # These are the command-line options
    @options = options

    # This is the config file (who's filename may have been passed in via the command-line)
    @config = config

#    log("config file notes: #{config.inspect}")
    
    provider = options[:source_file].nil? ? Ec2Provider.new(options) : JsonProvider.new(options)
    @security_groups = SecurityGroups.new(provider, config)
  end

  def unleash(output_file)
    g = build
    if output_file.end_with?('json')
      g.output(Renderer::Json.new(output_file, @config))
      FileUtils.copy(File.expand_path('../export/html/view.html', __FILE__),
                     File.expand_path('../view.html', output_file))
    else
      g.output(Renderer::GraphViz.new(output_file, @config))
    end
  end

  def build
    g = @config.obfuscate? ? DebugGraph.new(@config) : Graph.new(@config)
    @security_groups.each_with_index { |group, index|
      picker = ColorPicker.new(@options[:color])

      # This is gross, but I'm not sure of a prettier way to do it. 
      # I expect I'll just create an addNote() function to the group
      notes = @config.notes(group.group_id)
      log("notes for #{group.group_id}: #{notes}")
      if notes
        labels = group.labels.merge!({"notes"=> notes})
      else
        labels = group.labels
      end  

      g.add_node(group.name, labels)
      group.traffic.each { |traffic|
        if traffic.ingress
          g.add_edge(traffic.from, traffic.to, :color => picker.color(index, traffic.ingress), :label => traffic.port_range)
        else
          g.add_edge(traffic.to, traffic.from, :color => picker.color(index, traffic.ingress), :label => traffic.port_range)
        end
      }
    }
    g
  end

  def log(msg)
    puts msg if @config.debug?
  end      

end

