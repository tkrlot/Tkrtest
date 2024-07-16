const toggleButton = document.getElementById('theme-toggle');
const body = document.body;
const toggleText = document.querySelector('.toggle-text');

toggleButton.addEventListener('click', () => {
    body.classList.toggle('dark-mode');
    if (body.classList.contains('dark-mode')) {
        toggleButton.textContent = '🌜';
        toggleText.textContent = 'Dark Mode';
    } else {
        toggleButton.textContent = '🌞';
        toggleText.textContent = 'Light Mode';
    }
});

// Initial theme check based on user preference
if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
    body.classList.add('dark-mode');
    toggleButton.textContent = '🌜';
    toggleText.textContent = 'Dark Mode';
}
