require 'graphviz'

module Renderer
  class GraphViz
    def initialize(file_name, config)
      @g = ::GraphViz::new('G', :type => 'strict digraph') { |g|
        g[:overlap] = :false
        g[:splines] = :true
        g[:sep] = 1
        g[:concentrate] = :true
      }
      @file_name = file_name
      @config = config
    end

    def add_node(name, labels={})
#      puts "adding to renderer name #{name} with labels #{labels}"
      node = @g.add_node(name)

      rows = ""
      if !labels.nil? && !labels.empty?
        labels.each_pair { |key, value| rows+="<tr><td>#{key}</td><td>#{value}</td></tr>" }
      end

#      notes = @config.notes(name)
#      if !notes.nil? && !notes.empty?
#        rows += "<tr><td colspan=\"2\">#{notes}</td></tr>"
#      end

      if !rows.empty?
        label = "<<table>#{rows}</table>>"
          
        node.set { |_n|
          _n.label = label
        }
      end
    end

    def add_edge(from, to, opts)
      log(opts)
      @g.add_edge(from, to, ({style: 'bold'}).merge(opts))
    end

    def output
      extension = File.extname(@file_name)
      opts = {extension[1..-1].to_sym => @file_name, :use => @config.format}
      @g.output(opts)
    end

    def log(msg)
      puts msg if @config.debug?
    end    
  end
end
