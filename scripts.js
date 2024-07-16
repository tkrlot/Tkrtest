document.addEventListener("DOMContentLoaded", () => {
    const toggle = document.getElementById("dark-mode-toggle");
    toggle.addEventListener("change", () => {
        document.body.classList.toggle("dark-mode", toggle.checked);
    });
});
