document.addEventListener("DOMContentLoaded", function() {
    document.querySelectorAll('.scroll-btn').forEach(button => {
        button.addEventListener('click', function(event) {
            event.preventDefault();
            window.location.href = this.getAttribute('href');
        });
    });
});