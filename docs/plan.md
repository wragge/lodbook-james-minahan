# LOD Book plan, May 2018

## Data

Formats:

* JSON-LD
* JSON
* YAML

YAML should include context? Or check JSON/YAML for context, if none, assume schema.org.

Getting context:

* first check config.yml for context setting for data file -- this would allow data to be reframed
* then check data file for context
* otherwise assume schema.org

Minimum fields:

* name
* @type

For both create ids from type and slugified name.

## Jekyll output

HTML with tagged entities marked up with `name` and `type`, and linked to individual pages.

Numbered paras?

The link will also be the LOD identifier.

JSON-LD embedded in page.

Individual pages for each entity.

Browse/index pages for each type (or groups of types?)

* Page mentions...
* Full details of each entity mentioned on that page.

Steps for narrative pages:

* Tags processed to add links (or link blockers) to text
* Tagged entities harvested
* Tag other mentions of tagged entities
* Generate JSON-LD and append to end of page

Steps for entity pages:

* Loop through attributes for each entity and display
* Options for displaying/suppressing particular fields
* Append JSON-LD

## Javascript

Create array of paras -> entities.

Retrieve data from JSON-LD for info boxes.
