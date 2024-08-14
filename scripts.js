document.addEventListener('DOMContentLoaded', () => {
    const video = document.getElementById('video');
    const videoUrlInput = document.getElementById('video-url');
    const loadVideoButton = document.getElementById('load-video');

    loadVideoButton.addEventListener('click', () => {
        const videoUrl = videoUrlInput.value;
        video.src = videoUrl;
        video.load();
        video.play();
    });

    // Add any additional JavaScript functionality here
});
