require 'yaml'
require 'csv'

data = YAML.load_file('new_data.yml')

collections = {
    "people": ["Person"],
    "organisations": ["Organization"],
    "places": ["Place", "CivicStructure", "City", "State"],
    "events": ["Event"],
    "resources": ["CreativeWork", "ImageObject", "ArchivalUnit", "Book", "Photograph", "ArchivalSeries", "Letter"]
}

properties = {
    "people": [],
    "organisations": [],
    "places": [],
    "events": [],
    "resources": []
}

data.each do |thing|
    type = thing["type"]
    collection = collections.find { |key, values| values.include?(type) }.first
    keys = thing.keys
    properties[collection] = (properties[collection] + keys).uniq
end

collections.keys.each do |collection|
    puts collection
    CSV.open("#{collection}.csv", "wb") do |csv|
        csv << properties[collection]
    end
end

data.each do |thing|
    #puts "\"#{thing['name']}\", #{thing['type']}"
    puts "\n\n--------------------"
    puts thing['name'].upcase
    thing.each do |key, value|
        puts "\n#{key}:\n"
        if value.kind_of?(Array)
            value.each do |v|
                if v.kind_of?(Hash)
                    v.each do |k1, v1|
                        if k1 == 'name'
                            puts v1
                        elsif k1 != 'collection'
                            puts "\n#{k1}:\n"
                            puts v1
                        end
                    end
                else
                    puts v
                end
            end
        elsif value.kind_of?(Hash)
            value.each do |k, v|
                if k == 'name'
                    puts v
                elsif k != 'collection'
                    puts "\n#{k}:\n"
                    puts v
                end
            end
        else
            puts value
        end
    end
end
