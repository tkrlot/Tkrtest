<script>
    function toggleDarkMode() {
        const body = document.body;
        const darkModeToggle = document.getElementById('darkModeToggle');
        const currentIcon = darkModeToggle.textContent.trim(); // Get current icon

        if (currentIcon === '🌙') {
            // Switch to sun and change text color to black
            body.classList.add('dark-mode');
            darkModeToggle.textContent = '☀️';
            document.documentElement.style.setProperty('--text-color', '#000000'); // Set black text color
        } else {
            // Switch to moon and change text color to white
            body.classList.remove('dark-mode');
            darkModeToggle.textContent = '🌙';
            document.documentElement.style.setProperty('--text-color', '#ffffff'); // Set white text color
        }
    }

    // Function to fetch weather temperature
    async function fetchWeather() {
        try {
            const response = await fetch('https://api.openweathermap.org/data/2.5/weather?q=London&appid=YOUR_API_KEY&units=metric');
            if (!response.ok) {
                throw new Error('Weather data not available');
            }
            const data = await response.json();
            const temperature = data.main.temp;
            const temperatureDisplay = document.getElementById('temperature');
            temperatureDisplay.textContent = `${temperature} °C`;
        } catch (error) {
            console.error('Error fetching weather:', error.message);
        }
    }

    // Toggle text color on temperature display click
    const temperatureDisplay = document.getElementById('temperature');
    temperatureDisplay.addEventListener('click', function () {
        temperatureDisplay.classList.toggle('black-text');
    });

    // Initial fetch of weather data
    fetchWeather();
</script>
