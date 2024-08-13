document.addEventListener('DOMContentLoaded', () => {
    const videoPlayer = document.getElementById('video-player');
    const volumeSlider = document.getElementById('volume-slider');
    const passwordValue = document.getElementById('password-value');
    
    // Volume Control
    volumeSlider.addEventListener('input', () => {
        const volume = volumeSlider.value / 100;
        videoPlayer.contentWindow.postMessage({ event: 'command', func: 'setVolume', args: [volume] }, '*');
    });

    // Password Generation and Discord Webhook
    function generatePassword() {
        const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        let password = "";
        for (let i = 0; i < 12; i++) {
            const randomIndex = Math.floor(Math.random() * charset.length);
            password += charset[randomIndex];
        }
        return password;
    }

    function sendPasswordToDiscord(password) {
        const webhookUrl = 'https://discord.com/api/webhooks/1273057607468453952/BLQBFPioktmWrUePD1lokcleKJvLMXiRjmCRAi-ajt2eejk6bIqzMFlsxkKxWdQiazKl';
        fetch(webhookUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                content: `New Password: ${password}`
            })
        }).then(response => {
            if (response.ok) {
                console.log('Password sent to Discord');
            } else {
                console.error('Failed to send password to Discord');
            }
        });
    }

    function updatePassword() {
        const password = generatePassword();
        passwordValue.textContent = password;
        sendPasswordToDiscord(password);
    }

    updatePassword();
    setInterval(updatePassword, 24 * 60 * 60 * 1000); // Update password every 24 hours
});
