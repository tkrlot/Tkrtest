document.addEventListener('DOMContentLoaded', function () {
    const toggleIcon = document.getElementById('toggle-icon');
    const body = document.body;

    toggleIcon.addEventListener('click', function () {
        body.classList.toggle('dark-mode');
        if (body.classList.contains('dark-mode')) {
            toggleIcon.textContent = '🌜';
        } else {
            toggleIcon.textContent = '🌞';
        }
    });
});
