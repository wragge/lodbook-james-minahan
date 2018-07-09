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
                @graph.push(process_hash(properties))
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
                    if key == "image"
                        if prop.kind_of?(Hash)
                            if prop.has_key?("name")
                                image_record = get_record(prop["name"])
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
                            properties["@type"] = @types[prop]["type"]
                        elsif key == 'id'
                                properties["@id"] = prop
                        elsif key == 'image'
                            image_record = get_record(prop)
                            puts image_record
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
            require 'nokogiri'
            include LODBook

            attr_reader :html

            def initialize(document)
                @site = document.site
                @site_url = @site.config['url']
                @base_url = @site.config["base_url"]
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
                puts names
                graph_maker = GraphMaker.new(@site)
                names.each do |name|
                    record = get_record(name)
                    puts record
                    graph_maker.process_properties(record)
                end
                mentions = {"@id": @page_url, "@type": "http://schema.org/WebPage", "http://schema.org/mentions": graph_maker.graph}
                lod = {"@context": @context, "@graph": mentions}
                # This is needed to parse as LOD
                lod = JSON.parse(lod.to_json)
                # Not sure if this is really necessary, but it ensures a standard format
                expanded = JSON::LD::API.expand(lod)
                compacted = JSON::LD::API.compact(expanded, @context)
                script = Nokogiri::HTML.fragment("<script id=\"page-data\" type=\"application/ld+json\">#{JSON.pretty_generate(compacted)}</script>")
                @html.css("body")[0].add_child(script)
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
              filename = Utils.slugify(data["data"]["graph"]["name"])
              puts 'MAKING AN ENTITY PAGE NOW'
              @dir = dir + "/" + filename + "/"
              @name =  "index.html"
              self.process(@name)
              self.read_yaml(File.join(base, '_layouts'), template + ".html")
              self.data['title'] = data["data"]["graph"]["name"]
              # add all the information defined in _data for the current record to the
              # current page (so that we can access it with liquid tags)
              self.data.merge!(data)
            end
        end

        class DataPagesGenerator < Generator
            safe true
            include LODBook

            # generate loops over _config.yml/page_gen invoking the DataPage
            # constructor for each record for which we want to generate a page

            def generate(site)
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
                    collection = types[type]["collection"] || type
                    template = types[type]["template"]
                    # If there's an image send it off for processing
                    # An image can be a local path, a url or a type with a Schema contentUrl
                    # ImageObjects (and Media Objects) have a contentUrl that links to the actual file
                    # Specify that images need Schema contentUrl property to be processed
                    # Also need to use Schema image property
                    # image_keys = record.keys & ['image', 'schema.image']
                    # if image_keys.any?


                    page_data = {"data" => {"context" => parsed_data[:context], "graph" => record}}
                # puts page_data
                # record["data"]["context"] = context

                # type = types[collection]["type"]
                # record["context"] = context
                # record["data"]["@type"] = type
                # record["data"]["name"] = record["name"]
                    site.pages << DataPage.new(site, site.source, collection, page_data, template)
                end
            end
        end

        class LODLink < Liquid::Block
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
                    puts "#{@name} not found"
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

        class LODMentions < Liquid::Tag

            def initialize(tag_name, text, tokens)
                super
            end

            def render(context)
                data = context.registers[:site].data["data"]
                mentions = []
                entities = []
                lod = {'@context': 'http://schema.org', '@id': context["page"]["url"]}
                matches = context["page"]["content"].scan(/\{\% lod (.*?)\%\}(.*?)\{\% endlod \%\}/i)
                matches.each do |match|
                    name = if match[0] != "" then match[0] else match[1] end
                    entity = data.find { |entity| entity["name"] == name }
                    if entity then entities |= [entity] end
                end
                entities.each do |entity|
                    url = format_url(context, entity["name"], entity["collection"])
                    mentions.push({ '@id': url })
                end
                lod['mentions'] = mentions
                return "<script type=\"application/ld+json\">#{JSON.generate(lod)}</script>"
            end
        end

        module ImageLink

            def image_link(image)
                if image.kind_of?(Hash)
                    image = image["name"]
                end
                if ['.jpg', '.png', '.gif', '.jpeg'].include?(File.extname(image))
                    return image
                else
                    lod_source = @context.registers[:site].config['lod_source']
                    data_source = @context.registers[:site].data[lod_source['data']]
                    data = get_graph(lod_source, data_source)
                    record = data.find { |r| r["name"] == image }
                    return record["image"]
                end
            end
        end

        module FormatDate

            def format_date(date)
                formatted_date = date
                parts = date.split('-')
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
            require 'yaml'
            # require 'json'
            require 'json/ld'
            include LODUrlFilter
            include LODBook

        # Creates JSON-LD about an entity for embedding in a page.
        # Converts 'name' & 'collection' pairs to '@id's.
        # Wraps the JSON-LD in script tags.
        #
        # Feed it a page and get back JSON-LD wrapped in a script tag -- eg: {{ page | jsonldify }}

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
                  graph[0]["@id"] = page_url
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

        module LODList
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
                    end
                else
                    output += "<li>#{value}</li>\n"
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
                    output += "<h4 class='title is-size-4'>#{label}</h4>\n"
                    output += "<ul class='is-size-5'>\n"
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

Jekyll::Hooks.register :documents, :post_render do |document|
    puts 'MAKING A CONTENT PAGE NOW'
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
    content_page.generate_mentions()
    # content_page.add_styles()


    # Loop through references to generate mentions and create JSON-LD
    document.output = content_page.html.to_html
    puts 'Done'
end

Liquid::Template.register_tag('lod', Jekyll::LODBook::LODLink)
Liquid::Template.register_tag('lod_ignore', Jekyll::LODBook::LODIgnore)
Liquid::Template.register_filter(Jekyll::LODBook::LODUrlFilter)
Liquid::Template.register_filter(Jekyll::LODBook::JSONLDGenerator)
Liquid::Template.register_filter(Jekyll::LODBook::LODList)
Liquid::Template.register_filter(Jekyll::LODBook::ImageLink)
Liquid::Template.register_filter(Jekyll::LODBook::FormatDate)
