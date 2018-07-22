require 'yaml'
require 'csv'


$properties = {
    "name" => {"type" => "text", "multiple" => false},
    "type" => {"type" => "text", "multiple" => false},
    "familyName" => {"type" => "text", "multiple" => true},
    "givenName" => {"type" => "text", "multiple" => true},
    "image" => {"type" => "link", "multiple" => false},
    "imagefile" => {"type" => "text", "multiple" => false},
    "url" => {"type" => "text", "multiple" => false},
    "birthDate" => {"type" => "text", "multiple" => false},
    "deathDate" => {"type" => "text", "multiple" => false},
    "parent" => {"type" => "link", "multiple" => true},
    "children" => {"type" => "link", "multiple" => true},
    "sibling" => {"type" => "link", "multiple" => true},
    "spouse" => {"type" => "link", "multiple" => true},
    "relatedTo" => {"type" => "link", "multiple" => true},
    "knows" => {"type" => "link", "multiple" => true},
    "subjectOf" => {"type" => "link", "multiple" => true},
    "created" => {"type" => "link", "multiple" => true},
    "memberOf" => {"type" => "link", "multiple" => true},
    "worksFor" => {"type" => "link", "multiple" => true},
    "attended" => {"type" => "link", "multiple" => true},
    "performedIn" => {"type" => "link", "multiple" => true},
    "sameAs" => {"type" => "text", "multiple" => true},
    "description" => {"type" => "text", "multiple" => false},
    "publishes" => {"type" => "link", "multiple" => true},
    "foundingDate" => {"type" => "text", "multiple" => false},
    "dissolutionDate" => {"type" => "text", "multiple" => false},
    "employee" => {"type" => "link", "multiple" => true},
    "member" => {"type" => "link", "multiple" => true},
    "provides" => {"type" => "link", "multiple" => true},
    "coordinates" => {"type" => "geo", "multiple" => false},
    "containedInPlace" => {"type" => "link", "multiple" => true},
    "mentionedBy" => {"type" => "link", "multiple" => true},
    "containsPlace" => {"type" => "link", "multiple" => true},
    "address" => {"type" => "link", "multiple" => true},
    "startDate" => {"type" => "text", "multiple" => false},
    "endDate" => {"type" => "text", "multiple" => false},
    "performer" => {"type" => "link", "multiple" => true},
    "attendee" => {"type" => "link", "multiple" => true},
    "creationDate" => {"type" => "text", "multiple" => false},
    "publicationDate" => {"type" => "text", "multiple" => false},
    "publisher" => {"type" => "link", "multiple" => true},
    "isPartOf" => {"type" => "link", "multiple" => true},
    "hasPart" => {"type" => "link", "multiple" => true},
    "position" => {"type" => "text", "multiple" => true},
    "about" => {"type" => "link", "multiple" => true},
    "provider" => {"type" => "link", "multiple" => true},
    "creator" => {"type" => "link", "multiple" => true},
    "mentions" => {"type" => "link", "multiple" => true},
    "location" => {"type" => "link", "multiple" => true}
}


class Thing
    attr_reader :thing
    def initialize(data)
        @thing = {}
        data.each do |property, value|
            unless value.nil?
                if property == "image" and [".jpg", ".jpeg", ".png", ".pdf", ".tif", ".tiff"].include?(File.extname(value).downcase)
                    config = $properties["imagefile"]
                else
                    config = $properties[property]
                end
                if config["type"] == "link"
                    new_value = make_array({"name" => value.to_s.chomp.strip}, config["multiple"])
                elsif config["type"] == "geo"
                    latitude, longitude = value.split(",")
                    new_value = {"latitude" => latitude.strip, "longitude" => longitude.strip, "type" => "GeoCoordinates"}
                    property = "geo"
                else
                    new_value = make_array(value.to_s.chomp.strip, config["multiple"])
                end
                @thing[property] = new_value
            end
        end
    end

    def make_array(value, multiple)
        if multiple
            return [value]
        else
            return value
        end
    end

    def add_values(data)
        data.each do |property, value|
            unless value.nil?
                config = $properties[property]
                if config["type"] == "link"
                    @thing[property] << {"name" => value}
                else
                    @thing[property] << value
                end
            end
        end
    end
end

def process_csv(csv)
    things = []
    thing = nil
    csv = CSV.read("#{csv}.csv", { encoding: "UTF-8", headers: true, converters: :all})
    csv.each do |row|
      data = row.to_hash
      if data["name"] != nil
          puts 'Yes'
          unless thing.nil?
              things << thing.thing
          end
          thing = Thing.new(data)
      else
          puts "no"
          thing.add_values(data)
      end
    end
    return things
end

csvs = ["people", "organisations", "places", "events", "resources"]
csvs.each do |csv|
    things = process_csv(csv)
    File.open('data-csv.yml', 'a') { |f| f.write(things.to_yaml.gsub("---\n", '')) }
end
