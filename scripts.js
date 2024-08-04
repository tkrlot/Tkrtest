document.addEventListener('DOMContentLoaded', () => {
    const toggleButton = document.getElementById('toggle-theme');

    toggleButton.addEventListener('click', () => {
        document.body.classList.toggle('light-theme');
    });
});
