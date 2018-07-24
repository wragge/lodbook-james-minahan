$(document).ready(function() {
    var $wall = $('#wall').imagesLoaded( function() {
        $wall.isotope({
            itemSelector: '.column',
            layoutMode: 'packery'
        });
    });
});
