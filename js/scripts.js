$(document).ready(function() {
    $(".navbar-burger").click(function() {
        var target = $(this).data("target");
        $(this).toggleClass("is-active");
        $("#"+target).toggleClass("is-active");
    });
});
