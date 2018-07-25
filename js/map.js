$(document).ready(function() {
    var map = L.map('map').setView([-25, 135], 4);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(map);
    var markers = [];
    $.each(places, function(index, place) {
        console.log(place);
        if ("geo" in place && "latitude" in place.geo) {
            var name = place.name;
            var link = "../../places/" + _.kebabCase(name) + "/";
            var latitude = place.geo.latitude;
            var longitude = place.geo.longitude;
            var html = '<a class="title is-size-5" href="' + link + '">' + name + '</a>';
            if ("image_file" in place) {
                html += '<br><figure class="image is-96x96"><img class="cover" src="../../images/resized/100/' + place.image_file + '"></figure>';
            }
            marker = L.marker([latitude, longitude]).bindPopup(html);
            markers.push(marker);
        }
        var fg = L.featureGroup(markers).addTo(map);
        map.fitBounds(fg.getBounds());
    });
});
