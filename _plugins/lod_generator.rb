#
# This a modified version of data_page_generator.rb by Adolfo Villafiorita.
#
# Generate pages from individual records in yml files
# (c) 2014-2016 Adolfo Villafiorita
#
# Additions and modifications (c) 2016 Tim Sherratt (@wragge)
# Distributed under the conditions of the MIT License


module Jekyll

    module LODBook
        require 'json/ld'
        # Preload to save time
        ctx = JSON::LD::Context.new().parse('http://schema.org/')
        JSON::LD::Context.add_preloaded('http://schema.org/', ctx)

        def get_context(lod_source, data)
            # Set defaults
            if lod_source.has_key?("context")
                context = lod_source["context"]
            else
                context = "http://schema.org/"
            end
            # Overide with context on data
            if data.kind_of?(Hash)
                if data.has_key?("context")
                    context = data["context"]
                elsif data.has_key?("@context")
                    context = data["@context"]
                end
            end
            return context
        end

        def get_graph(lod_source, data)
            context = get_context(lod_source, data)
            if data.kind_of?(Hash)
                if data.has_key?("graph")
                    graph = data["graph"]
                elsif data.has_key?("@graph")
                    # if JSON-LD, compact the data
                    if !context.kind_of?(String)
                        str_context = JSON.parse(context.to_json)
                    else
                        str_context = context
                    end
                    lod = JSON.parse(data.to_json)
                    # Not sure if this is really necessary, but it ensures a standard format
                    expanded = JSON::LD::API.expand(lod)
                    compact = JSON::LD::API.compact(expanded, str_context)
                    graph = compact["@graph"]
                end
            else
                graph = data
            end
            return graph
        end

        def parse_data(lod_source, data)
            puts lod_source
            context = get_context(lod_source, data)
            graph = self.get_graph(lod_source, data)
            return {context: context, graph: graph}
        end

        def self.format_url(context, name, collection)
            @site_url = context.registers[:site].config['url']
            @base_url = context.registers[:site].config['baseurl']
            "#{@site_url}#{@base_url}/#{collection}/#{Utils.slugify(name)}/"
        end

        class GraphMaker

            # Class for assembling graphs

            require 'json/ld'
            include LODBook
            attr_reader :graph

            def initialize(site)
                @site_url = site.config['url']
                @base_url = site.config["baseurl"]
                lod_source = site.config["lod_source"]
                data_source = site.data[lod_source["data"]]
                @types = site.config['data_types']
                @data = get_graph(lod_source, data_source)
                @graph = []
            end

            def process_properties(properties)
                # puts properties
                @graph << process_hash(properties)
            end

            def process_array(value)
                properties = []
                value.each do |prop|
                    if prop.kind_of?(Hash)
                        properties.push(process_hash(prop))
                    else
                        properties.push(prop)
                    end
                end
                return properties
            end

            def process_hash(value)
                properties = {}
                value.each do |key, prop|
                    puts key
                    if key == "image"
                        if prop.kind_of?(Hash)
                            if prop.has_key?("name")
                                image_record = get_record(prop["name"])
                                if image_record
                                    image = {}
                                    image["@id"] = create_id(image_record["name"], @types[image_record["type"]]["collection"])
                                    image["@type"] = @types[image_record["type"]]["type"]
                                    image["name"] = image_record["name"]
                                    image["image"] = image_record["image"]
                                    properties["image"] = image
                                else
                                    puts "\e[31mImage not found: #{prop["name"]}\e[0m"
                                end
                            else
                                properties[key] = prop
                            end
                        else
                            properties[key] = prop
                        end
                    elsif prop.kind_of?(Hash)
                        properties[key] = process_hash(prop)
                    elsif prop.kind_of?(Array)
                        properties[key] = process_array(prop)
                    else
                        if key == "name"
                            properties["name"] = prop
                            if !value.has_key?("id")
                                record = get_record(prop)
                                if record
                                    properties["@id"] = create_id(prop, @types[record["type"]]["collection"])
                                end
                            end
                            if !value.has_key?("type")
                                record = get_record(prop)
                                if record
                                    properties["@type"] = @types[record["type"]]["type"]
                                end
                            end
                        elsif key == 'type'
                            if @types.has_key?(prop)
                                properties["@type"] = @types[prop]["type"]
                            else
                                properties["@type"] = prop
                            end
                        elsif key == 'id'
                                properties["@id"] = prop
                        elsif key == 'image'
                            image_record = get_record(prop)
                            # puts image_record
                            if image_record
                                image = {}
                                image["@id"] = create_id(image_record["name"], @types[image_record["type"]]["collection"])
                                image["@type"] = @types[image_record["type"]]["type"]
                                image["name"] = image_record["name"]
                                image["image"] = image_record["image"]
                                properties["image"] = image
                            else
                                properties[key] = prop
                            end
                        else
                            properties[key] = prop
                        end
                    end
                end
                return properties
            end

            def get_record(prop)
                @data.find { |r| r["name"] == prop }
            end

            def create_id(name, collection)
                "#{@site_url}#{@base_url}/#{collection}/#{Utils.slugify(name)}/"
            end
        end

        class ContentPage

            # Class for text/narrative pages.

            require 'nokogiri'
            include LODBook

            attr_reader :html

            def initialize(document)
                @site = document.site
                @site_url = @site.config['url']
                @base_url = @site.config["baseurl"]
                @page_url = document.url
                lod_source = @site.config["lod_source"]
                data_source = @site.data[lod_source["data"]]
                @types = @site.config['data_types']
                @collections = @site.config['data_collections']
                @context = get_context(lod_source, data_source)
                @data = get_graph(lod_source, data_source)
                @html = Nokogiri::HTML(document.output)
                @references = {}
            end

            def collect_references()
                @html.css("#text p").each do |para|
                  para.css("a[property=name]").each do |link|
                    @references[link.content] = {'url': link['href'], 'name': link['data-name'], 'collection': link['data-collection']}
                  end
                end
            end

            def number_paras()
                # Add numeric ids to ps and blockquotes, so they can be referenced in JS interface-y stuff.
                @html.css("#text p").each_with_index do |para, index|
                  para['id'] = "para-#{index}"
                end
                @html.css("blockquote").each_with_index do |quote, index|
                  quote['id'] = "quote-#{index}"
                end
            end

            def markup_names()
                labels = @references.keys.sort_by(&:length).reverse!
                @html.css("#text p").each do |para|
                  labels.each do |label|
                    if para.inner_html =~ /\b#{label}\b/
                      name = @references[label][:name]
                      collection = @references[label][:collection]
                      url = @references[label][:url]
                      link = "<a class=\"lod-link\" data-name=\"#{name}\" data-collection=\"#{collection}\" property=\"name\" href=\"#{url}\">#{label}</a>"
                      para.inner_html = para.inner_html.gsub(/(?<!\>)(?<!\=")\b#{label}\b(?!\<)(?!")/, link)
                    end
                  end
                end
            end

            def generate_mentions()
                names = []
                mentions = []
                @references.each do |key, reference|
                    names |= [reference[:name]]
                end
                # puts names
                graph_maker = GraphMaker.new(@site)
                names.each do |name|
                    record = get_record(name)
                    # puts record
                    graph_maker.process_properties(record)
                end
                mentions = {"@id" => "#{@site_url}#{@base_url}#{@page_url}", "@type" => "WebPage", "mentions" => graph_maker.graph}
                lod = {"@context" => @context, "@graph" => mentions}
                # This is needed to parse as LOD
                lod = JSON.parse(lod.to_json)
                # Not sure if this is really necessary, but it ensures a standard format
                expanded = JSON::LD::API.expand(lod)
                compacted = JSON::LD::API.compact(expanded, @context)
                script = Nokogiri::HTML.fragment("<script id=\"page-data\" type=\"application/ld+json\">#{JSON.pretty_generate(compacted)}</script>")
                @html.css("body")[0].add_child(script)
                return compacted
            end

            def get_record(prop)
                @data.find { |r| r["name"] == prop }
            end

            def add_styles()
                css = ""
                @collections.each do |collection|
                    css += ".#{collection['name']} { background-color: #{collection['color']}; border-color: #{collection['color']}}\n"
                    css += ".#{collection['name']}.inverse { background-color: #ffffff; color: #{collection['color']}}\n"
                end
                style = Nokogiri::HTML.fragment("<style type=\"text/css\">#{css}</style>")
                @html.css("head")[0].add_child(style)
            end
        end

        # this class is used to tell Jekyll to generate a page
        class DataPage < Page

        # - site and base are copied from other plugins: to be honest, I am not sure what they do
        # - `dir` is the default output directory
        # - `data` is the data defined in `_data.yml` of the record for which we are generating a page
        # - `template` is the name of the template for generating the page

            def initialize(site, base, dir, data, template)
              @site = site
              name = data["name"]
              filename = Utils.slugify(name)
              puts name
              @dir = dir + "/" + filename + "/"
              @name =  "index.html"
              self.process(@name)
              self.read_yaml(File.join(base, '_layouts'), template + ".html")
              self.data['title'] = name
              self.data['data'] = data
              self.data['contexts'] = []
              # add all the information defined in _data for the current record to the
              # current page (so that we can access it with liquid tags)
              #self.data.merge!(data)
              # puts "Finished"
            end
        end

        class TurtlePage < Page

            # Create an RDF Turtle represntation of the entity and save to a plain text file.

            def initialize(site, base, dir, data, template)
              @site = site
              filename = Utils.slugify(data["@graph"]["name"])
              @dir = dir + "/" + filename + "/"
              @name =  "index.ttl"
              self.process(@name)
              self.read_yaml(File.join(base, '_layouts'), template + ".md")
              # graph = RDF::Graph.new << JSON::LD::API.toRdf(data)
              # self.data["lod"] = graph.dump(:ttl)
            end

        end

        class JSONPage < Page

            # Create an RDF Turtle represntation of the entity and save to a plain text file.

            def initialize(site, base, dir, data, template)
              @site = site
              filename = Utils.slugify(data["name"])
              @dir = dir + "/" + filename + "/"
              @name =  "index.json"
              self.process(@name)
              self.read_yaml(File.join(base, '_layouts'), template + ".md")
              # self.data["lod"] = JSON.pretty_generate(data)
            end

        end

        class JSONContentPage < Page

            # Create JSON-LD represntation of the page and save to a plain text file.

            def initialize(site, base, dir, data, template)
              @site = site
              @dir = dir
              @name =  "index.json"
              self.process(@name)
              self.read_yaml(File.join(base, '_layouts'), template + ".md")
              self.content = JSON.pretty_generate(data)
            end

        end

        class TurtleContentPage < Page

            # Create RDF Turtle represntation of the page and save to a plain text file.

            def initialize(site, base, dir, data, template)
              @site = site
              @dir = dir
              @name =  "index.ttl"
              self.process(@name)
              self.read_yaml(File.join(base, '_layouts'), template + ".md")
              graph = RDF::Graph.new << JSON::LD::API.toRdf(data)
              self.content = graph.dump(:ttl)
            end

        end

        class DataPagesGenerator < Generator

            # Generates pages for each of the entities in the data file.

            safe true
            include LODBook
            require 'rdf/turtle'
            require 'json/ld'

            def generate(site)
              puts "\n\e[34mMAKING ENTITY PAGES:\e[0m"
              lod_source = site.config['lod_source']
              types = site.config['data_types']
              # records is the list of records defined in _data.yml
              # for which we want to generate different pages
              records = nil
              data = site.data[lod_source["data"]]
              parsed_data = parse_data(lod_source, data)
              # puts parsed_data
              records = parsed_data[:graph]
              # puts records
              records.each do |record|
                    type = record["type"]
                    if types[type]
                        collection = types[type]["collection"] || type
                        template = types[type]["template"]
                        page_data = {"data" => {"context" => parsed_data[:context], "graph" => record}}
                        lod = create_graph(site, collection, page_data["data"])
                        expanded_json = JSON::LD::API.expand(lod)
                        compacted_json = JSON::LD::API.compact(expanded_json, parsed_data[:context])
                    # puts page_data
                    # record["data"]["context"] = context

                    # type = types[collection]["type"]
                    # record["context"] = context
                    # record["data"]["@type"] = type
                    # record["data"]["name"] = record["name"]
                        site.pages << DataPage.new(site, site.source, collection, compacted_json, template)
                        site.pages << TurtlePage.new(site, site.source, collection, lod, "text")
                        site.pages << JSONPage.new(site, site.source, collection, compacted_json, "text")
                    else
                        puts "\e[31mType not configured: #{type}\e[0m"
                    end
                end
            end

            def create_graph(site, collection, page_data)
                puts "Making graph"
                site_url = site.config['url']
                base_url = site.config['baseurl']
                data = page_data["graph"]
                context = page_data["context"]
                graph_maker = GraphMaker.new(site)
                graph = graph_maker.process_properties(data)[0]
                # puts graph
                # graph = []
                # graph[0] = process_properties(page_data, data, types)
                filename = Utils.slugify(data["name"])
                page_id = "#{site_url}#{base_url}/#{collection}/#{filename}/"
                if !data.has_key?("@id")
                  graph["@id"] = page_id
                end
                graph["mainEntityofPage"] = "#{page_id}index.html"
                #graph.push({"@id": "#{page_id}index.html", "@type": "http://schema.org/WebPage", "mainEntity": {"@id": page_id}})
                #graph.push
                lod = {"@context": context, "@graph": graph}
                # This is needed to parse as LOD
                lod = JSON.parse(lod.to_json)
                return lod
            end
        end

        class LODLink < Liquid::Block

            # Turns {% lod %} tags in text into HTML linked to entity pages.

            include LODBook

            def initialize(tag_name, name, tokens)
                super
                @name = name.strip
            end

            def render(context)
                @name = super.to_s if @name == ""
                # puts @name
                site_url = context.registers[:site].config['url']
                base_url = context.registers[:site].config['baseurl']
                types = context.registers[:site].config['data_types']
                lod_source = context.registers[:site].config['lod_source']
                data_source = context.registers[:site].data[lod_source['data']]
                data = get_graph(lod_source, data_source)
                record = data.find { |r| r["name"] == @name }
                # puts record
                if record
                    collection = types[record["type"]]["collection"]
                    url = "#{base_url}/#{collection}/#{Utils.slugify(@name)}/"
                    "<a class=\"lod-link\" data-name=\"#{@name}\" data-collection=\"#{collection}\" property=\"name\" href=\"#{url}\">#{super}</a>"
                else
                    puts "\e[31m#{@name} not found\e[0m"
                    super.to_s
                end
            end
        end

        class LODIgnore < Liquid::Block
            # Tag to markup names you don't want to be LOD-ified.

            def initialize(tag_name, params, tokens)
                super
            end

            def render(context)
                "<span class=\"lod-ignore\">#{super}</span>"
            end

        end

        module ImageLink

            # Gets the filename for an image.

            def image_link(image)
                image_file = ""
                if image.kind_of?(Hash)
                    image = image["name"]
                end
                extension = File.extname(image)
                if ['.jpg', '.png', '.gif', '.jpeg'].include?(extension.downcase)
                    image_file = image
                elsif ['.tif', '.tiff', '.pdf'].include?(extension.downcase)
                    puts "\e[31mImage not processed: #{image}\e[0m"
                else
                    lod_source = @context.registers[:site].config['lod_source']
                    data_source = @context.registers[:site].data[lod_source['data']]
                    data = get_graph(lod_source, data_source)
                    record = data.find { |r| r["name"] == image }
                    if record and record["image"]
                        image_file = record["image"]
                    else
                        puts "\e[31mImage not found: #{image}\e[0m"
                    end
                end
                return image_file
            end
        end

        module FormatDate

            # Formats an ISO date as a nice human-readable string

            def format_date(date)
                formatted_date = date.to_s
                parts = date.to_s.split('-')
                if parts.length == 3
                    formatted_date = Date.iso8601(date).strftime("%e %B %Y")
                elsif parts == 2
                    formatted_date = Date.iso8601(date + '-01').strftime("%B %Y")
                end
                return formatted_date
            end

        end

        module LODUrlFilter

            # Formats a complete URI when supplied with a name and collection.
            # Use in lists etc. For example:
            #{% for knows in page.data.knows %}
              #<li><a href="{{ knows.name | lod_url: "", knows.collection }}">{{ knows.name }}</a></li>
            #{% endfor %}

            def lod_url(name, collection)
                site_url = context.registers[:site].config['url']
                base_url = context.registers[:site].config['baseurl']
                "#{site_url}#{base_url}/#{collection}/#{Utils.slugify(name)}/"
            end

        end

        module JSONLDGenerator

            # Creates JSON-LD about an entity for embedding in a page.
            # Converts 'name' & 'collection' pairs to '@id's.
            # Wraps the JSON-LD in script tags.
            #
            # Feed it a page and get back JSON-LD wrapped in a script tag -- eg: {{ page | jsonldify }}
            # TURN THIS INTO A BLOCK TAG?????

            require 'yaml'
            # require 'json'
            require 'json/ld'
            include LODUrlFilter
            include LODBook

            def jsonldify(page)
                site_url = @context.registers[:site].config['url']
                base_url = @context.registers[:site].config['baseurl']
                types = @context.registers[:site].config['data_types']
                lod_source = @context.registers[:site].config['lod_source']
                data_source = @context.registers[:site].data[lod_source['data']]
                data = get_graph(lod_source, data_source)
                page_data = page["data"]["graph"]
                page_context = page["data"]["context"]
                graph_maker = GraphMaker.new(@context.registers[:site])
                graph = graph_maker.process_properties(page_data)
                # graph = []
                # graph[0] = process_properties(page_data, data, types)
                page_url = "#{site_url}#{base_url}#{page["url"]}"
                if !data[0].has_key?("id")
                  graph["@id"] = page_url
                end
                graph.push({"@id": "#{page_url}index.html", "@type": "http://schema.org/WebPage", "mainEntity": {"@id": page_url}})
                lod = {"@context": page_context, "@graph": graph}
                # This is needed to parse as LOD
                lod = JSON.parse(lod.to_json)
                # Not sure if this is really necessary, but it ensures a standard format
                expanded = JSON::LD::API.expand(lod)
                compacted = JSON::LD::API.compact(expanded, page_context)
                return "<script type=\"application/ld+json\">#{JSON.pretty_generate(compacted)}</script>"
            end
        end

        module LODItem

            include LODBook

            def lod_item(item)
                output = ""
                if value.kind_of?(Hash)
                    if value.has_key?("name") and !value.has_key?("id")
                        name = value["name"]
                        record = @@data.find { |r| r["name"] == name }
                        if record
                            collection = @@types[record["type"]]["collection"]
                            output += "<a href=\"#{@@base_url}/#{collection}/#{Utils.slugify(name)}/\">#{name}</a>\n"
                        else
                            output += "#{name}\n"
                        end
                    elsif value.has_key?("id") and value.has_key?("name")
                        output += "<a href=\"#{value["id"]}\">#{value["name"]}</a>\n"
                    elsif value.has_key?("id")
                        output += "<a href=\"#{value["id"]}\">#{value["id"]}</a>\n"
                    end
                else
                    output += "<li>#{value}</li>\n"
                end
                return output
            end
        end

        module LODList

            # Creates a HTML list of values for a particular property

            include LODBook

            def format_item(value)
                output = ""
                if value.kind_of?(Hash)
                    if value.has_key?("name") and !value.has_key?("id")
                        name = value["name"]
                        record = @@data.find { |r| r["name"] == name }
                        if record
                            collection = @@types[record["type"]]["collection"]
                            output += "<li><a href=\"#{@@base_url}/#{collection}/#{Utils.slugify(name)}/\">#{name}</a></li>\n"
                        else
                            output += "<li>#{name}</li>\n"
                        end
                    elsif value.has_key?("id") and value.has_key?("name")
                        output += "<li><a href=\"#{value["id"]}\">#{value["name"]}</a></li>\n"
                    elsif value.has_key?("id")
                        output += "<li><a href=\"#{value["id"]}\">#{value["id"]}</a></li>\n"
                    else
                        value.each do |prop|
                            output += "<li>#{prop[0]}: #{prop[1]}</li>\n"
                        end
                    end
                else
                    if value =~ /^(http|https)/
                        output += "<li><a href=\"#{value}\">#{value}</a></li>\n"
                    else
                        output += "<li>#{value}</li>\n"
                    end
                end
                return output
            end

            def lod_list(list, label)
                @@site_url = @context.registers[:site].config['url']
                @@base_url = @context.registers[:site].config['baseurl']
                lod_source = @context.registers[:site].config['lod_source']
                data_source = @context.registers[:site].data[lod_source['data']]
                @@types = @context.registers[:site].config['data_types']
                @@data = get_graph(lod_source, data_source)
                output = ""
                if label[0..0] =~ /[a-z]/
                    label = label.gsub(/[A-Z]/, ' \0').capitalize
                    #label = label.gsub(/\w+/) {|word| word.capitalize}
                end
                if list
                    output += "<h4 class='title lod-list-title'>#{label}</h4>\n"
                    output += "<ul class='lod-list'>\n"
                    if list.kind_of?(Array)
                        list.each do |value|
                            output += format_item(value)
                        end
                    else
                        output += format_item(list)
                    end
                    output += "</ul>\n"
                end
                return output
            end
        end
    end
end

# pre render documents to tag additional mentions, then add mentions to page data

# So it seems as if the pre/post rendering happens in groups rather than across the site:
# 1. Generators
# 2. documents -- prerender, then postrender
# 3. pages -- prerender, then post render
# So prerender phase of pages will access postrender version of documents...

Jekyll::Hooks.register :pages, :pre_render do |page|
    require 'nokogiri'
    # This runs after the documents have been rendered.
    # So we can get some info from documents about where things are mentioned and insert them in the page data / lod.
    site = page.site
    if page.data.has_key?("data")
        mentioned = []
        contexts = []
        thing_url = "#{site.config["url"]}#{site.config["baseurl"]}#{page.url}"
        collection, id = page.url.split("/")
        site.documents.each do |document|
            if document.data.has_key?("data")
                if document.data["data"]["mentions"].find { |r| r["id"] == thing_url }
                    mentioned << {"id" => document.data["data"]["id"], "name" => document.data["title"], "type" => "WebPage"}
                end
                html = Nokogiri::HTML(document.output)
                html.css('#text  p').each do |para|
                    para_id = para.attr("id").split("-")[1]
                    anchors = []
                    para.css("a[data-name=\"#{page.data["title"]}\"]").each do |link|
                        anchor = link.text
                        anchors |= [anchor]
                    end
                        #puts keyword
                        #para = link.parent
                        #para.text.scan(/.*{50}(?=#{keyword})(?<=#{keyword}).*{50}/)[0].split[0,5].join(' ')
                    anchors.each do |anchor|
                        para.text.scan(/(?:\b\w+\b[\s\.,‘’\:]*){0,5}#{anchor}[\s\.,‘’\:]*(?:\b\w+\b[\s\.,‘’\:]*){0,5}/).each do |match|
                            contexts << {"document_title" => document.data["title"], "document_chapter" => document.data["chapter"], "document_url" => document.url, "para" => para_id, "context" => match}
                        end
                        #@references[link.content] = {'url': link['href'], 'name': link['data-name'], 'collection': link['data-collection']}
                    end
                end
            end
        end
        unless mentioned.empty?
            page.data["data"]["mentionedBy"] = mentioned
        end
        unless contexts.empty?
            page.data["contexts"].concat(contexts)
        end
        # puts page.data
        lod = JSON.parse(page.data["data"].to_json)
        turtle = site.pages.find { |p| p.url == "#{page.url}index.ttl" }
        graph = RDF::Graph.new << JSON::LD::API.toRdf(lod)
        turtle.content = graph.dump(:ttl)
        expanded = JSON::LD::API.expand(lod)
        compacted = JSON::LD::API.compact(expanded, page.data["data"]["@context"])
        jsonld = site.pages.find { |p| p.url == "#{page.url}index.json" }
        jsonld.content = JSON.pretty_generate(compacted)

    end
end

Jekyll::Hooks.register :documents, :post_render do |document|
    puts "\n\e[34mMAKING CONTENT PAGE: #{document["title"]}\e[0m"
    require 'nokogiri'
    include Jekyll::LODBook
    include Jekyll::Utils
    content_page = ContentPage.new(document)
    # base_url = document.site.config["base_url"]
    # lod_source = document.site.config["lod_source"]
    # data_source = document.site.data[lod_source["data"]]
    # types = document.site.config['data_types']
    # data = get_graph(lod_source, data_source)
    # html = Nokogiri::HTML(document.output)
    content_page.number_paras()
    content_page.collect_references()
    content_page.markup_names()
    lod = content_page.generate_mentions()
    # content_page.add_styles()
    document.output = content_page.html.to_html
    # This is so we can pick up the mentions later in pages
    document.data["data"] = lod
    document.site.pages << JSONContentPage.new(document.site, document.site.source, document.url, lod, "text")
    document.site.pages << TurtleContentPage.new(document.site, document.site.source, document.url, lod, "text")
end

#

Liquid::Template.register_tag('lod', Jekyll::LODBook::LODLink)
Liquid::Template.register_tag('lod_ignore', Jekyll::LODBook::LODIgnore)
Liquid::Template.register_filter(Jekyll::LODBook::LODUrlFilter)
# Liquid::Template.register_filter(Jekyll::LODBook::JSONLDGenerator)
Liquid::Template.register_filter(Jekyll::LODBook::LODList)
Liquid::Template.register_filter(Jekyll::LODBook::LODItem)
Liquid::Template.register_filter(Jekyll::LODBook::ImageLink)
Liquid::Template.register_filter(Jekyll::LODBook::FormatDate)
