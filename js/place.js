$(document).ready(function() {
    console.log(latitude);
    if (latitude != "") {
        var map = L.map('map').setView([latitude, longitude], 5);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        }).addTo(map);

        L.marker([latitude, longitude]).addTo(map);
    }
});
