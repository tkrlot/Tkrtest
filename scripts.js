function updateSignatureText() {
    var inputText = document.getElementById('input-text').value;
    var signatureText = document.getElementById('signature-text');
    
    // You can modify this to apply different signature fonts or styles
    signatureText.style.fontFamily = 'cursive';  // Example: 'cursive', 'Brush Script MT', etc.
    signatureText.textContent = inputText;
}

function copyText() {
    var signatureText = document.getElementById('signature-text');
    var range = document.createRange();
    range.selectNode(signatureText);
    window.getSelection().removeAllRanges();
    window.getSelection().addRange(range);
    document.execCommand('copy');
    window.getSelection().removeAllRanges();
    
    // Optionally provide feedback to the user
    alert('Copied!');
}

document.getElementById('input-text').addEventListener('input', updateSignatureText);

// Initialize with empty input
updateSignatureText();
