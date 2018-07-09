$(document).ready(function() {
    var data;
    var template;
    var linksActivated = false;
    var footnotesActivated = false;
    var animationEnd = "webkitAnimationEnd mozAnimationEnd MSAnimationEnd oanimationend animationend";

    function checkSize() {
        if (window.matchMedia("(min-width: 769px)").matches) {
            if (linksActivated == false) {
                activate();
                linksActivated = true;
                footnotesActivated = true;
            }
        } else {
            if (footnotesActivated == false) {
                activateMobile();
                footnotesActivated = true;
            }
        }
    }

    function showReferences() {
        var names = {};
        var referenceIds = [];
        var nameIds = []
        var newReferences = [];
        hideDetails();
        // Extract names/ids from lod links currently in view
        var visible = $(".lod-link:in-viewport");
        visible.each(function(index, elem) {
            var name = $(elem).data("name");
            var collection = $(elem).data("collection");
            var id = _.kebabCase(name);
            if (nameIds.indexOf(id) === -1) {
                names[id] = {"name": name, "collection": collection};
                nameIds.push(id);
            }
        });
        // Extract ids for references currently displayed
        $(".reference").each(function(index, elem) {
            referenceIds.push($(elem).attr("id"));
        });
        // The difference between the nameIds and referenceIds will be the references we need to add.
        // Loop through these creating new reference elements.
        $.each(_.difference(nameIds, referenceIds), function(index, id) {
            var name = names[id]["name"];
            var collection = names[id]["collection"];
            var initial = name.substr(0,1);
            var reference = $("<div>").attr('id', id)
                                      .attr('title', name)
                                      .text(initial)
                                      .data("name", name)
                                      .addClass(collection + " reference animated bounceInDown")
                                      .one(animationEnd, function() {
                                          $(this).removeClass("animated bounceInDown")
                                      })
                                      .click(displayDetails)
                                      .mouseenter(function() {
                                          var name = $(this).data("name");
                                          console.log(name);
                                          $('a[data-name="' + name + '"]')
                                                .addClass("animated pulse")
                                                .one(animationEnd, function(event) {
                                                    $(this).removeClass("animated pulse");
                                                });
                                      });
            newReferences.push(reference);
        });
        // The difference between the referenceIds and the nameIds will be the references we need to remove.
        // Loop through these and remove them. Once they've finished, add the new references.
        var difference = _.difference(referenceIds, nameIds);
        if (difference.length > 0) {
            var remove = "#" + _.difference(referenceIds, nameIds).join(", #")
            $(remove).addClass("animated bounceOutDown")
                     .one(animationEnd, function() {
                         $(this).animate({width: "toggle", opacity: "toggle"}, 100, function() {
                             $(this).remove();
                             $("#references").append(newReferences);
                         });
                     });
        } else {
            $("#references").append(newReferences);
        }
    }

    function hideDetails() {
        $("#thing-details").fadeOut(function() {$("#thing-details").empty();});
        $(".reference").removeClass("inverse");
    }

    function countConnections(record) {
        counts = [];
        record = _.flatMapDeep(record);
        $.each(collections, function(index, coll) {
            count = 0;
            $.each(coll["types"], function(index, type) {
                count += _.filter(record, {"type": type}).length
            });
            if (count > 0) {
                counts.push({"collection": coll["name"], "count": count});
            }
        });
        console.log(counts);
        return counts;
    }

    function prepareDisplayFields(record, collection) {
        fields = []
        $.each(displayFields[collection], function(index, displayField) {
            var content = record[displayField["field"]];
            if (typeof content !== 'undefined') {
                if (displayField["type"] = "date") {
                    content = moment(content).format("D MMMM YYYY");
                }
                fields.push({"label": displayField["label"], "content": content});
            }
        });
        return fields;
    }

    function displayDetails(event) {
        event.preventDefault();
        var name = $(this).data("name");
        var id = _.kebabCase(name);
        // Don't bother if it's already showing
        if ($("#thing-details .card").data("id") == id) {
            hideDetails();
        } else {
            var record = _.find(data, {"name": name});
            var urlSplit = record.id.split('/');
            var collection = urlSplit[4];
            connections = countConnections(record);
            $(".reference").removeClass("inverse");
            var fields = prepareDisplayFields(record, collection);
            var details = {"name": name, "url": record["id"], "collection": collection, "id": id, "fields": fields, "connections": connections};
            if (typeof record["image"] !== "undefined") {
                if (typeof record["image"]["image"] !== "undefined") {
                    details["image"] = record["image"]["image"];
                } else {
                    details["image"] = record["image"];
                }
            }
            var card = template(details);
            $("#thing-details").fadeOut(function() {
                $(this).empty().append(card).fadeIn();
                $(".close-details").click(hideDetails);
                $("#" + id).addClass("inverse");
            });
        }
    }

    function highlightReference(event) {
        var name = $(this).data("name");
        var id = _.kebabCase(name);
        $("#" + id).addClass("animated wobble")
                   .one(animationEnd, function(event) {
                       $(this).removeClass("animated wobble");
                   });
    }

    function setSidebarWidth() {
        $("#sidebar").width($("#sidebar").parent().width());
    }

    function getFootnote(fNumber) {
        fn = $("li[id='fn:"+fNumber+"']");
        fn.find('a.reversefootnote').remove();
        return $("p", fn).html()
    }

    function activateFootnotes() {
        $("a[href^='#fn:']").off().each(function(index, fn) {
            var fNumber = /\d+/.exec($(this).attr("href"))[0];
            var footnote = getFootnote(fNumber);
            var fnSlider = $("<div>").attr("id", "fnSlider"+fNumber).addClass("fnSlider").html(footnote);
            if (mobile === false) {
                $(".lod-link", fnSlider).click(displayDetails).mouseenter(highlightReference);
            }
            $(this).parent().after(fnSlider);
            $(this).click(function(event) {
                event.preventDefault();
                $("#fnSlider"+fNumber).slideToggle(function() {
                    if (mobile == false) {
                        showReferences();
                    }
                });
            });
        });
    }

    function activate() {
        console.log("Activating...");
        var json = JSON.parse($("#page-data").text());
        data = json["mentions"];
        var source = $("#details-template").html();
        template = Handlebars.compile(source);

        var sidebar = $('#sidebar');
        var top = sidebar.offset().top - parseFloat(sidebar.css('margin-top'));

        $(window).scroll(function (event) {
            var y = $(this).scrollTop();
            if (y >= top -20) {
                sidebar.addClass('fixed');
            } else {
                sidebar.removeClass('fixed');
            }
        });

        $(window).resize(setSidebarWidth);

        $(".lod-link").click(displayDetails);

        $(".close-details").click(hideDetails);

        // Wobble reference when you hover over a name in the text.
        $(".lod-link").mouseenter(highlightReference);

        activateFootnotes(mobile=false);
        setSidebarWidth();
        $(window).on('scroll', _.debounce(showReferences, 200));
        showReferences();
    }

    function activateMobile() {
        activateFootnotes(mobile=true);
    }

    $(window).resize(function() {
        checkSize();
    });

    checkSize();
});
